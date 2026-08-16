# TapLog

Local-first iPhone expense logging — capture a purchase in under five seconds from the
Action Button, a widget, Siri, or the share sheet. All data stays on the device.
See `investor-pitch.md` for the vision and `build-plan.md` for the milestone plan.

## Prerequisites

- macOS with Xcode (targets iOS 17+; tested with Xcode 26.x)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build & run

```sh
xcodegen generate
open TapLog.xcodeproj
```

Select the **TapLog** scheme and an iPhone simulator, then Run.

CLI build + run on a simulator:

```sh
xcodebuild -project TapLog.xcodeproj -scheme TapLog \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

xcrun simctl boot "iPhone 17 Pro"
APP=$(find ~/Library/Developer/Xcode/DerivedData -path "*TapLog*/Build/Products/Debug-iphonesimulator/TapLog.app" | head -1)
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.example.taplog -seedSampleData   # seeds 12 demo entries
```

Deep link to the capture form:

```sh
xcrun simctl openurl booted "taplog://log?amount=12.50&note=coffee&category=Coffee"
```

## Status

**All code milestones (M0–M5 + the agent-portion of M6) are built and verified on the
iOS 26.5 simulator.** Remaining before TestFlight: real-device code signing, Action
Button / widget-on-lock-screen checks, and capture timing — see `build-plan.md`.

## Project layout

| Path | What it is |
|---|---|
| `project.yml` | XcodeGen spec — **the single source of truth**. Regenerate with `xcodegen generate` after adding files or targets; never hand-edit the `.xcodeproj` |
| `Sources/TapLog/` | App sources (Models, Shared, Capture, List, Undo) |
| `Configs/` | Generated Info.plist and entitlements (recreated by XcodeGen) |

## Notes

- The SwiftData store lives in the App Group container `group.com.example.taplog` so the
  widget and share-extension targets (M3/M4) can read it. If the group container isn't
  available the app transparently falls back to on-device Application Support storage.
- **Free Apple ID:** App Groups require a paid developer account. For free-account device
  testing, delete the `entitlements:` block from `project.yml`, run `xcodegen generate`,
  and the app will use the on-device fallback.
- Change the bundle ID / App Group prefix (`com.example`) before TestFlight.
