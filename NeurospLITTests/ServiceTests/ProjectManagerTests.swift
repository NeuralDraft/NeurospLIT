import XCTest
import Combine
@testable import NeurospLIT

@MainActor
final class ProjectManagerTests: XCTestCase {
    var projectManager: ProjectManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        projectManager = ProjectManager()
        cancellables = Set<AnyCancellable>()
        // Clear UserDefaults for clean test state
        UserDefaults.standard.removeObject(forKey: "neurosplit.projects")
    }
    
    override func tearDown() async throws {
        projectManager = nil
        cancellables = nil
        UserDefaults.standard.removeObject(forKey: "neurosplit.projects")
        try await super.tearDown()
    }
    
    func testCreateProject() {
        let initialCount = projectManager.projects.count
        
        projectManager.createProject(name: "Test Project", description: "Test Description")
        
        XCTAssertEqual(projectManager.projects.count, initialCount + 1)
        XCTAssertEqual(projectManager.projects.last?.name, "Test Project")
        XCTAssertEqual(projectManager.projects.last?.description, "Test Description")
    }
    
    func testUpdateProject() {
        projectManager.createProject(name: "Original Name", description: "Original Description")
        guard var project = projectManager.projects.first else {
            XCTFail("Project not created")
            return
        }
        
        project.name = "Updated Name"
        project.description = "Updated Description"
        projectManager.updateProject(project)
        
        let updatedProject = projectManager.projects.first
        XCTAssertEqual(updatedProject?.name, "Updated Name")
        XCTAssertEqual(updatedProject?.description, "Updated Description")
    }
    
    func testDeleteProject() {
        projectManager.createProject(name: "To Delete")
        let initialCount = projectManager.projects.count
        
        guard let project = projectManager.projects.first else {
            XCTFail("Project not created")
            return
        }
        
        projectManager.deleteProject(project)
        
        XCTAssertEqual(projectManager.projects.count, initialCount - 1)
    }
    
    func testGetProjectById() {
        projectManager.createProject(name: "Findable Project")
        guard let project = projectManager.projects.first else {
            XCTFail("Project not created")
            return
        }
        
        let foundProject = projectManager.getProject(by: project.id)
        
        XCTAssertNotNil(foundProject)
        XCTAssertEqual(foundProject?.name, "Findable Project")
    }
    
    func testAddTemplateToProject() {
        projectManager.createProject(name: "Template Project")
        guard let project = projectManager.projects.first else {
            XCTFail("Project not created")
            return
        }
        
        let templateId = UUID()
        projectManager.addTemplateToProject(templateId: templateId, projectId: project.id)
        
        let updatedProject = projectManager.getProject(by: project.id)
        XCTAssertTrue(updatedProject?.templateIds.contains(templateId) ?? false)
    }
    
    func testRemoveTemplateFromProject() {
        projectManager.createProject(name: "Template Project")
        guard let project = projectManager.projects.first else {
            XCTFail("Project not created")
            return
        }
        
        let templateId = UUID()
        projectManager.addTemplateToProject(templateId: templateId, projectId: project.id)
        projectManager.removeTemplateFromProject(templateId: templateId, projectId: project.id)
        
        let updatedProject = projectManager.getProject(by: project.id)
        XCTAssertFalse(updatedProject?.templateIds.contains(templateId) ?? true)
    }
    
    func testDuplicateTemplateNotAdded() {
        projectManager.createProject(name: "Unique Template Project")
        guard let project = projectManager.projects.first else {
            XCTFail("Project not created")
            return
        }
        
        let templateId = UUID()
        projectManager.addTemplateToProject(templateId: templateId, projectId: project.id)
        projectManager.addTemplateToProject(templateId: templateId, projectId: project.id)
        
        let updatedProject = projectManager.getProject(by: project.id)
        XCTAssertEqual(updatedProject?.templateIds.filter { $0 == templateId }.count, 1)
    }
    
    func testProjectPersistence() {
        projectManager.createProject(name: "Persistent Project", description: "Should persist")
        let projectId = projectManager.projects.first?.id
        
        // Create new manager instance to test loading from UserDefaults
        let newManager = ProjectManager()
        
        XCTAssertFalse(newManager.projects.isEmpty)
        XCTAssertNotNil(newManager.getProject(by: projectId!))
        XCTAssertEqual(newManager.projects.first?.name, "Persistent Project")
    }
}
