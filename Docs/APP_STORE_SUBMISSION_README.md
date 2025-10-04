# NeurospLIT App Store Submission Guide

## 🚀 Implementation Status

### ✅ Completed Components

#### Phase 1: Critical Infrastructure
- ✅ **App Icons Setup**: Created directory structure and Contents.json for app icons
- ✅ **Debug Code Removal**: Replaced all print statements with AppLogger
- ✅ **Secure API Key Management**: Implemented KeychainService for secure storage
- ✅ **Production Configuration**: Created AppConfig for environment management

#### Phase 2: Core Functionality  
- ✅ **Test Coverage**: Created comprehensive test suites
  - SubscriptionManagerTests
  - WhipCoinsManagerTests
  - EngineCalculationTests
  - UIFlowTests
- ✅ **Network Resilience**: Implemented NetworkMonitor with retry logic
- ✅ **Error Handling**: Created ErrorView, LoadingView, and recovery mechanisms

#### Phase 3: Production Polish
- ✅ **Performance Monitoring**: PerformanceMonitor with memory tracking
- ✅ **Info.plist Configuration**: Added required keys for App Store
- ✅ **Accessibility Support**: Created AccessibilityHelpers and utilities

### 📋 Remaining Tasks for App Store Submission

## 1️⃣ App Icons Generation

**REQUIRED - App cannot be submitted without icons**

### Option A: Using the Python Script
```bash
# Install Pillow if not already installed
pip install Pillow

# Generate placeholder icons
python Scripts/generate_icons.py
```

### Option B: Manual Creation
Create icons for these sizes and add to `Resources/Assets/Assets.xcassets/AppIcon.appiconset/`:
- Icon-20.png (20x20)
- Icon-29.png (29x29)
- Icon-40.png (40x40)
- Icon-58.png (58x58)
- Icon-60.png (60x60)
- Icon-76.png (76x76)
- Icon-80.png (80x80)
- Icon-87.png (87x87)
- Icon-120.png (120x120)
- Icon-152.png (152x152)
- Icon-167.png (167x167)
- Icon-180.png (180x180)
- Icon-1024.png (1024x1024)

