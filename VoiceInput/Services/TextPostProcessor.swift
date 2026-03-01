import Foundation
import os

/// OpenAI API を使った認識テキストの後処理
/// フィラー除去・句読点補完などを gpt-4o-mini で実行する
final class TextPostProcessor {

    private let logger = Logger(subsystem: "com.voiceinput.VoiceInput", category: "TextPostProcessor")

    private static let systemPrompt = """
        音声認識の結果を自然な日本語に整形してください。ルール：
        - 句点（。）と読点（、）を適切な位置に挿入
        - フィラー（えーと、あのー、まあ、えー、うーん等）を除去
        - 不自然な空白を除去
        - 漢字の変換ミスはそのまま残す（音声認識の出力を尊重）
        - 整形後のテキストのみを出力（説明や補足は不要）
        """

    private static let apiURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private static let model = "gpt-4.1-mini"
    private static let timeoutSeconds: Double = 30

    /// API キーが設定されているかチェック
    static func isAvailable() -> Bool {
        guard let key = AppSettings.openaiAPIKey else { return false }
        return !key.isEmpty
    }

    /// 認識テキストを整形する
    /// - Parameter text: Whisper の認識結果
    /// - Returns: 整形済みテキスト（失敗時は元テキストをそのまま返す）
    func process(_ text: String) async -> String {
        do {
            return try await callAPI(input: text)
        } catch {
            logger.notice("後処理に失敗（元テキスト長: \(text.count)文字）: \(error.localizedDescription, privacy: .public)")
            return text
        }
    }

    private func callAPI(input: String) async throws -> String {
        guard let apiKey = AppSettings.openaiAPIKey, !apiKey.isEmpty else {
            throw PostProcessError.noAPIKey
        }

        var request = URLRequest(url: Self.apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Self.timeoutSeconds

        let body: [String: Any] = [
            "model": Self.model,
            "messages": [
                ["role": "system", "content": Self.systemPrompt],
                ["role": "user", "content": input]
            ],
            "temperature": 0.3,
            "max_tokens": 1024
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PostProcessError.apiFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            logger.notice("API エラー status=\(httpResponse.statusCode) body=[\(String(errorBody.prefix(200)), privacy: .public)]")
            throw PostProcessError.apiFailed("HTTP \(httpResponse.statusCode)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String

        guard let result = content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !result.isEmpty else {
            throw PostProcessError.apiFailed("Empty response")
        }

        return result
    }

    enum PostProcessError: LocalizedError {
        case noAPIKey
        case apiFailed(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "API キーが設定されていません"
            case .apiFailed(let message):
                return "API エラー: \(message)"
            }
        }
    }
}
