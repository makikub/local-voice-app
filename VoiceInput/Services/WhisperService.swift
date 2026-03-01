import Foundation
import os
import WhisperKit

/// WhisperKit を使用した音声認識サービス
/// モデルのダウンロード・ロード・音声ファイルからのトランスクリプションを管理
@MainActor
final class WhisperService {

    private let logger = Logger(subsystem: "com.voiceinput.VoiceInput", category: "WhisperService")

    // MARK: - 状態定義

    enum ServiceState: Equatable {
        case idle                              // 初期状態
        case downloadingModel(progress: Double) // モデルDL中（0.0〜1.0）
        case loadingModel                      // モデルロード中
        case ready                             // 認識可能
        case transcribing                      // 認識処理中
        case error(String)                     // エラー
    }

    // MARK: - プロパティ

    private(set) var state: ServiceState = .idle {
        didSet { onStateChanged?(state) }
    }

    /// 状態変更時のコールバック（AppDelegate が UI 更新に使用）
    var onStateChanged: ((ServiceState) -> Void)?

    private var whisperKit: WhisperKit?

    // MARK: - モデルセットアップ

    /// モデルのダウンロード（必要な場合）とロードを行う
    /// WhisperKit に DL/ロードを一括で任せる方式
    func setupModel() async {
        do {
            let downloadBase = AppSettings.modelDirectory
            try FileManager.default.createDirectory(
                at: downloadBase,
                withIntermediateDirectories: true
            )

            state = .loadingModel
            logger.info("WhisperKit セットアップ開始 (downloadBase: \(downloadBase.path))")

            // WhisperKit が自動でモデルの存在を確認し、
            // なければダウンロード、あればロードする
            let config = WhisperKitConfig(
                model: AppSettings.whisperModelVariant,
                downloadBase: downloadBase,
                modelRepo: AppSettings.whisperModelRepo,
                verbose: true,
                logLevel: .info,
                prewarm: true,
                load: true,
                download: true
            )
            whisperKit = try await WhisperKit(config)

            state = .ready
            logger.notice("WhisperKit 準備完了")

        } catch {
            let desc = error.localizedDescription
            state = .error(desc)
            logger.error("モデルセットアップ失敗: \(desc)")
        }
    }

    // MARK: - 音声認識

    /// WAV ファイルを音声認識し、テキストを返す
    /// - Parameter audioURL: 録音済みの WAV ファイル URL
    /// - Returns: 認識されたテキスト（失敗時は nil）
    func transcribe(audioURL: URL) async -> String? {
        guard let whisperKit = whisperKit else {
            logger.warning("WhisperKit が未初期化です")
            return nil
        }

        guard case .ready = state else {
            logger.warning("認識可能な状態ではありません")
            return nil
        }

        state = .transcribing

        do {
            let options = DecodingOptions(
                language: AppSettings.recognitionLanguage,
                temperature: 0.0,
                usePrefillPrompt: true,
                usePrefillCache: true,
                skipSpecialTokens: true,
                withoutTimestamps: false
            )

            let results = try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: options
            )

            // 全セグメントのテキストを結合
            let text = results
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined()

            state = .ready

            if text.isEmpty {
                logger.info("認識結果: (空)")
                return nil
            }

            logger.notice("認識結果: \(text)")
            return text

        } catch {
            logger.error("認識エラー: \(error.localizedDescription)")
            state = .ready
            return nil
        }
    }

    // MARK: - リソース管理

    /// モデルをアンロードしてメモリを解放する
    func unloadModel() async {
        await whisperKit?.unloadModels()
        whisperKit = nil
        state = .idle
        logger.info("モデルをアンロードしました")
    }
}
