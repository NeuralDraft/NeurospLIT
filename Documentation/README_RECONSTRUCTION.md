# NeurospLIT Reconstructed Layout

Date: 2025-10-04T06:10:29.644604Z

This is a **non-destructive** reconstruction of your project into best-practice buckets.
Original zip remains untouched in `/mnt/data`. Use this layout as a clean starting point.

## Buckets

- `App/` – app entry points, app-level glue, non-classified Swift files
- `Views/` – SwiftUI views
- `ViewModels/` – ObservableObject, state managers for views
- `Models/` – data models
- `Services/` – network, API, persistence, analytics services
- `Managers/` – cross-cutting managers (e.g., SubscriptionManager)
- `Engine/` – tip split math, compute logic
- `Utilities/` – extensions, helpers, formatting
- `Resources/Assets/` – images, xcassets, PDFs
- `Configs/` – Info.plist, .xcconfig, entitlements
- `Packages/` – SwiftPMs like WhipCore
- `Tests/` – unit/UI tests
- `Scripts/` – helper scripts
- `Legacy/` – anything old/unknown kept for safety

## Relink Checklist (Xcode)

1. Open the `.xcodeproj` or create a new `.xcworkspace`.
2. In Project Navigator, add new **Groups** mirroring the folders above.
3. For each bucket, **Add Files to “YourApp”...** and select the matching files in this reconstructed tree.
4. Ensure targets are checked for each file (App target for app files, Test target for `Tests/`).
5. Verify **Build Settings → SWIFT_VERSION**, **iOS Deployment Target**, and **Signing** are correct.
6. If using SwiftPM packages (e.g., WhipCore), add them via **File → Add Packages...** or drag the local package.
7. Clean build (⌘⇧K) and build (⌘B). Fix missing imports/paths as needed.
8. Run tests (⌘U).

## Notes

- All “junk” and legacy files are preserved in `Legacy/`.
- A mapping CSV (`reports/reconstruction_mapping.csv`) shows **original → new** path for every file.
- You can regenerate this structure safely; it never alters your original.
