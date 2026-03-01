import AppKit
import os
import SwiftUI
import UserNotifications

/// アプリケーションライフサイクル管理
/// メニューバーアイコン、ホットキー、録音、音声認識、テキスト入力の統合を担当
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private let logger = Logger(subsystem: "com.voiceinput.VoiceInput", category: "AppDelegate")

    // MARK: - サービス

    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager?
    private var audioRecorder: AudioRecorder!
    private var whisperService: WhisperService!
    private var textInputService: TextInputService!
    private var textPostProcessor: TextPostProcessor!
    private var recordingIndicator: RecordingIndicator!
    private var settingsWindowController: SettingsWindowController!

    // MARK: - メニューアイテム参照

    private weak var statusMenuItem: NSMenuItem?
    private weak var modelStatusMenuItem: NSMenuItem?
    private weak var shortcutMenuItem: NSMenuItem?
    private weak var cancelMenuItem: NSMenuItem?

    // MARK: - ライフサイクル

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupNotifications()
        setupStatusItem()
        setupAudioRecorder()

        let isOnboarded = AppSettings.hasCompletedOnboarding

        if isOnboarded {
            setupHotkeyManager()
        }

        setupTextInputService()
        setupTextPostProcessor()
        setupRecordingIndicator()
        setupSettingsWindowController()
        setupWhisperService()

        if !isOnboarded {
            showOnboarding()
        }
    }

    // MARK: - セットアップ

    /// 通知センターの権限要求
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// メニューバーアイコンとドロップダウンメニューの構築
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusItemIcon(state: .idle)

        let items = MenuBarView.createMenu(target: self)
        self.statusMenuItem = items.statusItem
        self.modelStatusMenuItem = items.modelStatusItem
        self.shortcutMenuItem = items.shortcutItem
        self.cancelMenuItem = items.cancelItem
        self.statusItem.menu = items.menu
    }

    private func setupAudioRecorder() {
        audioRecorder = AudioRecorder()
    }

    private func setupHotkeyManager() {
        hotkeyManager = HotkeyManager { [weak self] in
            self?.toggleRecording()
        }
    }

    private func setupTextInputService() {
        textInputService = TextInputService()

        if !TextInputService.isAccessibilityGranted && AppSettings.hasCompletedOnboarding {
            TextInputService.requestAccessibility()
        }
    }

    private func setupTextPostProcessor() {
        textPostProcessor = TextPostProcessor()
    }

    private func setupRecordingIndicator() {
        recordingIndicator = RecordingIndicator()
    }

    private func setupSettingsWindowController() {
        settingsWindowController = SettingsWindowController()
    }

    /// WhisperService の初期化とモデルセットアップ
    private func setupWhisperService() {
        whisperService = WhisperService()

        whisperService.onStateChanged = { [weak self] state in
            self?.updateModelStatusUI(state)
        }

        Task {
            await whisperService.setupModel()
        }
    }

    // MARK: - 録音トグル

    private func toggleRecording() {
        if audioRecorder.isRecording {
            // 録音停止 → 音声認識開始
            hotkeyManager?.unregisterEscape()
            let savedURL = audioRecorder.stopRecording()
            recordingIndicator.hide()
            updateStatusItemIcon(state: .idle)
            statusMenuItem?.title = "録音: オフ"
            cancelMenuItem?.isHidden = true

            if let url = savedURL {
                logger.info("録音停止: \(url.lastPathComponent)")
                startTranscription(audioURL: url)
            }
        } else {
            guard case .ready = whisperService.state else {
                logger.warning("モデル未準備のため録音を開始できません")
                notifyModelNotReady()
                return
            }
            audioRecorder.startRecording()
            recordingIndicator.show()
            updateStatusItemIcon(state: .recording)
            statusMenuItem?.title = "録音中..."
            cancelMenuItem?.isHidden = false

            // 録音中のみ Esc でキャンセル可能にする
            hotkeyManager?.registerEscape { [weak self] in
                self?.cancelRecording()
            }
        }
    }

    /// 録音をキャンセルする（認識処理を実行しない）
    @objc func cancelRecording() {
        guard audioRecorder.isRecording else { return }

        hotkeyManager?.unregisterEscape()
        let savedURL = audioRecorder.stopRecording()
        recordingIndicator.hide()
        updateStatusItemIcon(state: .idle)
        statusMenuItem?.title = "録音: オフ"
        cancelMenuItem?.isHidden = true
        logger.info("録音をキャンセルしました")

        // キャンセル時は常にファイルを削除
        if let url = savedURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// 音声認識を非同期で実行
    private func startTranscription(audioURL: URL) {
        updateStatusItemIcon(state: .transcribing)
        statusMenuItem?.title = "認識中..."

        Task {
            let text = await whisperService.transcribe(audioURL: audioURL)

            // メモリ管理: 設定に応じてモデルをアンロード
            if AppSettings.unloadModelAfterRecognition {
                await whisperService.unloadModel()
            }

            updateStatusItemIcon(state: .idle)

            if var text = text {
                // Claude 後処理（オプション）
                if AppSettings.enableClaudePostProcessing {
                    statusMenuItem?.title = "整形中..."
                    text = await textPostProcessor.process(text)
                }

                statusMenuItem?.title = "入力中..."
                textInputService.insertText(text)
                statusMenuItem?.title = "入力完了"
            } else {
                statusMenuItem?.title = "認識結果なし"
                sendNotification(title: "認識結果なし", body: "音声を認識できませんでした。もう一度お試しください。")
            }

            // WAV 自動削除（オプション）
            if AppSettings.deleteRecordingAfterTranscription {
                do {
                    try FileManager.default.removeItem(at: audioURL)
                    logger.info("録音ファイルを削除: \(audioURL.lastPathComponent)")
                } catch {
                    logger.warning("録音ファイルの削除に失敗: \(error.localizedDescription)")
                }
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            statusMenuItem?.title = "録音: オフ"

            // アンロード後は次回録音前にモデルを再ロード
            if AppSettings.unloadModelAfterRecognition {
                await whisperService.setupModel()
            }
        }
    }

    // MARK: - UI更新

    private enum IconState {
        case idle, recording, transcribing
    }

    private func updateStatusItemIcon(state: IconState) {
        guard let button = statusItem.button else { return }

        let symbolName: String
        switch state {
        case .idle:        symbolName = "mic"
        case .recording:   symbolName = "mic.fill"
        case .transcribing: symbolName = "brain"
        }

        button.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "VoiceInput"
        )

        switch state {
        case .recording:
            button.image?.isTemplate = false
            button.contentTintColor = .systemRed
        case .transcribing:
            button.image?.isTemplate = false
            button.contentTintColor = .systemBlue
        case .idle:
            button.image?.isTemplate = true
            button.contentTintColor = nil
        }
    }

    private func updateModelStatusUI(_ state: WhisperService.ServiceState) {
        switch state {
        case .idle:
            modelStatusMenuItem?.title = "モデル: 未ロード"
        case .downloadingModel(let progress):
            let percent = Int(progress * 100)
            modelStatusMenuItem?.title = "モデル: ダウンロード中 \(percent)%"
        case .loadingModel:
            modelStatusMenuItem?.title = "モデル: ロード中..."
        case .ready:
            modelStatusMenuItem?.title = "モデル: 準備完了"
        case .transcribing:
            modelStatusMenuItem?.title = "モデル: 認識処理中..."
        case .error(let message):
            modelStatusMenuItem?.title = "モデル: エラー"
            logger.error("モデルエラー: \(message)")
            sendNotification(title: "モデルエラー", body: message)
        }
    }

    // MARK: - モデル未準備時のフィードバック

    private func notifyModelNotReady() {
        switch whisperService.state {
        case .downloadingModel(let progress):
            let percent = Int(progress * 100)
            sendNotification(title: "モデル準備中", body: "モデルをダウンロード中です（\(percent)%）。完了までお待ちください。")
        case .loadingModel:
            sendNotification(title: "モデル準備中", body: "モデルを読み込み中です。まもなく使用可能になります。")
        case .error(let message):
            sendNotification(title: "モデルエラー", body: "モデルの読み込みに失敗しました: \(message)\n設定からモデルを変更するか、アプリを再起動してください。")
        case .idle:
            sendNotification(title: "モデル未ロード", body: "モデルのロードを開始します。しばらくお待ちください。")
            Task { await whisperService.setupModel() }
        case .transcribing:
            sendNotification(title: "認識処理中", body: "前の音声を認識中です。完了後に再度お試しください。")
        case .ready:
            break
        }
    }

    // MARK: - 通知

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - オンボーディング

    private var onboardingWindow: NSWindow?

    private func showOnboarding() {
        let onboardingView = OnboardingView { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            // オンボーディング完了後にホットキーを初期化
            self?.setupHotkeyManager()
        }

        let hostingController = NSHostingController(rootView: onboardingView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "VoiceInput セットアップ"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false

        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - メニューアクション

    @objc func openSettings() {
        settingsWindowController.showSettings(
            onModelChanged: { [weak self] _ in
                // モデルが変更されたら再セットアップ
                Task { [weak self] in
                    guard let self = self else { return }
                    await self.whisperService.unloadModel()
                    await self.whisperService.setupModel()
                }
            },
            onShortcutChanged: { [weak self] newShortcut in
                self?.hotkeyManager?.applyShortcut(newShortcut)
                self?.shortcutMenuItem?.title = "録音開始/停止: \(newShortcut.displayName)"
            }
        )
    }

    @objc func quit() {
        if audioRecorder.isRecording {
            _ = audioRecorder.stopRecording()
        }
        recordingIndicator.hide()
        Task {
            await whisperService.unloadModel()
            NSApplication.shared.terminate(nil)
        }
    }
}
