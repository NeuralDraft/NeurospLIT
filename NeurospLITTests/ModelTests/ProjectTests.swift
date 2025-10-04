import XCTest
@testable import NeurospLIT

final class ProjectTests: XCTestCase {
    
    func testProjectInitialization() {
        let project = Project(name: "Test Project", description: "Test Description")
        
        XCTAssertEqual(project.name, "Test Project")
        XCTAssertEqual(project.description, "Test Description")
        XCTAssertNotNil(project.id)
        XCTAssertNotNil(project.createdDate)
        XCTAssertNotNil(project.updatedDate)
        XCTAssertTrue(project.templateIds.isEmpty)
    }
    
    func testProjectWithTemplates() {
        let templateId = UUID()
        let project = Project(
            name: "Project 1",
            description: "First project",
            templateIds: [templateId]
        )
        
        XCTAssertEqual(project.templateIds.count, 1)
        XCTAssertTrue(project.templateIds.contains(templateId))
    }
    
    func testProjectCodable() throws {
        let project = Project(
            name: "Codable Test",
            description: "Testing encoding/decoding",
            color: "blue"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(project)
        
        let decoder = JSONDecoder()
        let decodedProject = try decoder.decode(Project.self, from: data)
        
        XCTAssertEqual(project.id, decodedProject.id)
        XCTAssertEqual(project.name, decodedProject.name)
        XCTAssertEqual(project.description, decodedProject.description)
        XCTAssertEqual(project.color, decodedProject.color)
    }
    
    func testProjectWithoutDescription() {
        let project = Project(name: "Minimal Project")
        
        XCTAssertEqual(project.name, "Minimal Project")
        XCTAssertNil(project.description)
        XCTAssertNil(project.color)
    }
    
    func testTipTemplateProjectReference() {
        let projectId = UUID()
        let template = TipTemplate(
            name: "Test Template",
            createdDate: Date(),
            rules: TipRules(type: .equal),
            participants: [],
            displayConfig: DisplayConfig(
                primaryVisualization: "chart",
                accentColor: "blue",
                showPercentages: true,
                showComparison: false
            ),
            projectId: projectId
        )
        
        XCTAssertEqual(template.projectId, projectId)
    }
}
