import SwiftUI

/// 設定画面（SwiftUI）
/// NSWindow にホスティングして表示する
struct SettingsView: View {

    @State private var selectedModel: String = AppSettings.whisperModelVariant
    @State private var selectedShortcut: ShortcutOption = AppSettings.shortcut
    @State private var launchAtLogin: Bool = AppSettings.launchAtLogin
    @State private var unloadModel: Bool = AppSettings.unloadModelAfterRecognition
    @State private var enablePostProcessing: Bool = AppSettings.enableClaudePostProcessing
    @State private var apiKey: String = AppSettings.openaiAPIKey ?? ""
    @State private var deleteRecording: Bool = AppSettings.deleteRecordingAfterTranscription
    @State private var recordingMode: RecordingMode = AppSettings.recordingMode

    /// モデル変更時のコールバック（AppDelegate がモデル再読み込みに使用）
    var onModelChanged: ((String) -> Void)?
    /// ショートカット変更時のコールバック
    var onShortcutChanged: ((ShortcutOption) -> Void)?
    /// 録音モード変更時のコールバック
    var onRecordingModeChanged: ((RecordingMode) -> Void)?

    var body: some View {
        Form {
            // MARK: - モデル設定
            Section {
                Picker("Whisper モデル", selection: $selectedModel) {
                    ForEach(AppSettings.availableModels, id: \.variant) { model in
                        Text(model.name).tag(model.variant)
                    }
                }
                .onChange(of: selectedModel) { _, newValue in
                    AppSettings.whisperModelVariant = newValue
                    onModelChanged?(newValue)
                }

                Toggle("認識後にモデルをメモリから解放", isOn: $unloadModel)
                    .onChange(of: unloadModel) { _, newValue in
                        AppSettings.unloadModelAfterRecognition = newValue
                    }

                Text("メモリ使用量を抑えたい場合に有効にします。次回認識時にモデルを再読み込みします。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("音声認識")
            }

            // MARK: - テキスト整形
            Section {
                Toggle("認識結果を整形", isOn: $enablePostProcessing)
                    .disabled(apiKey.isEmpty)
                    .onChange(of: enablePostProcessing) { _, newValue in
                        AppSettings.enableClaudePostProcessing = newValue
                    }

                SecureField("OpenAI API キー", text: $apiKey)
                    .onChange(of: apiKey) { _, newValue in
                        AppSettings.openaiAPIKey = newValue.isEmpty ? nil : newValue
                    }

                if apiKey.isEmpty {
                    Text("フィラー除去・句読点補完には OpenAI の API キーが必要です")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("認識後にフィラー除去・句読点補完を行います（GPT-4.1 mini 使用）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("テキスト整形")
            }

            // MARK: - ショートカット設定
            Section {
                Picker("ショートカットキー", selection: $selectedShortcut) {
                    ForEach(ShortcutOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .onChange(of: selectedShortcut) { _, newValue in
                    AppSettings.shortcut = newValue
                    onShortcutChanged?(newValue)
                }

                Picker("録音モード", selection: $recordingMode) {
                    ForEach(RecordingMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .onChange(of: recordingMode) { _, newValue in
                    AppSettings.recordingMode = newValue
                    onRecordingModeChanged?(newValue)
                }

                Text(recordingMode == .toggle
                    ? "ショートカットを押すたびに録音開始/停止を切り替えます。"
                    : "ショートカットを押している間だけ録音します。離すと転写が開始されます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("操作")
            }

            // MARK: - 一般設定
            Section {
                Toggle("ログイン時に起動", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        AppSettings.launchAtLogin = newValue
                    }

                Toggle("認識後に録音ファイルを削除", isOn: $deleteRecording)
                    .onChange(of: deleteRecording) { _, newValue in
                        AppSettings.deleteRecordingAfterTranscription = newValue
                    }
            } header: {
                Text("一般")
            }

            // MARK: - バージョン情報
            Section {
                LabeledContent("バージョン") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 560)
    }
}

// MARK: - 設定ウィンドウ管理

@MainActor
final class SettingsWindowController {

    private var window: NSWindow?
    private var windowDelegate: WindowCloseDelegate?

    /// 設定ウィンドウを表示する
    func showSettings(onModelChanged: @escaping (String) -> Void,
                      onShortcutChanged: @escaping (ShortcutOption) -> Void,
                      onRecordingModeChanged: @escaping (RecordingMode) -> Void) {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            onModelChanged: onModelChanged,
            onShortcutChanged: onShortcutChanged,
            onRecordingModeChanged: onRecordingModeChanged
        )
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "VoiceInput 設定"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        let closeDelegate = WindowCloseDelegate { [weak self] in
            self?.window = nil
            self?.windowDelegate = nil
        }
        self.windowDelegate = closeDelegate
        window.delegate = closeDelegate

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - ウィンドウクローズ検知

private class WindowCloseDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
