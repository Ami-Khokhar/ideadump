# Release verification runbook

Every row is a gate that must be closed before submission, and every gate needs
one artifact — a command's output, a screenshot, or a signed document — kept
next to the row or under `reports/release-evidence/`. A row with no artifact is
**not tested**, however likely it is to pass. No gate in this runbook has been
closed for this release; the only checks that have run are the source and static
ones the status column names.

This is an engineering checklist, not legal or tax advice, and it does not
authorize any account change, hosting change or submission. Items marked
**owner** or **adviser** cannot be completed by a coding agent. The "owner"
column names who must produce the artifact.

## How to read the status column

- **not tested** — no artifact exists. Do not treat this as passing.
- **partly checked** — a source or static check passed; the device or account
  check has not run.
- **blocked** — waiting on an owner or qualified-adviser action, or on Apple's
  account chain. These are honest blockers, not worker-completed clearance.

## Security and build gates

| # | Gate | Exact evidence | Owner | Status |
|---|------|----------------|-------|--------|
| S1 | Signed Release build of the app and both extensions | `codesign -dvvv` for `TapLog.app`, `TapLogWidget.appex`, `TapLogShare.appex`; the archive path; `codesign --verify --deep --strict` output | owner | not tested |
| S2 | Toolchain and SDK minimum (Xcode 26 / iOS 26 SDK) | `xcodebuild -version`, `xcodebuild -showsdks`, and `DTPlatformVersion` / `DTSDKName` from the built `Info.plist` | owner | not tested |
| S3 | File protection on device, before first unlock and after relock | On a physical device: the class of the SwiftData store, its `-wal` and `-shm` files, and `taplog-export.csv`. Capture with the device rebooted but not yet unlocked, and again after a lock. Use the file-protection attribute shown by the OS; the app must not set a weaker class than iOS applies by default | owner | not tested |
| S4 | Widget and Siri stay on-device | The widget and Siri flows produce an entry without a network request from TapLog; App Privacy answers match; each `.appex` bundles `PrivacyInfo.xcprivacy` | owner | partly checked (manifests and source), device pass not tested |
| S5 | Canary logs carry no records | Log one entry whose note is `taplog-canary-<uuid>` and whose amount is 4711, then send the same marker through the share sheet, a purchase and Siri. In the simulator capture with `log stream --predicate 'subsystem == "dev.amteshwar.taplog"'`; on a device use the same predicate in Console.app with the device selected, or `log collect --device`. No amount, note, category name or export text from it appears | owner | not tested |
| S6 | Canary network traffic | A proxy or Network instrument over the same actions with the same `taplog-canary-<uuid>` marker: the only traffic is to Apple for StoreKit. Any other host is a finding | owner | not tested |
| S7 | Real StoreKit behaviour in sandbox | Screenshots and receipts for: a completed purchase, a restore on a clean install, an Ask-to-Buy **pending**, and a **refund/revocation** removing the entitlement. Product id must be `dev.amteshwar.taplog.pro.lifetime` | owner | blocked on the Paid Apps Agreement, tax form and bank account showing Active |
| S8 | Verified entitlement policy | Source inspection: `ProEntitlement.grantsPro` requires the expected product id and no revocation date, and `isPro` is never persisted. Unit tests in `ProStoreTests` cover the store paths | owner | partly checked (tests pass), not a substitute for S7 |
| S9 | Screenshots and accessibility | The App Store screenshots; a VoiceOver pass over capture, history, budgets, recap, settings and the privacy screen; Dynamic Type at the largest size | owner | not tested |
| S10 | Current privacy disclosures | App Privacy label, the hosted privacy-policy page, the in-app Privacy screen, and the support page all agree with `PrivacyInfo.xcprivacy` | owner; counsel for the policy text | partly checked (in-app screen exists and its content test passes), hosting pending |
| S11 | Export compliance | `ITSAppUsesNonExemptEncryption` in the built `Info.plist`, and the matching App Store Connect answer | owner | partly checked (source), built value not tested |

## Legal and account gates (owner or qualified adviser only)

These are not engineering tasks. They are listed so they are not mistaken for
tests an agent can run. None of them has been completed.

| # | Decision or action | Exact evidence | Who | Status |
|---|--------------------|----------------|-----|--------|
| L1 | Apple Developer Program enrollment approved | Approval notice; exact legal name matches the ID used | owner | blocked |
| L2 | Paid Apps Agreement signed by the Account Holder | App Store Connect shows Active | owner | blocked |
| L3 | US tax form (W-8BEN) submitted | App Store Connect shows Active; the Part II treaty line was confirmed before submitting, because the form locks after | owner; **Chartered Accountant** for the treaty line | blocked |
| L4 | Bank account Active | App Store Connect shows Active; holder name matches the bank record | owner | blocked |
| L5 | EU DSA trader status decided and, if "trader", verified | The declared status and its verification; the address shown publicly matches the privacy policy | owner; **lawyer** before declaring "not a trader" while selling an in-app purchase | blocked |
| L6 | Trademark position for the app name | A public trademark search and a filing decision | owner; **trademark attorney** for the filing strategy | blocked |
| L7 | Jurisdiction review of the privacy analysis | A written position on the controller analysis for on-device data and for support email | owner; **lawyer** | blocked |
| L8 | In-app purchase attached to version 1.0 with a review screenshot | App Store Connect version page shows the IAP under "In-App Purchases and Subscriptions" | owner | blocked on L2–L4 |

### India DPDP: phased commencement

The Digital Personal Data Protection Act, 2023 and the DPDP Rules, 2025 commence
in phases. As published, the Rules came into force in stages from 13 November
2025, and the main obligations commonly cited (Rules 3 and 5–16) start 18 months
later, in about **May 2027**. Until those dates, they are not a live requirement;
they are a scheduled one. This runbook does not state whether any obligation
already applies — that is a question for counsel. The engineering-relevant point
is only that the app's architecture (nothing leaves the device except StoreKit
and support email) keeps the surface small, and that the support-email flow is
where the duties would attach.

Sources for the legal rows, to be read in full before relying on them:

- DPDP Act 2023 and DPDP Rules 2025, Ministry of Electronics and Information
  Technology, meity.gov.in
- App Review Guidelines, developer.apple.com/app-store/review/guidelines/
- DSA trader requirements, developer.apple.com (App Store Connect Help)
- Apple Developer Program enrollment, tax and banking, developer.apple.com
- Required-reason API and reason codes,
  developer.apple.com/documentation/bundleresources/
- Apple TN3186, troubleshooting in-app purchase availability in the sandbox
- Encrypting your app's files, developer.apple.com/documentation

## What this runbook does not do

- It does not claim any check above has passed. Every unexecuted row is marked
  **not tested** or **blocked**.
- It does not give legal or tax advice. Rows L1–L8 name the qualified adviser and
  the artifact they must produce.
- It does not change accounts, host anything, or submit the app. Those are owner
  actions, taken after the gates above are closed.
