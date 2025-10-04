# GitHub to Xcode Integration Guide

## ✅ Project Setup Complete!

This iOS project is now fully configured for seamless GitHub-to-Xcode workflow.

## 🚀 Quick Start (GitHub → Xcode)

### Method 1: Direct from GitHub (Recommended)
1. Go to your GitHub repository
2. Click the green **"Code"** button
3. Select **"Open with Xcode"**
4. Xcode will clone and open the project automatically
5. Build and run with ⌘+R

### Method 2: Clone and Open
```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/betterthanu.git
cd betterthanu

# Quick setup and open
./setup.sh
# OR
make open
```

### Method 3: Manual Clone
```bash
git clone https://github.com/YOUR_USERNAME/betterthanu.git
cd betterthanu
open NeurospLIT.xcodeproj
```

## 📁 Project Structure

```
betterthanu/                        # Repository root
├── NeurospLIT.xcodeproj/          # ✅ Xcode project (at root for GitHub integration)
│   ├── project.pbxproj
│   └── xcshareddata/
│       └── xcschemes/
├── NeurospLIT/                     # Source code
│   ├── Application/
│   ├── Models/
│   ├── Views/
│   ├── Services/
│   ├── Engine/
│   ├── Utilities/
│   └── Resources/
├── NeurospLITTests/                # Test suite
├── Configuration/                   # Build configs
├── Scripts/                        # Build & utility scripts
├── Documentation/                  # Project docs
├── LICENSE                         # MIT License
├── README.md                       # Project overview
├── Makefile                        # Build commands
├── setup.sh                        # Unix setup script
├── setup.ps1                       # Windows setup script
├── .gitignore                      # Git exclusions
└── .xcode-version                  # Minimum Xcode version
```

## 🛠️ Available Commands

### Using Makefile
```bash
make help      # Show all commands
make setup     # Initial project setup
make build     # Build the app
make test      # Run tests
make clean     # Clean build artifacts
make open      # Open in Xcode
make run       # Build and run in simulator
```

### Direct Commands
```bash
# Setup (first time)
./setup.sh

# Open in Xcode
open NeurospLIT.xcodeproj

# Build
xcodebuild -scheme NeurospLIT -configuration Debug build

# Test
xcodebuild test -scheme NeurospLIT -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 🔑 Configuration

### API Keys Setup
1. Copy the example config:
   ```bash
   cp Configuration/Secrets.example.xcconfig Configuration/Secrets.xcconfig
   ```
2. Edit `Configuration/Secrets.xcconfig` and add your API keys
3. This file is gitignored and won't be committed

### Development Team
1. Open the project in Xcode
2. Select the project in the navigator
3. Go to "Signing & Capabilities"
4. Select your development team

## 📱 Building for Device

1. Connect your iOS device
2. Select your device in Xcode's device selector
3. Ensure you have a valid development certificate
4. Build and run (⌘+R)

## 🏗️ Continuous Integration

The project structure supports CI/CD workflows:

```yaml
# Example GitHub Actions workflow
name: iOS Build
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build
        run: make build
      - name: Test
        run: make test
```

## ❓ Troubleshooting

### "Open with Xcode" not showing on GitHub
- Ensure `.xcodeproj` is at the repository root ✅
- The repository must be public or you must be logged into GitHub

### Build fails after cloning
1. Run setup: `./setup.sh` or `make setup`
2. Clean build: `make clean`
3. Add your API keys to `Configuration/Secrets.xcconfig`
4. Select your development team in Xcode

### Can't find scheme
- The scheme is at: `NeurospLIT.xcodeproj/xcshareddata/xcschemes/NeurospLIT.xcscheme`
- In Xcode: Product → Scheme → Manage Schemes → Make sure "Shared" is checked

### Windows Users
- Use `setup.ps1` instead of `setup.sh`
- Transfer the project to a Mac for actual iOS development
- Or use GitHub's web-based "Open with Xcode" feature

## ✨ Features Enabled

- ✅ **GitHub "Open with Xcode"** - Direct integration
- ✅ **One-command setup** - `./setup.sh` or `make setup`
- ✅ **Makefile commands** - Standard build commands
- ✅ **Clean .gitignore** - Proper Xcode exclusions
- ✅ **MIT License** - Open source ready
- ✅ **Version tracking** - `.xcode-version` file
- ✅ **Cross-platform scripts** - Unix and Windows support

## 📚 Additional Resources

- [Xcode Documentation](https://developer.apple.com/documentation/xcode)
- [GitHub's Xcode Integration](https://github.com/features/codespaces)
- [App Store Submission Guide](Documentation/APP_STORE_SUBMISSION_README.md)
- [Project Documentation](Documentation/README.md)

---

**Project:** NeurospLIT  
**Platform:** iOS 16.0+  
**Language:** Swift 5.0+  
**Framework:** SwiftUI  
**Status:** Ready for development and App Store submission
