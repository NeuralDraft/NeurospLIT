# Quick Start: Using the Project Feature

## What is the Project Feature?

The Project feature allows you to organize your tip templates into logical groups. For example:
- Group templates by restaurant or venue
- Organize by event type (weddings, corporate events, etc.)
- Separate by time period (Summer 2024, Fall 2024, etc.)

## Key Concepts

### Project
A container that holds multiple tip templates. Each project has:
- A unique name
- Optional description
- Optional color for visual identification
- List of associated templates
- Creation and update timestamps

### Default Project
When you first use the app, a default "Project 1" is automatically created to get you started.

## How to Use

### Creating a New Project

1. Open the `ProjectListView` in your app
2. Tap the "+" button in the navigation bar
3. Enter:
   - Project name (required)
   - Description (optional)
   - Select a color (optional)
4. Tap "Create"

### Editing a Project

1. Navigate to a project from the list
2. Tap "Edit" in the navigation bar
3. Modify the name or description
4. Tap "Save"

### Deleting a Project

1. In the project list, swipe left on a project
2. Tap "Delete"
3. Confirm deletion

### Associating Templates with Projects

When creating or editing a tip template, you can specify which project it belongs to using the `projectId` property:

```swift
let template = TipTemplate(
    name: "Restaurant Template",
    createdDate: Date(),
    rules: myRules,
    participants: myParticipants,
    displayConfig: myConfig,
    projectId: myProject.id  // Associate with a project
)
```

## Code Examples

### Using ProjectManager

```swift
import SwiftUI

struct MyView: View {
    @StateObject private var projectManager = ProjectManager()
    
    var body: some View {
        VStack {
            // List all projects
            ForEach(projectManager.projects) { project in
                Text(project.name)
            }
            
            // Create a new project
            Button("Create Project") {
                projectManager.createProject(
                    name: "New Project",
                    description: "My project description",
                    color: "blue"
                )
            }
        }
    }
}
```

### Adding Templates to Projects

```swift
// Add a template to a project
projectManager.addTemplateToProject(
    templateId: myTemplate.id,
    projectId: myProject.id
)

// Remove a template from a project
projectManager.removeTemplateFromProject(
    templateId: myTemplate.id,
    projectId: myProject.id
)
```

### Retrieving a Project

```swift
// Get a specific project by ID
if let project = projectManager.getProject(by: projectId) {
    print("Found project: \(project.name)")
    print("Template count: \(project.templateIds.count)")
}
```

## UI Components

### ProjectListView
The main view for browsing all projects. Features:
- Scrollable list of projects
- Create button in toolbar
- Swipe-to-delete functionality
- Template count display
- Relative update timestamps

### ProjectDetailView
Detailed view of a single project. Features:
- Project information
- Edit mode for updating details
- List of associated templates
- Creation and update timestamps

### ProjectRowView
Reusable component for displaying project information in lists. Shows:
- Color indicator (if set)
- Project name and description
- Template count
- Last update time

## Integration with Main App

To add the Project feature to your main app:

```swift
import SwiftUI

@main
struct NeurospLITApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                
                ProjectListView()
                    .tabItem {
                        Label("Projects", systemImage: "folder")
                    }
            }
        }
    }
}
```

## Data Persistence

Projects are automatically saved to UserDefaults whenever you:
- Create a new project
- Update a project
- Delete a project
- Add/remove templates from a project

No manual save action is required!

## Best Practices

1. **Use Descriptive Names**: Give your projects clear, meaningful names
2. **Add Descriptions**: Use descriptions to provide context for each project
3. **Color Coding**: Use different colors for different types of projects
4. **Regular Cleanup**: Delete projects you no longer need
5. **Template Organization**: Keep related templates together in the same project

## Troubleshooting

### Project Not Saving
- Projects save automatically to UserDefaults
- Make sure you're using the ProjectManager methods (createProject, updateProject, etc.)
- Check that the app has permissions to write to UserDefaults

### Templates Not Showing
- Ensure the template's `projectId` matches the project's `id`
- Use `addTemplateToProject()` to properly associate templates

### Default Project Missing
- The default "Project 1" is created automatically on first launch
- If it's missing, try creating a new project manually

## Further Reading

For more detailed information, see:
- `Documentation/PROJECT_FEATURE.md` - Complete feature documentation
- `Documentation/PROJECT_IMPLEMENTATION_SUMMARY.md` - Technical implementation details
- `NeurospLIT/Services/Managers/ProjectManager.swift` - Source code with inline comments

## Support

For questions or issues:
1. Check the documentation files
2. Review the test files for usage examples
3. Examine the source code for ProjectManager and views

---

**Quick Links:**
- [Project Feature Documentation](PROJECT_FEATURE.md)
- [Implementation Summary](PROJECT_IMPLEMENTATION_SUMMARY.md)
- [Main README](../README.md)
