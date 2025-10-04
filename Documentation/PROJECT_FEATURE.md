# Project Feature Documentation

## Overview

The Project feature allows users to organize their tip templates into logical groups called "Projects". This helps manage multiple tip templates across different contexts, such as different restaurants, events, or time periods.

## Data Model

### Project

A `Project` is a container for organizing multiple tip templates.

```swift
public struct Project: Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var description: String?
    public var createdDate: Date
    public var updatedDate: Date
    public var color: String?
    public var templateIds: [UUID]
}
```

**Properties:**
- `id`: Unique identifier for the project
- `name`: Name of the project (required)
- `description`: Optional description for additional context
- `createdDate`: When the project was created
- `updatedDate`: Last modification timestamp
- `color`: Optional color identifier for visual differentiation
- `templateIds`: Array of UUID references to associated tip templates

### TipTemplate Enhancement

The `TipTemplate` model has been enhanced with an optional project reference:

```swift
public struct TipTemplate: Codable, Identifiable {
    // ... existing properties
    public var projectId: UUID?
}
```

## Service Layer

### ProjectManager

`ProjectManager` is the main service for managing project CRUD operations and persistence.

**Location:** `NeurospLIT/Services/Managers/ProjectManager.swift`

**Key Features:**
- Create, read, update, and delete projects
- Add/remove templates from projects
- Automatic persistence using UserDefaults
- Published properties for SwiftUI integration
- Default "Project 1" created on first launch

**Public API:**

```swift
// Create a new project
func createProject(name: String, description: String? = nil, color: String? = nil)

// Update an existing project
func updateProject(_ project: Project)

// Delete a project
func deleteProject(_ project: Project)

// Retrieve a specific project
func getProject(by id: UUID) -> Project?

// Template management
func addTemplateToProject(templateId: UUID, projectId: UUID)
func removeTemplateFromProject(templateId: UUID, projectId: UUID)
```

## User Interface

### ProjectListView

Main view for displaying and managing projects.

**Location:** `NeurospLIT/Views/Projects/ProjectListView.swift`

**Features:**
- List of all projects with visual indicators
- Create new projects with name, description, and color
- Edit existing projects
- Delete projects (swipe to delete)
- Template count display
- Relative timestamp for last update

### ProjectDetailView

Detailed view for a specific project.

**Features:**
- Project information display
- List of associated templates
- Edit mode for updating project details
- Creation and update timestamps

### ProjectRowView

Reusable component for displaying project information in lists.

**Features:**
- Color-coded visual indicator
- Project name and description
- Template count
- Last update timestamp (relative format)

## Testing

### Model Tests

**Location:** `NeurospLITTests/ModelTests/ProjectTests.swift`

Tests cover:
- Project initialization
- Codable conformance (JSON encoding/decoding)
- Template references
- Optional properties

### Service Tests

**Location:** `NeurospLITTests/ServiceTests/ProjectManagerTests.swift`

Tests cover:
- CRUD operations
- Template association/disassociation
- Persistence across manager instances
- Duplicate template prevention
- Error handling

## Usage Examples

### Creating a Project

```swift
let projectManager = ProjectManager()
projectManager.createProject(
    name: "Summer 2024 Events",
    description: "All tip templates for summer events",
    color: "blue"
)
```

### Adding Templates to a Project

```swift
let templateId = template.id
let projectId = project.id
projectManager.addTemplateToProject(templateId: templateId, projectId: projectId)
```

### Displaying Projects

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        ProjectListView()
    }
}
```

## Architecture

The Project feature follows the established architecture pattern:

```
Models (Level 0)
    ↓
Services (Level 2) - ProjectManager
    ↓
Views (Level 3) - ProjectListView, ProjectDetailView
```

## Data Persistence

Projects are persisted using `UserDefaults` with the key `"neurosplit.projects"`. Data is automatically:
- Loaded on ProjectManager initialization
- Saved after every modification (create, update, delete, template changes)
- Encoded/decoded using Swift's Codable protocol

## Default Behavior

On first launch, if no projects exist, a default project named "Project 1" is automatically created to provide a starting point for users.

## Future Enhancements

Potential improvements for future versions:
- Project sharing and collaboration
- Project templates/presets
- Advanced filtering and search
- Export/import projects
- Project statistics and analytics
- Cloud sync support
- Project archiving
- Nested projects/sub-projects
- Bulk template operations

## Integration Points

To integrate the Project feature into the main app:

1. Add `ProjectListView` to the main navigation structure
2. Update template creation/editing flows to allow project selection
3. Add project filtering to template lists
4. Consider adding quick actions for project management
5. Update app state management to include ProjectManager

## File Structure

```
NeurospLIT/
├── Models/Domain/
│   └── Models.swift (contains Project struct)
├── Services/Managers/
│   └── ProjectManager.swift
└── Views/Projects/
    └── ProjectListView.swift (contains all project views)

NeurospLITTests/
├── ModelTests/
│   └── ProjectTests.swift
└── ServiceTests/
    └── ProjectManagerTests.swift
```
