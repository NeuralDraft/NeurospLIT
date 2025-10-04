import Foundation
import Combine

@MainActor
public class ProjectManager: ObservableObject {
    @Published public private(set) var projects: [Project] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?
    
    private let storageKey = "neurosplit.projects"
    
    public init() {
        loadProjects()
    }
    
    // MARK: - CRUD Operations
    
    public func createProject(name: String, description: String? = nil, color: String? = nil) {
        let project = Project(
            name: name,
            description: description,
            color: color
        )
        projects.append(project)
        saveProjects()
    }
    
    public func updateProject(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else {
            return
        }
        var updatedProject = project
        updatedProject.updatedDate = Date()
        projects[index] = updatedProject
        saveProjects()
    }
    
    public func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        saveProjects()
    }
    
    public func getProject(by id: UUID) -> Project? {
        return projects.first { $0.id == id }
    }
    
    public func addTemplateToProject(templateId: UUID, projectId: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else {
            return
        }
        var project = projects[index]
        if !project.templateIds.contains(templateId) {
            project.templateIds.append(templateId)
            project.updatedDate = Date()
            projects[index] = project
            saveProjects()
        }
    }
    
    public func removeTemplateFromProject(templateId: UUID, projectId: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else {
            return
        }
        var project = projects[index]
        project.templateIds.removeAll { $0 == templateId }
        project.updatedDate = Date()
        projects[index] = project
        saveProjects()
    }
    
    // MARK: - Persistence
    
    private func loadProjects() {
        isLoading = true
        defer { isLoading = false }
        
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Project].self, from: data) else {
            // Create default project if none exist
            createDefaultProject()
            return
        }
        
        projects = decoded
    }
    
    private func saveProjects() {
        guard let encoded = try? JSONEncoder().encode(projects) else {
            error = NSError(domain: "ProjectManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode projects"])
            return
        }
        
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
    
    private func createDefaultProject() {
        let defaultProject = Project(name: "Project 1", description: "Default project for organizing tip templates")
        projects = [defaultProject]
        saveProjects()
    }
}
