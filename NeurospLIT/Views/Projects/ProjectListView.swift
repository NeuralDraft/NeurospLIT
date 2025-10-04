import SwiftUI

struct ProjectListView: View {
    @StateObject private var projectManager = ProjectManager()
    @State private var showingCreateProject = false
    @State private var newProjectName = ""
    @State private var newProjectDescription = ""
    @State private var selectedColor = "blue"
    
    private let availableColors = ["blue", "green", "red", "purple", "orange", "yellow"]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(projectManager.projects) { project in
                    NavigationLink(destination: ProjectDetailView(project: project, projectManager: projectManager)) {
                        ProjectRowView(project: project)
                    }
                }
                .onDelete(perform: deleteProjects)
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateProject = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateProject) {
                createProjectSheet
            }
        }
    }
    
    private var createProjectSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Project Details")) {
                    TextField("Project Name", text: $newProjectName)
                    TextField("Description (Optional)", text: $newProjectDescription)
                }
                
                Section(header: Text("Color")) {
                    Picker("Color", selection: $selectedColor) {
                        ForEach(availableColors, id: \.self) { color in
                            Text(color.capitalized).tag(color)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingCreateProject = false
                        resetForm()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(newProjectName.isEmpty)
                }
            }
        }
    }
    
    private func createProject() {
        projectManager.createProject(
            name: newProjectName,
            description: newProjectDescription.isEmpty ? nil : newProjectDescription,
            color: selectedColor
        )
        showingCreateProject = false
        resetForm()
    }
    
    private func resetForm() {
        newProjectName = ""
        newProjectDescription = ""
        selectedColor = "blue"
    }
    
    private func deleteProjects(at offsets: IndexSet) {
        offsets.forEach { index in
            let project = projectManager.projects[index]
            projectManager.deleteProject(project)
        }
    }
}

struct ProjectRowView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let color = project.color {
                    Circle()
                        .fill(colorFromString(color))
                        .frame(width: 12, height: 12)
                }
                Text(project.name)
                    .font(.headline)
            }
            
            if let description = project.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(project.templateIds.count) template\(project.templateIds.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Updated \(formatDate(project.updatedDate))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "purple": return .purple
        case "orange": return .orange
        case "yellow": return .yellow
        default: return .blue
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ProjectDetailView: View {
    let project: Project
    @ObservedObject var projectManager: ProjectManager
    @State private var isEditing = false
    @State private var editedName: String
    @State private var editedDescription: String
    @State private var editedColor: String
    
    init(project: Project, projectManager: ProjectManager) {
        self.project = project
        self.projectManager = projectManager
        _editedName = State(initialValue: project.name)
        _editedDescription = State(initialValue: project.description ?? "")
        _editedColor = State(initialValue: project.color ?? "blue")
    }
    
    var body: some View {
        List {
            Section(header: Text("Details")) {
                if isEditing {
                    TextField("Name", text: $editedName)
                    TextField("Description", text: $editedDescription)
                } else {
                    Text(project.name)
                        .font(.headline)
                    if let description = project.description {
                        Text(description)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Templates")) {
                if project.templateIds.isEmpty {
                    Text("No templates in this project yet")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(project.templateIds, id: \.self) { templateId in
                        Text("Template: \(templateId.uuidString.prefix(8))...")
                            .font(.caption)
                    }
                }
            }
            
            Section(header: Text("Information")) {
                HStack {
                    Text("Created")
                    Spacer()
                    Text(formatFullDate(project.createdDate))
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Last Updated")
                    Spacer()
                    Text(formatFullDate(project.updatedDate))
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        saveChanges()
                    }
                    isEditing.toggle()
                }
            }
        }
    }
    
    private func saveChanges() {
        var updatedProject = project
        updatedProject.name = editedName
        updatedProject.description = editedDescription.isEmpty ? nil : editedDescription
        updatedProject.color = editedColor
        projectManager.updateProject(updatedProject)
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ProjectListView()
}
