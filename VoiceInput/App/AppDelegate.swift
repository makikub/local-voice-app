import AppKit
import SwiftUI

/// アプリケーションライフサイクル管理
/// メニューバーアイコン、ホットキー、録音、音声認識の統合を担当
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager!
    private var audioRecorder: AudioRecorder!
    private var whisperService: WhisperService!
    private var textInputService: TextInputService!

    // メニュー内のステータス表示用アイテム
    private weak var statusMenuItem: NSMenuItem?
    private weak var modelStatusMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupAudioRecorder()
        setupHotkeyManager()
        setupTextInputService()
        setupWhisperService()
    }

    // MARK: - セットアップ

    /// メニューバーアイコンとドロップダウンメニューの構築
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusItemIcon(state: .idle)

        let (menu, menuStatusItem, menuModelStatusItem) = MenuBarView.createMenu(target: self)
        self.statusMenuItem = menuStatusItem
        self.modelStatusMenuItem = menuModelStatusItem
        self.statusItem.menu = menu
    }

    /// 録音サービスの初期化
    private func setupAudioRecorder() {
        audioRecorder = AudioRecorder()
    }

    /// グローバルショートカットの登録
    private func setupHotkeyManager() {
        hotkeyManager = HotkeyManager { [weak self] in
            self?.toggleRecording()
        }
    }

    /// テキスト入力サービスの初期化とアクセシビリティ権限チェック
    private func setupTextInputService() {
        textInputService = TextInputService()

        // アクセシビリティ権限が未付与の場合、システムダイアログで案内
        if !TextInputService.isAccessibilityGranted {
            TextInputService.requestAccessibility()
        }
    }

    /// WhisperService の初期化とモデルセットアップ
    private func setupWhisperService() {
        whisperService = WhisperService()

        // 状態変更コールバック: メニューバーUIを更新
        whisperService.onStateChanged = { [weak self] state in
            self?.updateModelStatusUI(state)
        }

        // バックグラウンドでモデルセットアップを開始
        Task {
            await whisperService.setupModel()
        }
    }

    // MARK: - 録音トグル

    /// ショートカットキー押下時のトグル処理
    private func toggleRecording() {
        if audioRecorder.isRecording {
            // 録音停止 → 音声認識開始
            let savedURL = audioRecorder.stopRecording()
            updateStatusItemIcon(state: .idle)
            statusMenuItem?.title = "録音: オフ"

            if let url = savedURL {
                print("[VoiceInput] 保存完了: \(url.lastPathComponent)")
                startTranscription(audioURL: url)
            }
        } else {
            // 認識中は録音を開始しない
            if case .transcribing = whisperService.state {
                print("[VoiceInput] 認識処理中のため録音を開始できません")
                return
            }
            audioRecorder.startRecording()
            updateStatusItemIcon(state: .recording)
            statusMenuItem?.title = "録音中..."
        }
    }

    /// 音声認識を非同期で実行
    private func startTranscription(audioURL: URL) {
        updateStatusItemIcon(state: .transcribing)
        statusMenuItem?.title = "認識中..."

        Task {
            let text = await whisperService.transcribe(audioURL: audioURL)

            updateStatusItemIcon(state: .idle)

            if let text = text {
                statusMenuItem?.title = "入力中..."
                textInputService.insertText(text)
                statusMenuItem?.title = "入力完了"
            } else {
                statusMenuItem?.title = "認識結果なし"
            }

            // 3秒後にステータスをリセット
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            statusMenuItem?.title = "録音: オフ"
        }
    }

    // MARK: - UI更新

    /// メニューバーアイコンの状態
    private enum IconState {
        case idle, recording, transcribing
    }

    /// メニューバーアイコンの更新
    private func updateStatusItemIcon(state: IconState) {
        guard let button = statusItem.button else { return }

        let symbolName: String
        switch state {
        case .idle:
            symbolName = "mic"
        case .recording:
            symbolName = "mic.fill"
        case .transcribing:
            symbolName = "brain"
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

    /// モデル状態に応じたメニュー内テキスト更新
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
            print("[VoiceInput] モデルエラー: \(message)")
        }
    }

    // MARK: - アクション

    @objc func quit() {
        if audioRecorder.isRecording {
            _ = audioRecorder.stopRecording()
        }
        Task {
            await whisperService.unloadModel()
            NSApplication.shared.terminate(nil)
        }
    }
}
