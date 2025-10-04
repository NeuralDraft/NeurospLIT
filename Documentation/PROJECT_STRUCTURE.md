# NeurospLIT Project Structure

## Overview
This document describes the reorganized project structure following Swift and iOS development best practices.

## Directory Structure

```
NeurospLIT_reconstructed (1)/
│
├── NeurospLIT/                          # Main application source (Xcode target)
│   ├── Application/                     # App entry point & lifecycle
│   │   └── NeurospLITApp.swift         # @main app entry (monolithic)
│   │
│   ├── Models/                          # Data models (Level 0 - no dependencies)
│   │   ├── Domain/                      # Core business entities
│   │   │   └── Models.swift            # TipTemplate, Participant, TipRules, etc.
│   │   └── Supporting/
│   │       └── Errors.swift            # Error types
│   │
│   ├── Views/                           # UI layer (Level 3)
│   │   ├── Onboarding/
│   │   │   └── ClaudeOnboardingView.swift
│   │   ├── Dashboard/                   # (placeholder for future MainDashboard)
│   │   └── Components/
│   │       └── ErrorView.swift         # Reusable error UI component
│   │
│   ├── Services/                        # Business logic layer (Level 2)
│   │   ├── API/
│   │   │   └── ClaudeService.swift     # External API integration
│   │   ├── Storage/
│   │   │   └── Persistence.swift       # Data persistence
│   │   └── Managers/                    # (for SubscriptionManager, WhipCoinsManager)
│   │
│   ├── Engine/                          # Core calculation logic (Level 1)
│   │   ├── Engine.swift                # Tip calculation algorithms
│   │   └── EngineHarness.swift         # Engine wrapper/facade
│   │
│   ├── Utilities/                       # Helpers (Level 0-1)
│   │   ├── Extensions/                  # (for future Swift extensions)
│   │   ├── Helpers/
│   │   │   ├── AccessibilityHelpers.swift
│   │   │   ├── PerformanceMonitor.swift
│   │   │   └── TemplateUtilities.swift
│   │   └── Networking/                  # (for NetworkMonitor if extracted)
│   │
│   └── Resources/                       # Non-code assets
│       └── Assets.xcassets/
│           └── AppIcon.appiconset/
│               └── Contents.json
│
├── NeurospLITTests/                     # Unit tests (mirror source structure)
│   ├── ModelTests/                      # (future tests for models)
│   ├── ServiceTests/
│   │   ├── ClaudeServiceTests.swift
│   │   ├── SubscriptionManagerTests.swift
│   │   ├── WhipCoinsManagerTests.swift
│   │   ├── OnboardingAPITests.swift
│   │   ├── ClaudeTemplateExtractorTests.swift
│   │   ├── ExportTests.swift
│   │   └── TemplateSelectionTests.swift
│   ├── EngineTests/
│   │   └── EngineCalculationTests.swift
│   ├── ViewTests/
│   │   └── UIFlowTests.swift
│   └── Mocks/
│       └── MockURLProtocol.swift
│
├── Configuration/                       # Build configurations & settings
│   ├── PrivacyInfo.xcprivacy           # Privacy manifest
│   ├── AppInfo.template.plist          # Info.plist template
│   └── Secrets.example.xcconfig        # Config example
│
├── SupportingFiles/                     # Xcode project files
│   └── NeurospLIT.xcodeproj/
│       ├── project.pbxproj             # Xcode project definition
│       └── xcshareddata/
│           └── xcschemes/
│               └── NeurospLIT.xcscheme
│
├── Scripts/                             # Build & utility scripts
│   ├── generate_icons.py               # Icon generation
│   └── save.py                         # (legacy script)
│
├── Documentation/                       # Project documentation
│   ├── README.md                       # Main project README
│   ├── APP_STORE_SUBMISSION_README.md  # Submission guide
│   ├── AUDIT_FIXES_COMPLETE.md         # Audit fix documentation
│   ├── PROJECT_REORGANIZATION_PLAN.md  # This reorganization plan
│   ├── PROJECT_STRUCTURE.md            # This file
│   └── README_RECONSTRUCTION.md        # Original reconstruction notes
│
└── [Legacy Directories]                # Old structure (can be removed after verification)
    ├── App/                            # ❌ Deprecated - files moved
    ├── Views/                          # ❌ Deprecated - files moved
    ├── Services/                       # ❌ Deprecated - files moved
    ├── Engine/                         # ❌ Deprecated - files moved
    ├── Utilities/                      # ❌ Deprecated - files moved
    ├── Tests/                          # ❌ Deprecated - files moved
    ├── Configs/                        # ❌ Deprecated - files moved
    ├── Docs/                           # ❌ Deprecated - files moved
    └── Resources/                      # ❌ Deprecated - files moved
```

## Dependency Hierarchy

The structure follows a clear dependency hierarchy from bottom to top:

```
Level 0 (Foundation - No dependencies)
├── Models/Domain/
├── Models/Supporting/
└── Utilities/Extensions/

Level 1 (Core Logic - Depends on Models)
├── Engine/
└── Utilities/Helpers/

Level 2 (Services - Depends on Models & Engine)
├── Services/API/
├── Services/Storage/
└── Services/Managers/

Level 3 (Presentation - Depends on Services)
└── Views/

Level 4 (Application - Coordinates everything)
└── Application/NeurospLITApp.swift
```

