import XCTest
@testable import NeurospLIT

final class ClaudeTemplateExtractorTests: XCTestCase {
    
    func testExtractJSONFromFencedCodeBlock() {
        let response = """
        Here's your tip splitting template:
        
        ```json
        {
            "name": "Restaurant Team Split",
            "createdDate": "2024-01-01T00:00:00Z",
            "rules": {
                "type": "percentage",
                "formula": "servers:70,support:30",
                "offTheTop": null,
                "roleWeights": {"server": 35, "busser": 15, "host": 15},
                "customLogic": null
            },
            "participants": [
                {"name": "Alex", "role": "Server", "hours": null, "weight": 35},
                {"name": "Sam", "role": "Server", "hours": null, "weight": 35},
                {"name": "Jordan", "role": "Busser", "hours": null, "weight": 15},
                {"name": "Pat", "role": "Host", "hours": null, "weight": 15}
            ],
            "displayConfig": {
                "primaryVisualization": "pie",
                "accentColor": "#8B5CF6",
                "showPercentages": true,
                "showComparison": true
            }
        }
        ```
        
        This template splits tips with 70% to servers and 30% to support staff.
        """
        
        let extractedJSON = ClaudeTemplateExtractor.extractJSON(from: response)
        XCTAssertNotNil(extractedJSON)
        
        if let json = extractedJSON {
            XCTAssertTrue(json.contains("\"name\": \"Restaurant Team Split\""))
            XCTAssertTrue(json.contains("\"type\": \"percentage\""))
        }
    }
    
    func testExtractJSONFromGenericFencedCodeBlock() {
        let response = """
        Here's your template:
        
        ```
        {
            "name": "Simple Split",
            "createdDate": "2024-01-01T00:00:00Z",
            "rules": {
                "type": "equal",
                "formula": "Equal split",
                "offTheTop": null,
                "roleWeights": null,
                "customLogic": null
            },
            "participants": [
                {"name": "Alice", "role": "Server", "hours": null, "weight": null}
            ],
            "displayConfig": {
                "primaryVisualization": "pie",
                "accentColor": "#8B5CF6",
                "showPercentages": true,
                "showComparison": false
            }
        }
        ```
        """
        
        let extractedJSON = ClaudeTemplateExtractor.extractJSON(from: response)
        XCTAssertNotNil(extractedJSON)
        
        if let json = extractedJSON {
            XCTAssertTrue(json.contains("\"name\": \"Simple Split\""))
            XCTAssertTrue(json.contains("\"type\": \"equal\""))
        }
    }
    
    func testDecodeValidTemplate() {
        let jsonString = """
        {
            "name": "Test Template",
            "createdDate": "2024-01-01T00:00:00Z",
            "rules": {
                "type": "equal",
                "formula": "Equal split",
                "offTheTop": null,
                "roleWeights": null,
                "customLogic": null
            },
            "participants": [
                {"name": "Alice", "role": "Server", "hours": null, "weight": null}
            ],
            "displayConfig": {
                "primaryVisualization": "pie",
                "accentColor": "#8B5CF6",
                "showPercentages": true,
                "showComparison": false
            }
        }
        """
        
        let result = ClaudeTemplateExtractor.decodeTemplate(from: jsonString)
        
        switch result {
        case .success(let template):
            XCTAssertEqual(template.name, "Test Template")
            XCTAssertEqual(template.rules.type, .equal)
            XCTAssertEqual(template.participants.count, 1)
            XCTAssertEqual(template.participants.first?.name, "Alice")
        case .failure(let error):
            XCTFail("Failed to decode template: \(error.localizedDescription)")
        }
    }
    
    func testDecodeInvalidTemplate() {
        let invalidJSON = """
        {
            "name": "Invalid Template",
            "invalidField": "This should cause an error"
        }
        """
        
        let result = ClaudeTemplateExtractor.decodeTemplate(from: invalidJSON)
        
        switch result {
        case .success:
            XCTFail("Should have failed to decode invalid template")
        case .failure(let error):
            XCTAssertNotNil(error.localizedDescription)
        }
    }
    
    func testNoJSONInResponse() {
        let response = "This is just a regular response with no JSON."
        
        let extractedJSON = ClaudeTemplateExtractor.extractJSON(from: response)
        XCTAssertNil(extractedJSON)
    }
}
