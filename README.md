# NeurospLIT - Fair Tip Splitting with AI

> **iOS app for service industry professionals** | SwiftUI | StoreKit 2 | AI-Powered

[![iOS](https://img.shields.io/badge/iOS-16.0+-blue.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green.svg)](https://developer.apple.com/xcode/swiftui/)

---

## 🎉 Project Status: Recently Reorganized!

This project has been **professionally reorganized** following Swift and iOS development best practices.

📖 **See** `REORGANIZATION_SUMMARY.md` for complete before/after comparison  
📖 **See** `Documentation/MIGRATION_GUIDE.md` for next steps

---

## 📁 Project Structure

```
NeurospLIT_reconstructed (1)/
│
├── NeurospLIT/                      # Main application source
│   ├── Application/                 # App entry point (@main)
│   ├── Models/                      # Data models (Domain + Supporting)
│   ├── Views/                       # SwiftUI views (Onboarding, Components)
│   ├── Services/                    # Business logic (API, Storage, Managers)
│   ├── Engine/                      # Tip calculation algorithms
│   ├── Utilities/                   # Helpers (Extensions, Networking)
│   └── Resources/                   # Assets (Icons, Images)
│
├── NeurospLITTests/                 # Comprehensive test suite
│   ├── ServiceTests/                # API, managers, storage tests
│   ├── EngineTests/                 # Calculation logic tests
│   ├── ViewTests/                   # UI flow tests
│   └── Mocks/                       # Test doubles
│
├── Configuration/                   # Build configs & settings
├── SupportingFiles/                 # Xcode project files
├── Documentation/                   # All project documentation
└── Scripts/                         # Build & utility scripts
```

**See `Documentation/PROJECT_STRUCTURE.md` for detailed breakdown**

---

## ✨ Features

### Core Functionality
- 🤖 **AI-Powered Onboarding** - Describe your rules in plain English
- 📊 **Multiple Calculation Methods** - Equal, hours-based, percentage, role-weighted
- 📈 **Visual Breakdowns** - Charts and detailed split views
- 💾 **Template System** - Save and reuse your configurations
- 📁 **Project Organization** - Group templates into projects for better organization
- 📱 **iOS Native** - Built with SwiftUI for modern iOS

### Business Features
- 💳 **StoreKit 2 Integration** - Subscriptions and in-app purchases
- 🪙 **WhipCoins System** - Purchase credits for template generation
- 🎁 **Referral Bonuses** - Trial extensions via referrals
- 🔐 **Secure Storage** - Keychain-based sensitive data storage

### Technical Features
- 🌐 **Network Resilience** - Automatic retry with exponential backoff
- ♿ **Accessibility** - VoiceOver support, Dynamic Type
- 📊 **Performance Monitoring** - Memory and launch time tracking
- 🧪 **Comprehensive Tests** - Unit, integration, and UI tests
- 🔒 **Privacy First** - No data collection, local storage

---

## 🏗️ Architecture

### Dependency Hierarchy

```
Level 0: Models + Utilities (no dependencies)
    ↓
Level 1: Engine (uses Models)
    ↓
Level 2: Services (uses Models + Engine)
    ↓
Level 3: Views (uses Services)
    ↓
Level 4: Application (coordinates all)
```

### Key Design Decisions

1. **Monolithic Main File** - NeurospLITApp.swift contains AppLogger and KeychainService for guaranteed compilation
2. **Clear Separation** - Each layer only depends on lower layers
3. **Test Organization** - Test structure mirrors source structure
4. **SwiftUI Native** - No UIKit dependencies
5. **Modern Concurrency** - async/await throughout

---

## 🚀 Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 16.0+ deployment target
- macOS for development
- Apple Developer account (for device testing)

### Setup

1. **Open Project**
   ```bash
   cd "NeurospLIT_reconstructed (1)"
   open SupportingFiles/NeurospLIT.xcodeproj
   ```

2. **Update Xcode References** (REQUIRED)
   - Remove old directory references
   - Add new `NeurospLIT/` folder to project
   - Ensure files are in correct targets

3. **Configure API Keys**
   - Copy `Configuration/Secrets.example.xcconfig` to `Configuration/Secrets.xcconfig`
   - Add your DeepSeek API key

4. **Generate Icons** (Optional)
   ```bash
   python Scripts/generate_icons.py
   ```

5. **Build & Run**
   - Clean build folder (⌘⇧K)
   - Build (⌘B)
   - Run (⌘R)

### Running Tests

```bash
# In Xcode
Product > Test (⌘U)

# Or command line
xcodebuild test -scheme NeurospLIT \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

## 📖 Documentation

Comprehensive documentation is available in `Documentation/`:

| Document | Purpose |
|----------|---------|
| **MIGRATION_GUIDE.md** | Step-by-step migration from old structure |
| **PROJECT_STRUCTURE.md** | Detailed structure documentation |
| **PROJECT_FEATURE.md** | Project organization feature guide |
| **APP_STORE_SUBMISSION_README.md** | App Store submission checklist |
| **AUDIT_FIXES_COMPLETE.md** | Recent code quality improvements |
| **PROJECT_REORGANIZATION_PLAN.md** | Reorganization rationale |

---

## 🧪 Testing

### Test Coverage

- ✅ **Service Tests** - API, storage, managers
- ✅ **Engine Tests** - Calculation logic, edge cases
- ✅ **View Tests** - UI flow, navigation
- ✅ **Mocks** - Test doubles for external dependencies

### Test Files

```
NeurospLITTests/
├── ServiceTests/
│   ├── ClaudeServiceTests.swift
│   ├── SubscriptionManagerTests.swift
│   ├── WhipCoinsManagerTests.swift
│   └── ...
├── EngineTests/
│   └── EngineCalculationTests.swift
├── ViewTests/
│   └── UIFlowTests.swift
└── Mocks/
    └── MockURLProtocol.swift
```

---

## 🔧 Development

### Adding New Features

**New Model**
```swift
// NeurospLIT/Models/Domain/YourModel.swift
struct YourModel: Codable {
    // ...
}
```

**New Service**
```swift
// NeurospLIT/Services/[API|Storage|Managers]/YourService.swift
@MainActor
class YourService: ObservableObject {
    // Depends on Models
}
```

**New View**
```swift
// NeurospLIT/Views/[Feature]/YourView.swift
struct YourView: View {
    // Depends on Services
}
```

**New Test**
```swift
// NeurospLITTests/[ServiceTests|ViewTests]/YourTests.swift
final class YourTests: XCTestCase {
    // Test your feature
}
```

---

## 📦 Dependencies

### External
- **None** - Fully self-contained native iOS app

### System Frameworks
- SwiftUI
- StoreKit 2
- Combine
- Network
- Security (Keychain)

---

## 🎯 Roadmap

### Completed ✅
- [x] Core tip calculation engine
- [x] AI-powered onboarding
- [x] StoreKit 2 integration
- [x] Comprehensive test suite
- [x] Network resilience
- [x] Accessibility support
- [x] Performance monitoring
- [x] Security (Keychain)
- [x] Project reorganization
- [x] Code audit fixes

### In Progress 🚧
- [ ] Update Xcode project references
- [ ] Final testing before submission

### Planned 🔮
- [ ] iPad-optimized UI
- [ ] Export to PDF
- [ ] Team collaboration features
- [ ] Historical tracking
- [ ] Multi-currency support

---

## 📄 License

Proprietary - All rights reserved

---

## 👨‍💻 Development Team

**Current Status**: Solo development  
**Contact**: Via App Store Connect

---

## 🙏 Acknowledgments

- Built with SwiftUI
- AI integration via DeepSeek
- Icon generation with Pillow
- Testing with XCTest

---

## 📱 App Store

**Bundle ID**: `net.neuraldraft.NeurospLIT`  
**Version**: 1.0  
**Target**: iOS 16.0+

**Status**: 🟡 Pre-submission (Xcode project update required)

---

## 🔗 Quick Links

- [Setup Guide](Documentation/MIGRATION_GUIDE.md)
- [Structure Docs](Documentation/PROJECT_STRUCTURE.md)
- [Submission Checklist](Documentation/APP_STORE_SUBMISSION_README.md)
- [Reorganization Summary](REORGANIZATION_SUMMARY.md)

---

**Last Updated**: October 2025  
**Version**: 2.0 (Post-Reorganization)  
**Status**: ✅ Code Complete | 🚧 Xcode Integration Pending
