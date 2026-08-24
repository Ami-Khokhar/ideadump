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

## Test on your iPhone (10–15 min, free Apple ID works)

1. **Pick a unique prefix.** In `project.yml`, replace every `com.example` with your own
   reverse-domain, e.g. `dev.yourname.taplog` (bundle IDs must be unique to you). Do the
   same for the App Group `group.dev.yourname.taplog`.
2. **Free account? Remove App Groups** (they need a paid account): delete the two
   `entitlements:` blocks from `project.yml` (app + widget + share), then run
   `xcodegen generate`. The app falls back to on-device storage — the core app works;
   only the widget/share-extension lose shared data. With a **paid** account, keep the
   entitlements and also register the App Group in the developer portal.
3. **Set your team.** Add your Apple Developer team ID to `project.yml` so it survives
   regeneration:

   ```yaml
   settings:
     base:
       DEVELOPMENT_TEAM: YOUR_TEAM_ID   # find it at developer.apple.com → Membership
   ```

   Then `xcodegen generate` again.
4. **Run from Xcode:** plug in the iPhone, unlock it, and trust the computer when
   prompted. Select the **TapLog** scheme, set the destination to your iPhone, Run.
5. **Trust the developer profile on the phone:** Settings → General → VPN & Device
   Management → your Apple ID → Trust. (Free accounts re-sign every 7 days — rerun from
   Xcode when the app stops opening.)
6. **Test the front doors on the device:**
   - **Deep link:** in Safari on the phone, type `taplog://log?amount=12.50&note=coffee`
     and the capture form opens pre-filled.
   - **Siri keypad:** say “Hey Siri, open capture in TapLog” — TapLog opens the keypad
     and focuses the amount. This is the same route as the **Open Expense Capture** action.
   - **Siri hands-free / Shortcuts:** say “Hey Siri, log an expense in TapLog”, or open
     Shortcuts → TapLog → “Log Expense”; Siri asks for the amount and logs without opening
     TapLog.
   - **Action Button (iPhone 15 Pro+):** Settings → Action Button → Shortcut → choose
     **Open Expense Capture**.
   - **Widget:** long-press the home screen → + → TapLog → add the medium widget; tap
     ☕️/$12 to log instantly.
   - **Lock Screen widget:** long-press the Lock Screen → Customize → Lock Screen →
     Add Widgets → TapLog; choose the circular or rectangular capture widget.
   - **iOS 18 Control Center:** open Control Center → + → Add a Control → TapLog →
     add “Log expense”.
   - **Share sheet:** share any text (e.g. a fake “You spent $12.50 at Starbucks” note)
     → TapLog → confirm in the app.
7. **Seed demo data + settings** (optional): in the app, tap **⋯** (top-right on the
   home screen) → **Settings** → Seed sample data. The same menu holds History, Recap,
   and the currency / appearance controls (16 currencies, System/Light/Dark).

Paid-account-only later steps (not needed to test): TestFlight, App Groups with
widget/sharing, App Store submission.

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
