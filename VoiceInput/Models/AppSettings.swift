import Foundation

/// アプリケーション設定
enum AppSettings {
    // MARK: - 録音設定

    /// 録音ファイルの保存ディレクトリ名
    static let saveDirectoryName = "VoiceInput"

    /// サンプルレート（Whisper 標準: 16kHz）
    static let sampleRate: Double = 16000.0

    /// チャンネル数（モノラル）
    static let channels: Int = 1

    /// ビット深度
    static let bitDepth: Int = 16

    // MARK: - WhisperKit 設定（Phase 2）

    /// WhisperKit モデルバリアント名
    static let whisperModelVariant = "openai_whisper-large-v3_turbo"

    /// モデルのダウンロード元リポジトリ
    static let whisperModelRepo = "argmaxinc/whisperkit-coreml"

    /// モデル保存のベースディレクトリ: ~/Library/Application Support/VoiceInput/
    /// WhisperKit が内部で models/<repo>/<variant> を付加する
    static var modelDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return appSupport.appendingPathComponent("VoiceInput")
    }

    /// 認識対象言語
    static let recognitionLanguage = "ja"
}
