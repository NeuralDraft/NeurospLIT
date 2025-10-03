# NeurospLIT

**Fair tip splits in seconds. No math. Total transparency.**

NeurospLIT is a professional iOS app that revolutionizes tip splitting for restaurants and hospitality businesses. Using advanced AI and a sophisticated calculation engine, it ensures fair and transparent tip distribution among team members.

## Features

### 🎯 Smart Tip Splitting
- **Multiple splitting methods**: Equal, hours-based, percentage, role-weighted, and hybrid
- **Off-the-top deductions**: Handle manager fees and special allocations
- **Penny-perfect calculations**: Advanced rounding ensures every cent is accounted for

### 🤖 AI-Powered Setup
- **Natural language onboarding**: Describe your rules in plain English
- **Claude integration**: Optional AI assistant for complex rule creation
- **DeepSeek integration**: Smart template generation and suggestions

### 📊 Visual Analytics
- **Real-time visualizations**: Pie charts, bar graphs, and flow diagrams
- **Discrepancy detection**: Spot unfair distributions instantly
- **Comparison mode**: Compare calculated vs actual distributions

### 💰 WhipCoins System
- **Fair pricing model**: Pay based on template complexity
- **In-app currency**: Purchase WhipCoins for creating templates
- **Transparent pricing**: See exactly what you're paying for

### 📱 Professional Features
- **Template management**: Save and reuse splitting rules
- **Export capabilities**: CSV, PDF, and text formats
- **Team sharing**: Share results instantly with your team
- **Offline support**: Core calculations work without internet

## Architecture

The app is built with modern Swift and SwiftUI, following Apple's latest best practices:

- **SwiftUI**: 100% SwiftUI for all UI components
- **StoreKit 2**: Modern subscription and in-app purchase handling
- **Combine**: Reactive programming for data flow
- **Network**: Advanced network monitoring and offline handling
- **Async/Await**: Modern concurrency throughout

## Project Structure

```
NeurospLIT/
├── NeurospLIT/
│   ├── NeurospLITApp.swift        # Main app entry and core logic
│   ├── NeurospLITViews.swift      # UI components and views
│   ├── ClaudeService.swift        # Claude API integration
│   ├── ClaudeOnboardingView.swift # Claude-powered onboarding
│   └── MockURLProtocol.swift      # Testing utilities
├── Sources/
│   └── NeurospLITCore/            # Modular core (for future use)
├── NeurospLITTests/               # Test suite
└── Configs/                       # Configuration files
```

## Setup

### Requirements
- Xcode 15.0 or later
- iOS 16.0 or later deployment target
- Swift 5.9 or later

### Configuration

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/NeurospLIT.git
   cd NeurospLIT
   ```

2. **Add API Keys**
   Create `Configs/Secrets.xcconfig` from the template:
   ```bash
   cp Configs/Secrets.example.xcconfig Configs/Secrets.xcconfig
   ```
   
   Edit `Secrets.xcconfig` and add your API keys:
   ```
   DEEPSEEK_API_KEY = sk-your-deepseek-key-here
   CLAUDE_API_KEY = sk-ant-your-claude-key-here
   ```

3. **Configure StoreKit**
   - Add your in-app purchase products in App Store Connect
   - Update product IDs in `SubscriptionManager` and `WhipCoinsView`

4. **Build and Run**
   - Open `NeurospLIT.xcodeproj` in Xcode
   - Select your development team
   - Build and run on simulator or device

## Testing

The app includes comprehensive test coverage:

```bash
# Run all tests
xcodebuild test -scheme NeurospLIT -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test suite
xcodebuild test -scheme NeurospLIT -only-testing:NeurospLITTests/ClaudeServiceTests
```

## API Integration

### DeepSeek API
Used for natural language processing and template generation:
- Endpoint: `https://api.deepseek.com/v1/chat/completions`
- Models: `deepseek-chat`, `deepseek-reasoner`

### Claude API (Anthropic)
Optional integration for advanced template creation:
- Endpoint: `https://api.anthropic.com/v1/messages`
- Model: `claude-3-opus-20240229`

## Deployment

### App Store Preparation

1. **Update Info.plist**
   - Set proper bundle identifier
   - Update version and build numbers
   - Add usage descriptions for required capabilities

2. **Configure Capabilities**
   - Enable In-App Purchase
   - Enable Network Extensions (if needed)

3. **Archive and Upload**
   ```bash
   xcodebuild archive -scheme NeurospLIT -archivePath build/NeurospLIT.xcarchive
   xcodebuild -exportArchive -archivePath build/NeurospLIT.xcarchive -exportPath build/
   ```

## Contributing

We welcome contributions! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes with clear commit messages
4. Add tests for new functionality
5. Submit a pull request

## Code Style

- Use Swift's official style guide
- Maintain consistent indentation (4 spaces)
- Document all public APIs
- Keep functions focused and under 50 lines
- Use meaningful variable and function names

## License

Copyright © 2025 NeurospLIT. All rights reserved.

This is proprietary software. Unauthorized copying, modification, or distribution is prohibited.

## Support

For support, please contact:
- Email: support@neurosplit.com
- Issues: GitHub Issues page

## Acknowledgments

- Built with SwiftUI and modern Apple technologies
- AI integrations powered by DeepSeek and Anthropic Claude
- Icons from SF Symbols

---

**NeurospLIT** - Making tip splitting fair, fast, and transparent.