## File Mappings

### Moved Files

| Old Location | New Location | Reason |
|-------------|--------------|--------|
| `Views/NeurospLITApp.swift` | `NeurospLIT/Application/` | Main entry point |
| `Views/ClaudeOnboardingView.swift` | `NeurospLIT/Views/Onboarding/` | View organization |
| `Views/Components/ErrorView.swift` | `NeurospLIT/Views/Components/` | Reusable component |
| `Services/ClaudeService.swift` | `NeurospLIT/Services/API/` | External API service |
| `App/Persistence.swift` | `NeurospLIT/Services/Storage/` | Data persistence service |
| `App/Models.swift` | `NeurospLIT/Models/Domain/` | Core data models |
| `App/Errors.swift` | `NeurospLIT/Models/Supporting/` | Error definitions |
| `Engine/Engine.swift` | `NeurospLIT/Engine/` | Calculation engine |
| `Engine/EngineHarness.swift` | `NeurospLIT/Engine/` | Engine wrapper |
| `Utilities/*.swift` | `NeurospLIT/Utilities/Helpers/` | Helper utilities |
| `Tests/*Tests.swift` | `NeurospLITTests/*/` | Test organization |
| `App/MockURLProtocol.swift` | `NeurospLITTests/Mocks/` | Test mock |
| `Configs/*` | `Configuration/` | Build configurations |
| `App/PrivacyInfo.xcprivacy` | `Configuration/` | Privacy manifest |
| `App/project.pbxproj` | `SupportingFiles/NeurospLIT.xcodeproj/` | Xcode project |
| `App/NeurospLIT.xcscheme` | `SupportingFiles/NeurospLIT.xcodeproj/xcshareddata/xcschemes/` | Build scheme |
| `Docs/*` | `Documentation/` | Documentation files |

### Removed/Deprecated Files

| File | Status | Reason |
|------|--------|--------|
| `App/ContentView.swift` | Can be deleted | Empty/deprecated file |
| `App/Dummy.swift` | Can be deleted | Placeholder/unused |
| `App/AppConfig.swift` | Consolidated | Now in NeurospLITApp.swift |
| `Services/KeychainService.swift` | Consolidated | Now in NeurospLITApp.swift |
| `Services/NetworkMonitor.swift` | Retained separately | Can be moved to Utilities/Networking/ |

## Benefits of New Structure

### 1. **Clear Separation of Concerns**
- Models don't depend on anything
- Services depend only on models
- Views depend on services
- Application coordinates everything

### 2. **Easy Navigation**
- Find files by their function
- Test files mirror source structure
- No more digging through mixed directories

### 3. **Scalability**
- New features know where to go
- Clear where to add new models, services, or views
- Prevents "junk drawer" directories

### 4. **Better Collaboration**
- Standard structure team members expect
- Easy code reviews (changes localized by concern)
- Clear ownership boundaries

### 5. **Xcode-Friendly**
- Matches typical Xcode project organization
- Better build performance (dependency tree)
- Easier to configure targets

### 6. **Maintainability**
- Refactoring is easier
- Dependencies are obvious
- Technical debt is visible

## Xcode Integration

### Setting Up in Xcode

1. Open `SupportingFiles/NeurospLIT.xcodeproj/` in Xcode
2. Remove references to old directories
3. Add new `NeurospLIT/` folder structure
4. Ensure all files are in the correct target:
   - Main app files → NeurospLIT target
   - Test files → NeurospLITTests target
5. Verify build settings reference correct paths
6. Clean build folder (⌘⇧K)
7. Build project (⌘B)

### Target Membership

**NeurospLIT Target** should include:
- All files in `NeurospLIT/` directory
- `Configuration/` files (referenced, not compiled)
- `NeurospLIT/Resources/` assets

**NeurospLITTests Target** should include:
- All files in `NeurospLITTests/` directory
- Test configuration files

## Best Practices Going Forward

### Adding New Features

**New Model:**
```
NeurospLIT/Models/Domain/YourModel.swift
```

**New Service:**
```
NeurospLIT/Services/[API|Storage|Managers]/YourService.swift
```

**New View:**
```
NeurospLIT/Views/[FeatureName]/YourView.swift
```

**New Test:**
```
NeurospLITTests/[ModelTests|ServiceTests|ViewTests]/YourTests.swift
```

### File Organization Rules

1. **One concern per file** - Don't mix models with services
2. **Mirror test structure** - Test file location matches source file
3. **Group by feature** - Related files in same directory
4. **Dependencies flow down** - Higher levels depend on lower levels, never up
5. **Flat is better** - Don't nest too deeply (max 3 levels)

## Migration Checklist

- [x] Create new directory structure
- [x] Move application files
- [x] Move model files
- [x] Move view files
- [x] Move service files
- [x] Move engine files
- [x] Move utility files
- [x] Move test files
- [x] Move configuration files
- [x] Move documentation files
- [ ] Update Xcode project references
- [ ] Verify all imports work
- [ ] Run tests to validate
- [ ] Remove old directories
- [ ] Update README with new structure

## Notes

- The old directory structure is kept temporarily for safety
- After Xcode project is updated and tests pass, old directories can be removed
- Import statements don't need to change (same module)
- Only physical file locations changed

---

**Last Updated**: October 2025
**Version**: 2.0 (Post-Reorganization)
