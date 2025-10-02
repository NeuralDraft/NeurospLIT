import Foundation

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

@MainActor
final class ClaudeService: ObservableObject {
    enum ClaudeError: Error { case missingKey, server(Int), invalidResponse }

    private let session: URLSession
    private let apiKeyProvider: () -> String
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private let defaultModel = "claude-3-opus-20240229"

    init(session: URLSession? = nil, apiKeyProvider: (() -> String)? = nil) {
        if let providedSession = session {
            self.session = providedSession
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 60
            self.session = URLSession(configuration: configuration)
        }
        self.apiKeyProvider = apiKeyProvider ?? ClaudeService.defaultAPIKeyProvider
    }

    private static func defaultAPIKeyProvider() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "CLAUDE_API_KEY") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func sendMessage(system: String?, messages: [ClaudeMessage], model: String? = nil, maxTokens: Int = 512, stream: Bool = false) async throws -> String {
        let key = apiKeyProvider()
        guard !key.isEmpty else { throw ClaudeError.missingKey }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        struct Body: Codable {
            let model: String
            let max_tokens: Int
            let system: String?
            let messages: [ClaudeMessage]
            let stream: Bool
        }
        let body = Body(model: model ?? defaultModel, max_tokens: maxTokens, system: system, messages: messages, stream: stream)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ClaudeError.server(code)
        }

        struct ResponseDTO: Codable { struct Content: Codable { let text: String? }; let content: [Content] }
        let decoded = try JSONDecoder().decode(ResponseDTO.self, from: data)
        let combined = decoded.content.compactMap { $0.text }.joined()
        guard !combined.isEmpty else { throw ClaudeError.invalidResponse }
        return combined
    }
}



