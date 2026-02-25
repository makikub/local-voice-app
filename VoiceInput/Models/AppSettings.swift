import Foundation
import ServiceManagement

/// アプリケーション設定
/// 固定値は static let、ユーザー変更可能な設定は UserDefaults を使用
enum AppSettings {

    private static let defaults = UserDefaults.standard

    // MARK: - UserDefaults キー

    private enum Key {
        static let whisperModel = "whisperModel"
        static let shortcut = "shortcut"
        static let launchAtLogin = "launchAtLogin"
        static let unloadModelAfterRecognition = "unloadModelAfterRecognition"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    // MARK: - 固定値（録音設定）

    static let saveDirectoryName = "VoiceInput"
    static let sampleRate: Double = 16000.0
    static let channels: Int = 1
    static let bitDepth: Int = 16

    // MARK: - 固定値（WhisperKit）

    static let whisperModelRepo = "argmaxinc/whisperkit-coreml"
    static let recognitionLanguage = "ja"

    static var modelDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return appSupport.appendingPathComponent("VoiceInput")
    }

    // MARK: - ユーザー設定（UserDefaults）

    /// Whisper モデルバリアント
    static var whisperModelVariant: String {
        get { defaults.string(forKey: Key.whisperModel) ?? "openai_whisper-large-v3_turbo" }
        set { defaults.set(newValue, forKey: Key.whisperModel) }
    }

    /// 利用可能なモデル一覧（表示名とバリアント名）
    static let availableModels: [(name: String, variant: String)] = [
        ("Tiny（最速・低精度・39MB）", "openai_whisper-tiny"),
        ("Base（高速・中精度・74MB）", "openai_whisper-base"),
        ("Small（バランス・244MB）", "openai_whisper-small"),
        ("Large V3 Turbo（推奨・高精度・809MB）", "openai_whisper-large-v3_turbo"),
    ]

    /// ショートカットキー設定
    static var shortcut: ShortcutOption {
        get {
            guard let raw = defaults.string(forKey: Key.shortcut),
                  let option = ShortcutOption(rawValue: raw) else {
                return .cmdShiftV
            }
            return option
        }
        set { defaults.set(newValue.rawValue, forKey: Key.shortcut) }
    }

    /// ログイン時に起動
    static var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set {
            defaults.set(newValue, forKey: Key.launchAtLogin)
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // 登録失敗は無視（開発ビルドでは動作しないことがある）
            }
        }
    }

    /// 認識完了後にモデルをアンロードする
    static var unloadModelAfterRecognition: Bool {
        get { defaults.bool(forKey: Key.unloadModelAfterRecognition) }
        set { defaults.set(newValue, forKey: Key.unloadModelAfterRecognition) }
    }

    /// オンボーディング完了フラグ
    static var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }
}

// MARK: - ショートカットオプション

enum ShortcutOption: String, CaseIterable {
    case cmdShiftV = "cmd+shift+v"
    case cmdShiftSpace = "cmd+shift+space"
    case ctrlOptionV = "ctrl+option+v"

    var displayName: String {
        switch self {
        case .cmdShiftV:     return "⌘⇧V"
        case .cmdShiftSpace: return "⌘⇧Space"
        case .ctrlOptionV:   return "⌃⌥V"
        }
    }
}
