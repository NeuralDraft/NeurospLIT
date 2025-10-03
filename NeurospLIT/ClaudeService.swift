// ClaudeService.swift
// Claude API Integration for NeurospLIT
// Copyright © 2025 NeurospLIT. All rights reserved.

import Foundation

/// Message structure for Claude API
struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

/// Service for interacting with Claude API
@MainActor
final class ClaudeService: ObservableObject {
    enum ClaudeError: Error, LocalizedError {
        case missingKey
        case server(Int)
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .missingKey:
                return "Claude API key is missing. Please add CLAUDE_API_KEY to Info.plist."
            case .server(let code):
                return "Server error (HTTP \(code))"
            case .invalidResponse:
                return "Invalid response from Claude API"
            }
        }
    }
    
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
        (Bundle.main.object(forInfoDictionaryKey: "CLAUDE_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    /// Send a message to Claude API
    /// - Parameters:
    ///   - system: System prompt for context
    ///   - messages: Array of messages in the conversation
    ///   - model: Claude model to use (defaults to claude-3-opus)
    ///   - maxTokens: Maximum tokens in response
    ///   - stream: Whether to stream the response
    /// - Returns: Claude's response as a string
    func sendMessage(
        system: String?,
        messages: [ClaudeMessage],
        model: String? = nil,
        maxTokens: Int = 512,
        stream: Bool = false
    ) async throws -> String {
        let key = apiKeyProvider()
        guard !key.isEmpty else {
            throw ClaudeError.missingKey
        }
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        struct RequestBody: Codable {
            let model: String
            let max_tokens: Int
            let system: String?
            let messages: [ClaudeMessage]
            let stream: Bool
        }
        
        let body = RequestBody(
            model: model ?? defaultModel,
            max_tokens: maxTokens,
            system: system,
            messages: messages,
            stream: stream
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            throw ClaudeError.server(httpResponse.statusCode)
        }
        
        struct ResponseDTO: Codable {
            struct Content: Codable {
                let text: String?
            }
            let content: [Content]
        }
        
        let decoded = try JSONDecoder().decode(ResponseDTO.self, from: data)
        let combinedText = decoded.content.compactMap { $0.text }.joined()
        
        guard !combinedText.isEmpty else {
            throw ClaudeError.invalidResponse
        }
        
        return combinedText
    }
}