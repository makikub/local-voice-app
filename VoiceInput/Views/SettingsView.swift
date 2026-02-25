import SwiftUI

/// 設定画面（SwiftUI）
/// NSWindow にホスティングして表示する
struct SettingsView: View {

    @State private var selectedModel: String = AppSettings.whisperModelVariant
    @State private var selectedShortcut: ShortcutOption = AppSettings.shortcut
    @State private var launchAtLogin: Bool = AppSettings.launchAtLogin
    @State private var unloadModel: Bool = AppSettings.unloadModelAfterRecognition

    /// モデル変更時のコールバック（AppDelegate がモデル再読み込みに使用）
    var onModelChanged: ((String) -> Void)?
    /// ショートカット変更時のコールバック
    var onShortcutChanged: ((ShortcutOption) -> Void)?

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
            } header: {
                Text("操作")
            }

            // MARK: - 一般設定
            Section {
                Toggle("ログイン時に起動", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        AppSettings.launchAtLogin = newValue
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
        .frame(width: 420, height: 380)
    }
}

// MARK: - 設定ウィンドウ管理

@MainActor
final class SettingsWindowController {

    private var window: NSWindow?
    private var windowDelegate: WindowCloseDelegate?

    /// 設定ウィンドウを表示する
    func showSettings(onModelChanged: @escaping (String) -> Void,
                      onShortcutChanged: @escaping (ShortcutOption) -> Void) {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            onModelChanged: onModelChanged,
            onShortcutChanged: onShortcutChanged
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
