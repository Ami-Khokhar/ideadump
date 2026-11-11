# TapLog signed build and TestFlight runbook

Exact steps from this working tree to a TestFlight build. Written 12 October 2026 IST.

**Nothing in this file was executed by the readiness pass.** Steps 2, 4–6 and 9–11 need the
paid developer account, Apple's servers and a device, so they are instructions, not evidence.
Steps 1 and 3 were run and are marked as verified.

Bundle IDs, versions and team IDs are the current values, checked against `project.yml` and
the unsigned Release bundle on 12 October 2026.

| Thing | Value |
|---|---|
| Project | `TapLog.xcodeproj` (generated from `project.yml`; never edit it by hand) |
| Scheme | `TapLog` |
| App ID | `dev.amteshwar.taplog` |
| Widget ID | `dev.amteshwar.taplog.widget` |
| Share ID | `dev.amteshwar.taplog.share` |
| App Group | `group.dev.amteshwar.taplog` (all three targets) |
| Product ID | `dev.amteshwar.taplog.pro.lifetime` (non-consumable) |
| Marketing version | `1.0` |
| Build | `1` (raise before every upload) |
| Signing team in tree | `FKM4DL483M` (paid; the personal team `87VL9T9A8H` is no longer used) |

## 0. Preconditions

- Paid Apple Developer Program membership, active, with this Mac's Xcode signed in to the
  account that owns the paid team (Xcode → Settings → Accounts).
- The App Group and all three identifiers registered in that team, with the App Group
  capability enabled on each identifier.
- App Store Connect record exists for `dev.amteshwar.taplog` with the free price and the
  non-consumable product created.
- Export compliance answered once (the build already carries
  `ITSAppUsesNonExemptEncryption=false`).

## 1. Freeze and verify the revision (verified 12 October 2026)

```sh
cd "/Users/amteshwar/FlowyProjects/ideadump"
git status --short                 # expect only intended edits
xcodegen generate                  # pbxproj is generated; regenerate after any project.yml edit

xcodebuild test -project TapLog.xcodeproj -scheme TapLog \
  -destination 'platform=iOS Simulator,id=310F05DC-8DC4-4B38-AFF4-D5970E5DF863' \
  -parallel-testing-enabled NO -derivedDataPath /tmp/taplog-release-tests \
  CODE_SIGNING_ALLOWED=NO          # 430 tests, zero failures on 12 Oct

xcodebuild -project TapLog.xcodeproj -scheme TapLog -configuration Release \
  -sdk iphoneos -destination 'platform=iOS' -derivedDataPath /tmp/taplog-release-check \
  CODE_SIGNING_ALLOWED=NO build    # zero warnings on 12 Oct
```

Commit the exact revision that passed, and record its hash. Everything below builds from
that revision.

## 2. Switch to the paid team and raise the build number (owner action)

Two edits in `project.yml`:

```yaml
settings:
  base:
    DEVELOPMENT_TEAM: FKM4DL483M     # was 87VL9T9A8H (personal team)
    CURRENT_PROJECT_VERSION: 2       # was 1; must increase for every upload
```

Then `xcodegen generate`. The paid team is already in `project.yml`; what remains is
account work that cannot be done from here: registering the app and both extensions
under that team with the App Group, signing in to the owning account, and inspecting
the entitlements of a signed archive.

Self-check before archiving:

```sh
grep -n "DEVELOPMENT_TEAM\|CURRENT_PROJECT_VERSION" project.yml
xcodebuild -project TapLog.xcodeproj -scheme TapLog -showBuildSettings -configuration Release \
  | grep -E "DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER|MARKETING_VERSION|CURRENT_PROJECT_VERSION"
```

## 3. Confirm the App Group is on all three targets (verified in-tree 12 October 2026)

- `project.yml` declares `com.apple.security.application-groups` for `TapLog`,
  `TapLogWidget` and `TapLogShare`, all with `group.dev.amteshwar.taplog`.
- The three `Configs/*.entitlements` files carry the same group, and a unit test
  (`testAppGroupIDMatchesAllEntitlementsFiles`) pins `StoreLocator.appGroupID` to them.
- Portal side (owner): open developer.apple.com → Certificates, Identifiers & Profiles →
  Identifiers → App Groups, and confirm the group is registered and assigned to all three
  App IDs. A missing capability shows up as a signed archive whose extension cannot write
  to the shared store — the app then hides the widget/share data behind the Settings warning.

## 4. Archive (needs the paid team)

```sh
cd "/Users/amteshwar/FlowyProjects/ideadump"
STAMP=$(date +%Y%m%d-%H%M)
xcodebuild archive -project TapLog.xcodeproj -scheme TapLog \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$HOME/Library/Developer/Xcode/Archives/TapLog-1.0-$STAMP.xcarchive" \
  -allowProvisioningUpdates
```

Xcode creates or downloads the distribution profiles automatically
(`CODE_SIGN_STYLE: Automatic`). If Xcode reports a provisioning conflict, fix it in the
portal or Xcode → Settings → Accounts rather than forcing a manual profile.

## 5. Inspect the signed archive before uploading (do not skip this)

