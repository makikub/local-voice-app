import Foundation
import os

/// Claude CLI を使った認識テキストの後処理
/// フィラー除去・句読点補完などをClaude Haiku で実行する
final class TextPostProcessor {

    private let logger = Logger(subsystem: "com.voiceinput.VoiceInput", category: "TextPostProcessor")

    private static let prompt = """
        音声認識の結果を自然な日本語に整形してください。ルール：
        - 句点（。）と読点（、）を適切な位置に挿入
        - フィラー（えーと、あのー、まあ、えー、うーん等）を除去
        - 不自然な空白を除去
        - 漢字の変換ミスはそのまま残す（音声認識の出力を尊重）
        - 整形後のテキストのみを出力（説明や補足は不要）
        """

    private static let timeoutSeconds: Double = 15

    /// claude コマンドのフルパスキャッシュ
    private static var resolvedClaudePath: String? = nil

    /// /bin/zsh -l -c "which claude" でフルパスを解決してキャッシュする
    @discardableResult
    private static func resolveCLIPath() -> String? {
        if let cached = resolvedClaudePath {
            return cached
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which claude"]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let path, !path.isEmpty else { return nil }
            resolvedClaudePath = path
            return path
        } catch {
            return nil
        }
    }

    /// claude コマンドが利用可能かチェック
    static func isClaudeAvailable() -> Bool {
        return resolveCLIPath() != nil
    }

    /// 認識テキストを Claude で整形する
    /// - Parameter text: Whisper の認識結果
    /// - Returns: 整形済みテキスト（失敗時は元テキストをそのまま返す）
    func process(_ text: String) async -> String {
        do {
            return try await runClaude(input: text)
        } catch {
            logger.warning("Claude 後処理に失敗（元テキスト長: \(text.count)文字）: \(error.localizedDescription)")
            return text
        }
    }

    private func runClaude(input: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()

            if let claudePath = Self.resolveCLIPath() {
                logger.debug("claude フルパス: \(claudePath)")
                process.executableURL = URL(fileURLWithPath: claudePath)
                process.arguments = ["-p", "--model", "haiku", Self.prompt]
            } else {
                // フルパス取得失敗時はシェル経由にフォールバック
                logger.debug("claude フルパス取得失敗。シェル経由で実行")
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", "claude -p --model haiku '\(Self.prompt)'"]
            }

            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                logger.debug("claude プロセス起動: PID=\(process.processIdentifier)")
            } catch {
                logger.error("claude プロセス起動失敗: \(error.localizedDescription)")
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
                    self.logger.warning("claude タイムアウト（\(Self.timeoutSeconds)秒）。プロセスを終了")
                    process.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(
                deadline: .now() + Self.timeoutSeconds,
                execute: workItem
            )

            process.terminationHandler = { _ in
                workItem.cancel()

                // デッドロック防止: stdout/stderr をバックグラウンドで非同期読み取り
                let group = DispatchGroup()

                var outputData = Data()
                var errorData = Data()

                group.enter()
                DispatchQueue.global().async {
                    outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }

                group.enter()
                DispatchQueue.global().async {
                    errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }

                group.wait()

                let result = String(data: outputData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if process.terminationStatus == 0, !result.isEmpty {
                    continuation.resume(returning: result)
                } else {
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
