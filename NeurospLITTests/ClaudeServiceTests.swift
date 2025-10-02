import XCTest
@testable import NeurospLIT

final class ClaudeServiceTests: XCTestCase {
    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeService() -> ClaudeService {
        ClaudeService(session: makeSession(), apiKeyProvider: { "test-key" })
    }

    func testSuccessfulClaudeReply() async throws {
        let expectedText = "Hello from Claude"
        let responseJSON = "{" +
        "\"content\":[{\"text\":\"\(expectedText)\"}]" +
        "}"
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key")
            let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (http, Data(responseJSON.utf8))
        }

        let service = makeService()
        let result = try await service.sendMessage(system: nil, messages: [ClaudeMessage(role: "user", content: "Hi")])
        XCTAssertEqual(result, expectedText)
    }

    func testInvalidAPIKey401() async {
        MockURLProtocol.requestHandler = { request in
            let http = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (http, Data("{}".utf8))
        }

        let service = ClaudeService(session: makeSession(), apiKeyProvider: { "bad" })
        do {
            _ = try await service.sendMessage(system: nil, messages: [ClaudeMessage(role: "user", content: "Hi")])
            XCTFail("Expected error")
        } catch let error as ClaudeService.ClaudeError {
            switch error { case .server(401): break; default: XCTFail("Wrong error: \(error)") }
        } catch { XCTFail("Wrong error: \(error)") }
    }

    func testRateLimit429() async {
        MockURLProtocol.requestHandler = { request in
            let http = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (http, Data("{}".utf8))
        }

        let service = makeService()
        do {
            _ = try await service.sendMessage(system: nil, messages: [ClaudeMessage(role: "user", content: "Hi")])
            XCTFail("Expected error")
        } catch let error as ClaudeService.ClaudeError {
            switch error { case .server(429): break; default: XCTFail("Wrong error: \(error)") }
        } catch { XCTFail("Wrong error: \(error)") }
    }

    func testInvalidJSONOrEmptyContent() async {
        // Case 1: invalid JSON
        MockURLProtocol.requestHandler = { request in
            let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (http, Data("{".utf8))
        }
        let service1 = makeService()
        do {
            _ = try await service1.sendMessage(system: nil, messages: [ClaudeMessage(role: "user", content: "Hi")])
            XCTFail("Expected error")
        } catch { /* JSON decode error acceptable */ }

        // Case 2: valid JSON, but no text content
        MockURLProtocol.requestHandler = { request in
            let http = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = "{\"content\":[{}]}"
            return (http, Data(body.utf8))
        }
        let service2 = makeService()
        do {
            _ = try await service2.sendMessage(system: nil, messages: [ClaudeMessage(role: "user", content: "Hi")])
            XCTFail("Expected error")
        } catch let error as ClaudeService.ClaudeError {
            switch error { case .invalidResponse: break; default: XCTFail("Wrong error: \(error)") }
        } catch { XCTFail("Wrong error: \(error)") }
    }
}