```sh
ARCH="$HOME/Library/Developer/Xcode/Archives/TapLog-1.0-<STAMP>.xcarchive"
APP="$ARCH/Products/Applications/TapLog.app"

# Versions and identifiers, all three bundles
for p in "$APP/Info.plist" "$APP/PlugIns/TapLogWidget.appex/Info.plist" \
         "$APP/PlugIns/TapLogShare.appex/Info.plist"; do
  echo "== $p"; plutil -p "$p" | grep -E \
    "CFBundleIdentifier|CFBundleShortVersionString|CFBundleVersion|MinimumOSVersion|UIDeviceFamily"
done

# Entitlements must each carry group.dev.amteshwar.taplog, and the app must be signed
for b in "$APP" "$APP/PlugIns/TapLogWidget.appex" "$APP/PlugIns/TapLogShare.appex"; do
  echo "== $b"; codesign -d --entitlements :- "$b" 2>/dev/null
done
codesign -dv --verbose=4 "$APP" 2>&1 | grep -E "TeamIdentifier|Authority|Signature"

# The embedded profile should name the paid team
security cms -D -i "$APP/embedded.mobileprovision" | plutil -p - | grep -E "TeamIdentifier|application-identifier|beta-reports-active"
```

Expected: versions `1.0` / `<build>` on all three; identifiers exactly as the table above;
all three entitlements include the App Group; TeamIdentifier `FKM4DL483M`;
`beta-reports-active` present on an App Store profile. Also confirm no `.storekit` file is
inside the archive, and that the debug strings from
[appstore-readiness-checklist.md](appstore-readiness-checklist.md) are absent.

## 6. Validate and upload

Preferred: Xcode → Window → Organizer → the archive → Distribute App → App Store Connect →
Upload (choose Validate App first if you want the checks without the upload).

Command line alternative, which uploads:

```sh
cat > /tmp/TapLog-ExportOptions.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>FKM4DL483M</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath "$ARCH" \
  -exportOptionsPlist /tmp/TapLog-ExportOptions.plist \
  -exportPath /tmp/TapLog-upload -allowProvisioningUpdates
```

`method=app-store-connect` and `destination=upload` are the Xcode 27 values (`xcodebuild
-help` lists them; `app-store` and `altool` are deprecated). If the upload is rejected,
Apple's message names the missing agreement, capability or compliance answer; fix that in
App Store Connect rather than re-archiving blindly.

## 7. Paywall review screenshot (needs one tap; nothing else does)

The paywall must be captured from a running app. It cannot be opened with `simctl` alone
because it is presented from a button.

```sh
xcrun simctl boot "iPhone 17 Pro Max" 2>/dev/null; open -a Simulator
xcrun simctl install booted /path/to/Debug-iphonesimulator/TapLog.app
xcrun simctl launch booted dev.amteshwar.taplog -seedSampleData   # Debug-only hook
```

In the app: **Recap** (bar-chart icon) → **Month** → the paywall appears (the Month view is
the paid half of the recap). Second route: **Budgets** (leaf icon) → **+** with three budgets
already configured. Screenshot with `xcrun simctl io booted screenshot paywall.png`. With the
local StoreKit configuration active in the Debug scheme the price shows the test-file $4.99;
for the review screenshot that is acceptable — App Store Connect only needs to see the
paywall, not the live price.

## 8. TestFlight install and sandbox purchase

1. In App Store Connect → TestFlight, wait for processing (usually minutes; email arrives on
   failure). Resolve any "Missing Compliance" prompt — the build already declares
   `ITSAppUsesNonExemptEncryption=false`, so it should answer itself.
2. Add yourself to an internal testing group and install via the TestFlight app on a real
   device. Internal testers need no review.
3. Purchase testing uses the **sandbox** environment automatically. Sign in with a Sandbox
   Apple Account (App Store Connect → Users and Access → Sandbox Testers) in
   Settings → App Store → Sandbox Account. Do **not** use a real Apple Account for purchase
   tests.
4. Confirm the price loads from Apple (not "—"), then run: purchase, cancel, restore on a
   fresh install, restore with no purchase, and a purchase while offline. The expected copy
   for each state is listed in the checklist's IAP section.
5. The local `Configs/TapLog.storekit` file must not be involved: it is wired only into the
   Debug run scheme. Running the archived TestFlight build never uses it.

## 9. TestFlight QA and evidence log

Record on every build: build number, device, OS, date/time (IST), and pass/fail per line of
[physical-device-qa-sheet.md](physical-device-qa-sheet.md). Keep the log with the archive's
revision hash. Fix critical/high defects and repeat the affected checks.

## 10. First submission

- App Store Connect → the version → "In-App Purchases and Subscriptions": attach
  `dev.amteshwar.taplog.pro.lifetime`. The first non-consumable must go with a version.
- Every required section complete: privacy URL, support URL, age rating questionnaire,
  screenshots, description, review notes with the steps in `appstore/metadata.md`.
- Submit with explicit owner authorization, preferring manual release if launch timing
  matters. Keep the submission notes and any reviewer reply.
- A TestFlight build is not an App Store submission. Nothing above submits anything.

## 11. After approval and on updates

- Verify the public support/privacy URLs, the storefront price and product, install from the
  App Store, and a real purchase/restore only if the owner authorizes the charge.
- Keep the archive and its dSYMs for the shipped revision. A rollback needs a new build and a
  new review; source control cannot un-ship a binary.
- For every update: raise `CURRENT_PROJECT_VERSION`, rerun steps 1, 4, 5 and 6, and repeat the
  QA sheet on the new build.
