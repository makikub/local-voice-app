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
        static let enableClaudePostProcessing = "enableClaudePostProcessing"
        static let openaiAPIKey = "openaiAPIKey"
        static let deleteRecordingAfterTranscription = "deleteRecordingAfterTranscription"
        static let recordingMode = "recordingMode"
        static let customDictionary = "customDictionary"
    }

    // MARK: - 固定値（カスタム辞書）

    /// カスタム辞書の最大登録数（promptTokens の 224 トークン上限を考慮）
    static let maxDictionaryWords = 50

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

    /// 認識結果を整形する（フィラー除去・句読点補完）
    static var enableClaudePostProcessing: Bool {
        get { defaults.bool(forKey: Key.enableClaudePostProcessing) }
        set { defaults.set(newValue, forKey: Key.enableClaudePostProcessing) }
    }

    /// OpenAI API キー
    static var openaiAPIKey: String? {
        get { defaults.string(forKey: Key.openaiAPIKey) }
        set { defaults.set(newValue, forKey: Key.openaiAPIKey) }
    }

    /// 認識完了後に録音ファイルを自動削除する
    static var deleteRecordingAfterTranscription: Bool {
        get {
            // デフォルト true（UserDefaults の bool は未登録時 false を返すため明示的に処理）
            if defaults.object(forKey: Key.deleteRecordingAfterTranscription) == nil {
                return true
            }
            return defaults.bool(forKey: Key.deleteRecordingAfterTranscription)
        }
        set { defaults.set(newValue, forKey: Key.deleteRecordingAfterTranscription) }
    }

    /// カスタム辞書（音声認識のヒント語彙）
    static var customDictionary: [DictionaryEntry] {
        get {
            guard let data = defaults.data(forKey: Key.customDictionary),
                  let entries = try? JSONDecoder().decode([DictionaryEntry].self, from: data) else {
                return []
            }
            return entries
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.customDictionary)
            }
        }
    }

    /// 録音モード（トグル or Push-to-Talk）
    static var recordingMode: RecordingMode {
        get {
            guard let raw = defaults.string(forKey: Key.recordingMode),
                  let mode = RecordingMode(rawValue: raw) else {
                return .toggle
            }
            return mode
        }
        set { defaults.set(newValue.rawValue, forKey: Key.recordingMode) }
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

// MARK: - カスタム辞書エントリ

struct DictionaryEntry: Codable, Equatable, Hashable, Identifiable {
    var id: String { reading + display }
    /// 読み（音声認識のヒント。ひらがな・カタカナ・英語など）
    var reading: String
    /// 表示文字（認識結果として出力したい表記）
    var display: String
}

// MARK: - 録音モード

enum RecordingMode: String, CaseIterable {
    case toggle = "toggle"
    case pushToTalk = "pushToTalk"

    var displayName: String {
        switch self {
        case .toggle:     return "トグル（押して開始／もう一度押して停止）"
        case .pushToTalk: return "Push-to-Talk（押している間だけ録音）"
        }
    }
}
