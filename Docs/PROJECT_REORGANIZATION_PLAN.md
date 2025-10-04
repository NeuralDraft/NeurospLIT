# NeurospLIT Project Reorganization Plan

## Current Issues
1. Mixed file types in App/ directory (configs, models, mocks, persistence)
2. Test files mixed with implementation (ClaudeServiceTests.swift in Services/)
3. Flat structure doesn't reflect dependencies
4. No clear separation between app code and configuration

## Swift/iOS Best Practices Structure

### Recommended Organization

```
NeurospLIT/
├── NeurospLIT/                          # Main app target source
│   ├── Application/                     # App lifecycle & entry
│   │   ├── NeurospLITApp.swift         # @main entry point (monolithic)
│   │   └── AppDelegate.swift           # (if needed)
│   │
│   ├── Models/                          # Data models (no dependencies)
│   │   ├── Domain/                      # Core business models
│   │   │   ├── TipTemplate.swift
│   │   │   ├── Participant.swift
│   │   │   ├── TipRules.swift
│   │   │   └── DisplayConfig.swift
│   │   └── Supporting/
│   │       ├── SplitResult.swift
│   │       └── Errors.swift
│   │
│   ├── Views/                           # UI Layer (depends on Models, Services)
│   │   ├── Onboarding/
│   │   │   └── ClaudeOnboardingView.swift
│   │   ├── Dashboard/
│   │   │   ├── MainDashboardView.swift
│   │   │   └── RootView.swift
│   │   └── Components/
│   │       ├── ErrorView.swift
│   │       └── LoadingView.swift
│   │
│   ├── Services/                        # Business logic (depends on Models)
│   │   ├── API/
│   │   │   ├── ClaudeService.swift
│   │   │   └── APIService.swift
│   │   ├── Storage/
│   │   │   ├── Persistence.swift
│   │   │   └── TemplateManager.swift
│   │   └── Managers/
│   │       ├── SubscriptionManager.swift
│   │       └── WhipCoinsManager.swift
│   │
│   ├── Engine/                          # Core calculation logic
│   │   ├── TipCalculationEngine.swift
│   │   └── EngineHarness.swift
│   │
│   ├── Utilities/                       # Helpers (minimal dependencies)
│   │   ├── Extensions/
│   │   ├── Helpers/
│   │   │   ├── AccessibilityHelpers.swift
│   │   │   ├── PerformanceMonitor.swift
│   │   │   └── TemplateUtilities.swift
│   │   └── Networking/
│   │       └── NetworkMonitor.swift
│   │
│   └── Resources/                       # Non-code assets
│       └── Assets.xcassets/
│           └── AppIcon.appiconset/
│
├── NeurospLITTests/                     # Unit tests
│   ├── ModelTests/
│   ├── ServiceTests/
│   │   ├── ClaudeServiceTests.swift
│   │   ├── SubscriptionManagerTests.swift
│   │   └── WhipCoinsManagerTests.swift
│   ├── EngineTests/
│   │   └── EngineCalculationTests.swift
│   ├── ViewTests/
│   │   └── UIFlowTests.swift
│   └── Mocks/
│       └── MockURLProtocol.swift
│
├── NeurospLITUITests/                   # UI tests (if any)
│
├── Configuration/                       # Build configs & settings
│   ├── Info.plist
│   ├── PrivacyInfo.xcprivacy
│   ├── Secrets.example.xcconfig
│   └── Debug.xcconfig
│
├── Supporting Files/                    # Xcode project & schemes
│   ├── NeurospLIT.xcodeproj/
│   │   ├── project.pbxproj
│   │   └── xcshareddata/
│   │       └── xcschemes/
│   │           └── NeurospLIT.xcscheme
│   └── .gitignore
│
├── Scripts/                             # Build & utility scripts
│   ├── generate_icons.py
│   └── setup_dev_environment.sh
│
└── Documentation/                       # Project docs
    ├── README.md
    ├── APP_STORE_SUBMISSION_README.md
    ├── AUDIT_FIXES_COMPLETE.md
    └── API_DOCUMENTATION.md
```

## Dependency Hierarchy (Bottom-up)

1. **Models** (Level 0) - No dependencies
2. **Utilities** (Level 0-1) - May depend on Models
3. **Engine** (Level 1) - Depends on Models
4. **Services** (Level 2) - Depends on Models, Engine, Utilities
5. **Views** (Level 3) - Depends on all lower levels
6. **Application** (Level 4) - Coordinates everything

## Special Considerations for Monolithic Architecture

Since `NeurospLITApp.swift` contains AppLogger and KeychainService:
- This is acceptable for small projects
- Services/KeychainService.swift becomes redundant (can be removed)
- App/AppConfig.swift becomes redundant (can be removed)
- Keep one source of truth

## Files to Move

### From App/ to appropriate locations:
- `Models.swift` → Models/Domain/ (split into separate files)
- `Errors.swift` → Models/Supporting/
- `Persistence.swift` → Services/Storage/
- `MockURLProtocol.swift` → Tests/Mocks/
- `ContentView.swift` → DELETE (deprecated/empty)
- `Dummy.swift` → DELETE or Tests/Mocks/
- `project.pbxproj` → Supporting Files/NeurospLIT.xcodeproj/
- `NeurospLIT.xcscheme` → Supporting Files/NeurospLIT.xcodeproj/xcshareddata/xcschemes/
- `PrivacyInfo.xcprivacy` → Configuration/
- `AppConfig.swift` → DELETE (consolidated into NeurospLITApp.swift)

### From Services/:
- `ClaudeServiceTests.swift` → Tests/ServiceTests/
- `KeychainService.swift` → DELETE (consolidated into NeurospLITApp.swift)
- `NetworkMonitor.swift` → Utilities/Networking/ or DELETE if consolidated

### From Utilities/:
- Keep all as-is, just reorganize into subdirectories

### From Views/:
- `NeurospLITApp.swift` → Application/
- `ClaudeOnboardingView.swift` → Views/Onboarding/
- `Components/ErrorView.swift` → Views/Components/ (keep)

### From Configs/:
- Move to Configuration/

### From Docs/:
- Move to Documentation/

## Implementation Order

1. Create new directory structure
2. Move test files first
3. Move configuration files
4. Move utility files
5. Move service files
6. Move view files  
7. Move main app file
8. Update Xcode project references
9. Verify imports still work
10. Run tests to validate

## Benefits

1. **Clear Dependencies**: Easy to see what depends on what
2. **Scalability**: New features know where to go
3. **Testability**: Test files mirror source structure
4. **Maintainability**: Find files quickly
5. **Team Collaboration**: Standard structure everyone understands
6. **Build Performance**: Xcode can better optimize builds
7. **Code Review**: Changes are localized by concern

## Breaking Changes

- None if done correctly
- All files remain in same Xcode target
- Import statements remain unchanged (same module)
- Only physical file locations change

