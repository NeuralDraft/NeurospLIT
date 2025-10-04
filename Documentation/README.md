# NeurospLIT

## Secrets & Verification

This project injects the DeepSeek API key into the generated Info.plist via build settings and xcconfig. Runtime still prefers a UserDefaults override if present.

- Configure your local secret in `Configs/Secrets.xcconfig` (git-ignored):

```
// Configs/Secrets.xcconfig
DEEPSEEK_API_KEY = sk-deepseek-xxxxxxxxxxxxxxxx
```

- The target Debug/Release are wired to use this xcconfig as Base Configuration. The generated Info.plist contains:

```
INFOPLIST_KEY_DEEPSEEK_API_KEY = $(DEEPSEEK_API_KEY)
```

- Example file (committed): `Configs/Secrets.example.xcconfig`.

### Verify the key is in the built app

You can verify that your built app contains the key using the helper script:

```
# Default: Debug, simulator, iPhone 15
./scripts/verify-deepseek-key.sh

# Or specify configuration and SDK
./scripts/verify-deepseek-key.sh --configuration Release --sdk iphonesimulator
./scripts/verify-deepseek-key.sh --sdk iphoneos --configuration Release
```

The script builds to a temporary DerivedData folder and checks `NeurospLIT.app/Info.plist` for `DEEPSEEK_API_KEY`. Output masks the value.

Note: At runtime, if the user has set a key via `UserDefaults` (e.g., in-app settings), that value takes precedence over the Info.plist value.

Monolithic SwiftUI iOS app with **DeepSeek AI integration**.
A production-grade **tip splitting engine** with financial accuracy and AI-assisted onboarding.

## Features
- ✅ Offline-first calculation engine (cents-based for accuracy)
- ✅ DeepSeek-powered onboarding assistant
- ✅ Financial-grade rounding + penny distribution
- ✅ Export to CSV / text
- ✅ Subscription manager (StoreKit 2 ready)

## Setup
1. Clone repo:
   ```bash
   git clone https://github.com/<YOUR_USERNAME>/NeurospLIT.git
   cd NeurospLIT
   ```
2. Open in Xcode:
   ```bash
   open NeurospLIT.xcodeproj
   ```
3. Add your DeepSeek API key to **Info.plist**:
   ```xml
   <key>DEEPSEEK_API_KEY</key>
   <string>[YOUR_KEY]</string>
   ```

## Development
- Architecture: Single-file monolith (`NeurospLITApp.swift`).
- Dependency: None beyond Swift + iOS 16 SDK.
- License: MIT (optional).

## Smoke Test
After setting your API key, run in simulator and test onboarding flow:
- Default model: `deepseek-chat`
- Reasoning model: `deepseek-reasoner`

## Streaming Notes
The `APIService` supports SSE streaming with `streaming: true` to accumulate tokens.

## Security
`DEEPSEEK_API_KEY` is stored in `Info.plist` for development; consider moving to an encrypted configuration or server-mediated token exchange before production release.

---

_Replace `<YOUR_USERNAME>` above with your GitHub username._

## Swift Package (WhipCore)

This repo now includes a pure Swift Package for the core tip-splitting engine and models.

Use it in another project by adding this repo as a dependency, then:

```swift
import WhipCore
```

### Build and test (SwiftPM)

```powershell
# Requires Swift toolchain
swift build
swift test -c debug

## Edge Cases & Validation

The core engine (`WhipCore.computeSplits`) validates inputs and throws `WhipCoreError` for invalid cases. The app layer catches these and surfaces them as warnings without crashing.

- Supported inputs:
   - Non-negative pool amounts (Double), up to very large values (tested to $1,000,000,000.99)
   - Any number of participants with optional `hours` and `weight` (both must be non-negative if provided)
   - Rule types: equal, hours-based, percentage, role-weighted, hybrid (`formula` like `server:60, support:40`)
   - Off-the-top rules with per-role percentages (>= 0)

- Invalid inputs (cause thrown errors):
   - Negative pool → `WhipCoreError.negativePool`
   - Empty participant list → `WhipCoreError.noParticipants`
   - Negative hours on a participant → `WhipCoreError.negativeHours(name)`
   - Negative weight on a participant → `WhipCoreError.negativeWeight(name)`
   - Negative off-the-top percentage → `WhipCoreError.invalidOffTheTopPercentage(role, pct)`
   - Negative role weight → `WhipCoreError.invalidRoleWeight(role, weight)`

- Rounding and determinism:
   - All allocations are computed in cents and normalized to the exact pool total with deterministic penny distribution.
   - Tie-breaking is stable by remainder, then by rule-specific criteria, then by name/id to ensure repeatability.

See `Tests/WhipCoreTests/EngineTests.swift` for comprehensive coverage, including zero pool, hybrid with missing roles, and very large pool stress.
```

### Build and run (Xcode)

Open `NeurospLIT.xcodeproj` and run the `NeurospLIT` target. The project relies on a generated Info.plist (no checked-in Info.plist). The API key is injected via `Configs/Secrets.xcconfig` or the build script.

## Cleanup notes

- Expo/React Native remnants under `NEUROSPLIT-main/` are no longer used and are ignored via `.gitignore`. You can delete that folder locally if you don't need it.
- The app has been consolidated into `NeurospLIT/NeurospLITApp.swift`. Legacy files under `NeurospLIT/`, `Models/`, `Utilities/`, and `Services/` are retained only for reference and are not compiled by the Xcode target. They can be safely removed if you prefer a lean tree.

## Info.plist

The Xcode target sets `GENERATE_INFOPLIST_FILE = YES` and injects `DEEPSEEK_API_KEY` at build time. There's no committed Info.plist; `NeurospLIT/AppInfo.template.plist` is an unused placeholder and can be removed.
