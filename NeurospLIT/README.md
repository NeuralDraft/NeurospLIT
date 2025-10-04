# NeurospLIT - Main Application Source

This directory contains the main source code for the NeurospLIT iOS application.

## Directory Structure

```
NeurospLIT/
├── Application/         # App entry point (@main)
├── Models/             # Data models
│   ├── Domain/         # Core business entities
│   └── Supporting/     # Supporting types (errors, etc.)
├── Views/              # SwiftUI views
│   ├── Onboarding/     # Onboarding flow
│   ├── Dashboard/      # Main dashboard
│   └── Components/     # Reusable UI components
├── Services/           # Business logic services
│   ├── API/            # External API integrations
│   ├── Storage/        # Data persistence
│   └── Managers/       # State managers
├── Engine/             # Tip calculation logic
├── Utilities/          # Helpers and extensions
│   ├── Extensions/     # Swift extensions
│   ├── Helpers/        # Utility functions
│   └── Networking/     # Network utilities
└── Resources/          # Assets (images, colors, etc.)
```

## Dependency Hierarchy

This structure follows a clear dependency hierarchy:

```
Level 0: Models + Utilities/Extensions (no dependencies)
    ↓
Level 1: Engine (depends on Models)
    ↓
Level 2: Services (depends on Models + Engine)
    ↓
Level 3: Views (depends on Services)
    ↓
Level 4: Application (coordinates everything)
```

**Rule**: Higher levels can depend on lower levels, but never the reverse.

## Key Files

- **Application/NeurospLITApp.swift** - Main app entry point with @main attribute
- **Models/Domain/Models.swift** - Core data models (TipTemplate, Participant, etc.)
- **Services/API/ClaudeService.swift** - AI integration service
- **Engine/Engine.swift** - Tip calculation algorithms
- **Views/Onboarding/ClaudeOnboardingView.swift** - AI-powered onboarding

## Monolithic Architecture Note

NeurospLITApp.swift contains consolidated helper classes:
- AppLogger (debug logging)
- KeychainService (secure storage)
- NetworkMonitor (may be extracted to Utilities/Networking)

This is intentional for small projects to guarantee compilation without complex module dependencies.

## Adding New Code

### New Model
```swift
// NeurospLIT/Models/Domain/YourModel.swift
struct YourModel: Codable {
    // ...
}
```

### New Service
```swift
// NeurospLIT/Services/[API|Storage|Managers]/YourService.swift
class YourService {
    // Depends on Models
}
```

### New View
```swift
// NeurospLIT/Views/[Feature]/YourView.swift
struct YourView: View {
    // Depends on Services
}
```

### New Utility
```swift
// NeurospLIT/Utilities/Helpers/YourHelper.swift
struct YourHelper {
    // Minimal dependencies
}
```

## Best Practices

1. **One Concern Per File** - Don't mix models with services
2. **Respect Dependencies** - Never import from higher levels
3. **Use Protocols** - For testability and flexibility
4. **Keep Views Thin** - Business logic belongs in Services
5. **Test Everything** - Mirror this structure in NeurospLITTests/

## Related Documentation

- `../Documentation/PROJECT_STRUCTURE.md` - Complete structure documentation
- `../Documentation/MIGRATION_GUIDE.md` - Migration from old structure
- `../Documentation/APP_STORE_SUBMISSION_README.md` - Submission guide

## Xcode Integration

This directory should be added to the **NeurospLIT target** in Xcode:

1. Right-click in Xcode Project Navigator
2. "Add Files to 'NeurospLIT'..."
3. Select this `NeurospLIT/` folder
4. Check "Create groups"
5. Ensure "NeurospLIT" target is checked

All files will then be compiled as part of the main app.

---

**Last Updated**: October 2025
**Architecture**: Monolithic with organized structure
**iOS Version**: 16.0+
**Swift Version**: 5.0+
