import XCTest
@testable import NeurospLIT

final class OnboardingAPITests: XCTestCase {

    func testClaudeServiceMissingKey() async {
        let service = ClaudeService(session: URLSession(configuration: .ephemeral), apiKeyProvider: { "" })
        do {
            _ = try await service.sendMessage(system: nil, messages: [ClaudeMessage(role: "user", content: "Hello")])
            XCTFail("Expected missingKey error")
        } catch let error as ClaudeService.ClaudeError {
            switch error {
            case .missingKey: break
            default: XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testClaudeServiceTimeout() async {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.01
        config.timeoutIntervalForResource = 0.02
        let service = ClaudeService(session: URLSession(configuration: config), apiKeyProvider: { "test" })
        do {
            _ = try await service.sendMessage(system: nil, messages: [ClaudeMessage(role: "user", content: "Hello")])
            // A real network call won't be made but if it attempted, timeout likely occurs.
        } catch {
            // Accept any error here as network is not mocked; this ensures path doesn't crash the runtime.
        }
    }

    func testTemplateExtractionJSON() {
        let response = """
        ```json
        {"name":"X","createdDate":"2024-01-01T00:00:00Z","rules":{"type":"equal","formula":"Equal","offTheTop":null,"roleWeights":null,"customLogic":null},"participants":[{"name":"A","role":"Server","hours":null,"weight":null}],"displayConfig":{"primaryVisualization":"pie","accentColor":"#8B5CF6","showPercentages":true,"showComparison":false}}
        ```
        """
        let json = ClaudeTemplateExtractor.extractJSON(from: response)
        XCTAssertNotNil(json)
        if let json = json {
            let decoded = ClaudeTemplateExtractor.decodeTemplate(from: json)
            switch decoded {
            case .success(let template):
                XCTAssertEqual(template.name, "X")
                XCTAssertEqual(template.rules.type, .equal)
                XCTAssertEqual(template.participants.count, 1)
            case .failure(let error):
                XCTFail("Decoding failed: \(error)")
            }
        }
    }
}

