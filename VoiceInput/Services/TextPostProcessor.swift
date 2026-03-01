import Foundation
import os

/// Claude CLI を使った認識テキストの後処理
/// フィラー除去・句読点補完などをClaude Haiku で実行する
final class TextPostProcessor {

    private let logger = Logger(subsystem: "com.voiceinput.VoiceInput", category: "TextPostProcessor")

    private static let prompt = """
        音声認識の結果を整形してください。ルール：
        - フィラー（えーと、あのー、まあ、えー、うーん等）を除去
        - 句読点を適切に補完
        - 不自然な空白を除去
        - 整形後のテキストのみを出力（説明や補足は不要）
        """

    private static let timeoutSeconds: Double = 15

    /// claude コマンドが利用可能かチェック
    static func isClaudeAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// 認識テキストを Claude で整形する
    /// - Parameter text: Whisper の認識結果
    /// - Returns: 整形済みテキスト（失敗時は元テキストをそのまま返す）
    func process(_ text: String) async -> String {
        do {
            return try await runClaude(input: text)
        } catch {
            logger.warning("Claude 後処理に失敗。元テキストを使用: \(error.localizedDescription)")
            return text
        }
    }

    private func runClaude(input: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "claude -p --model claude-haiku-4-5-20251001 '\(Self.prompt)'"]

            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            // 標準入力にテキストを書き込み、閉じる
            let inputData = Data(input.utf8)
            inputPipe.fileHandleForWriting.write(inputData)
            inputPipe.fileHandleForWriting.closeFile()

            // タイムアウト処理
            let workItem = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(
                deadline: .now() + Self.timeoutSeconds,
                execute: workItem
            )

            process.terminationHandler = { _ in
                workItem.cancel()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let result = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if process.terminationStatus == 0, !result.isEmpty {
                    continuation.resume(returning: result)
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: PostProcessError.claudeFailed(errorMessage))
                }
            }
        }
    }

    enum PostProcessError: LocalizedError {
        case claudeFailed(String)

        var errorDescription: String? {
            switch self {
            case .claudeFailed(let message):
                return "Claude 処理エラー: \(message)"
            }
        }
    }
}
