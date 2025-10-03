import XCTest
@testable import NeurospLIT

final class TemplateSelectionTests: XCTestCase {

    func testTemplateManagerSaveAndDelete() throws {
        let manager = TemplateManager()
        let template = TipTemplate(
            name: "Test",
            createdDate: Date(),
            rules: TipRules(type: .equal, formula: "Equal"),
            participants: [Participant(name: "A", role: "Server")],
            displayConfig: DisplayConfig(primaryVisualization: "pie", accentColor: "#8B5CF6", showPercentages: true, showComparison: false)
        )

        // Save
        manager.saveTemplate(template)
        XCTAssertTrue(manager.templates.contains(where: { $0.id == template.id }))

        // Delete
        manager.deleteTemplate(template)
        XCTAssertFalse(manager.templates.contains(where: { $0.id == template.id }))
    }
}


