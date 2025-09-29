# NeurospLIT (Monolithic)

Single-file SwiftUI iOS app with a production-grade tip‑splitting engine inlined into `WhipTip/WhipTipApp.swift`. The rest of the repository is archived under `Legacy/` for reference.

## TL;DR
- Open `WhipTip.xcodeproj` in Xcode (macOS).
- Add `DEEPSEEK_API_KEY` via `Configs/Secrets.xcconfig` (preferred) or at runtime via UserDefaults.
- Run the `WhipTip` target (iOS 16+). No Swift Package dependencies.

## What changed
- Fully monolithic: the core models and engine (validation, rounding, penny distribution) are inlined into `WhipTipApp.swift`.
- Removed SPM package linkage; `Sources/` and tests were moved to `Legacy/`.
- Xcode project now builds only the app target; no test target or external frameworks.

## Setup
1) Secrets (build‑time, recommended)
- Copy `Configs/Secrets.example.xcconfig` to `Configs/Secrets.xcconfig` and set:
  ```
  DEEPSEEK_API_KEY = sk-deepseek-xxxxxxxxxxxxxxxx
  ```
- The build script “Inject DEEPSEEK_API_KEY” writes the value into the generated Info.plist.

2) Secrets (runtime override, optional)
- Key resolution priority: UserDefaults override > Info.plist (from xcconfig). If neither is set, onboarding shows "Missing API Key" and prompts for entry. In this state, API calls are blocked until a key is provided.

3) Open and run
- Open `WhipTip.xcodeproj` in Xcode and run the `WhipTip` target on a simulator or device.

Notes (Windows)
- Building iOS requires a Mac. The VS Code task shown in this repo targets macOS `xcodebuild` and won’t run on Windows.

## Engine overview
- Inputs: `TipTemplate { participants, rules, displayConfig }` and a `pool` amount (Double).
- Rule types supported: equal, hours‑based, percentage, role‑weighted, hybrid (`formula` like `server:60, support:40`).
- Off‑the‑top: Optional per‑role percentages removed before the main allocation.
- Validation: Negative numbers and inconsistent rules throw typed errors; the UI surfaces them as warnings and preserves input.
- Rounding: All math in cents. Deterministic penny distribution with stable tie‑breaking (by remainder, then rule‑specific signal, then name/id).

## Quick test drive
After the app launches, try a small pool with a few participants across roles. You can export splits to CSV using the in‑app control.

## Security
- Store your API key in the xcconfig for development builds. For production, consider server‑mediated tokens or another secure distribution.

## Legal
- Privacy Policy: Docs/PRIVACY.md
- Terms of Service: Docs/TERMS.md

## Legacy archive
Everything not required for the monolithic build lives in `Legacy/` (kept for reference, not compiled):
- Former Swift package `Sources/WhipCore/` and tests under `Tests/`
- CI workflows, SwiftLint config, scripts
- Prior `Utilities/`, `Services/`, `Engine/`, `Models/`, and React Native proofs under `WHIPTIP-main/`

To restore the package/tests temporarily:
- Move `Legacy/Sources` back to `Sources/` and `Legacy/Tests` back to `Tests/`.
- Re‑add the Swift package to the Xcode project or build with SwiftPM.
- Re‑enable CI/Lint from `Legacy/.github` and `Legacy/.swiftlint.yml` as needed.

Optional CI guard (if you restore CI):
- Add a step post-build to assert `WhipTip.app/Info.plist` contains `DEEPSEEK_API_KEY` and fail if missing to avoid shipping without a usable config.

## Changelog
- Removal: All legacy WhipCoins code (manager, views, pricing types, UI bindings) removed. Subscriptions (StoreKit 2) remain intact.
- Fix: Chat DTOs corrected (e.g., `ChatRequestDTO.stream: Bool`, `ChatChoiceDTO.Message.content: String`).
- Fix: Debug logging typos corrected (`whitespacesAndNewlines`, `prefix`).
- Cleanup: DEBUG test helper hooks deduplicated.

## Appendix: Build details
- Xcode generates Info.plist (`GENERATE_INFOPLIST_FILE = YES`).
- A shell script build phase injects `DEEPSEEK_API_KEY` into the built Info.plist.
- No additional frameworks are required.