### Option C: Use Icon Generator Tools
- [Bakery](https://apps.apple.com/app/bakery/id1575220747)
- [IconSet](https://apps.apple.com/app/iconset/id939343785)
- [App Icon Generator](https://appicon.co)

## 2️⃣ API Key Setup

### Development Setup
1. For development/testing, add to Info.plist:
```xml
<key>DEEPSEEK_API_KEY</key>
<string>YOUR_DEV_API_KEY_HERE</string>
```

### Production Setup
1. Use the KeychainService to store API key securely:
```swift
// In your app initialization or settings screen
try KeychainService.shared.saveAPIKey("YOUR_PRODUCTION_API_KEY")
```

2. Consider implementing a server-side proxy to avoid embedding keys

## 3️⃣ Xcode Project Configuration

### Build Settings
1. Open project in Xcode
2. Select the NeurospLIT target
3. Verify these settings:
   - **Bundle Identifier**: `net.neuraldraft.NeurospLIT`
   - **Version**: `1.0`
   - **Build**: `1` (increment for each upload)
   - **Deployment Target**: iOS 15.0 or later
   - **Device**: iPhone and iPad

### Signing & Capabilities
1. Select your Development Team
2. Enable Automatic Signing
3. Add capabilities if needed:
   - In-App Purchase (already configured)
   - Network (already configured)

## 4️⃣ App Store Connect Setup

### Create App Record
1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Create new app with Bundle ID: `net.neuraldraft.NeurospLIT`

### App Information
- **Name**: NeurospLIT
- **Subtitle**: Fair tip splits in seconds
- **Category**: Finance or Business
- **Age Rating**: 4+

### Subscription Configuration
Create subscription matching the code:
- **Product ID**: `com.neurosplit.pro.monthly`
- **Reference Name**: NeurospLIT Pro
- **Duration**: 1 Month
- **Free Trial**: 3 days

### WhipCoins In-App Purchases
Create consumable products:
- `com.neurosplit.whipcoins.pack1` - 10 WhipCoins
- `com.neurosplit.whipcoins.pack2` - 25 WhipCoins
- `com.neurosplit.whipcoins.pack3` - 50 WhipCoins
- `com.neurosplit.whipcoins.pack4` - 100 WhipCoins

### Screenshots Required
Prepare screenshots for:
- iPhone 6.7" (1290 x 2796)
- iPhone 6.5" (1242 x 2688)
- iPhone 5.5" (1242 x 2208)
- iPad Pro 12.9" (2048 x 2732)

### App Description
```
NeurospLIT revolutionizes tip splitting for service industry professionals. 

Key Features:
• Describe your rules in plain English using AI
• Instant visual breakdowns with charts
• Spot discrepancies automatically
• Share splits with your team instantly
• Multiple calculation methods (equal, hours-based, percentage, role-weighted)

Perfect for restaurants, bars, salons, and any business that pools tips.

Subscription:
• Free 3-day trial
• Monthly subscription for unlimited templates
• WhipCoins for additional template generation
```

### Privacy Policy
Create and host a privacy policy covering:
- No personal data collection
- API key storage in Keychain
- Network requests to DeepSeek API
- In-app purchase handling

## 5️⃣ Testing Protocol

### Local Testing
```bash
# Run unit tests
xcodebuild test -scheme NeurospLIT -destination 'platform=iOS Simulator,name=iPhone 15'

# Check for memory leaks
# Open Xcode > Product > Profile > Leaks
```

### TestFlight Setup
1. Archive app in Xcode (Product > Archive)
2. Upload to App Store Connect
3. Add internal testers
4. Test these scenarios:
   - Fresh install flow
   - Onboarding completion
   - Template creation (all types)
   - Subscription purchase (sandbox)
   - WhipCoins purchase
   - Network disconnection/reconnection
   - App backgrounding/foregrounding

### Pre-Submission Checklist
- [ ] App icons display correctly
- [ ] No crashes in 100 test runs
- [ ] API key properly secured
- [ ] Subscription flow works in sandbox
- [ ] WhipCoins purchases work
- [ ] Network errors handled gracefully
- [ ] Memory usage < 100MB typical
- [ ] Launch time < 400ms
- [ ] All text is spell-checked
- [ ] Screenshots are high quality
- [ ] App description is compelling

## 6️⃣ Build and Submit

### Final Build
1. Set build configuration to Release
2. Clean build folder (Shift+Cmd+K)
3. Archive (Product > Archive)
4. Validate archive
5. Upload to App Store Connect

### App Review Notes
Include for reviewers:
```
This app uses AI to help service industry workers split tips fairly.

To test the main functionality:
1. Tap "Set Up Your First Template" on welcome screen
2. Describe any tip splitting scenario (e.g., "We split tips equally among all servers")
3. The AI will create a template based on your description
4. Enter a tip amount to see the calculated splits

The app includes a 3-day free trial for the subscription.
WhipCoins are used for generating additional templates.

No special hardware or accounts required for testing.
```

## 🐛 Troubleshooting

### Common Issues

**Issue**: App crashes on launch
**Solution**: Check that all required files are included in target membership

**Issue**: API calls failing
**Solution**: Verify API key is properly stored in Keychain or Info.plist

**Issue**: Subscription not working
**Solution**: Ensure StoreKit configuration file is added to project

**Issue**: Icons not showing
**Solution**: Clean build folder and ensure Contents.json is properly formatted

## 📞 Support Resources

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [StoreKit Documentation](https://developer.apple.com/documentation/storekit)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)

## 🎯 Final Steps Summary

1. **TODAY**: Generate and add app icons
2. **TODAY**: Configure API key for production
3. **TODAY**: Run full test suite
4. **TOMORROW**: Create App Store Connect record
5. **TOMORROW**: Upload TestFlight build
6. **DAY 3**: Complete testing and submit for review

## 📈 Success Metrics

Post-launch, monitor:
- Crash-free users rate (target: >99%)
- Average session duration
- Subscription conversion rate
- User ratings and reviews
- Memory usage patterns
- Network request success rates

---

**Last Updated**: October 2025
**Version**: 1.0
**Status**: Ready for final testing and submission

For questions or issues, consult the implementation plan in `/plan.md`.
