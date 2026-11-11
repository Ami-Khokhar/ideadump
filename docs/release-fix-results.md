# TapLog release fixes — verified local status

**Code fixes are implemented and verified. App Store submission is still pending external setup and real-device QA.** DeepSeek v4.1 Flash workers authored the app changes through Agent Relay. Codex orchestrated, reviewed, generated the project and ran verification. No app implementation was authored by the orchestrator.

Local fix commit: `92fcd99`. Its verified worker-authored patch is now applied to `/Users/amteshwar/FlowyProjects/ideadump`. The checkout retains the original branch and existing edits. No push or merge was performed.

Scope: branch `release/readiness-fixes` in `/private/tmp/taplog-release-fixes`, based on snapshot `54f7b31` of the original dirty checkout. Original user edits were preserved. Assumptions: local-first iPhone app, one app currency without conversion, lifetime Pro and free export. Support email/public URLs remain pending by the owner's instruction.

## Fixed

| Finding | Result | Evidence |
|---|---|---|
| R1 failed intent insert | Refused Siri/widget inserts are removed before throwing, so later saves cannot persist the refused attempt. Unrelated edits are preserved. | Production writer failure regression on SwiftData. |
| R2 undo after wipe | Successful wipe invalidates undo and widget receipt. Fetch/save failure does not announce success or reset progress. | Production wipe/undo regressions. |
| R3 invisible widget save | Extension process refuses an unshared store before any row, counter or receipt. App-host execution can safely use its own fallback. | Both gate branches and writer side effects tested. |
| R4 shared amounts | Full-token localized parsing, valid grouping, caps, OTP/account/balance guards, and conservative multi-amount rejection. | Parser regressions and pre-fix failure probes. |
| R5 currency/export | Existing-record currency changes require a no-conversion warning. Query failure also requires confirmation. CSV includes current currency, uses unique files and mitigates formula-leading whitespace/control prefixes. | Currency/export regressions and native warning/cancel/relaunch check. |
| R6 category usage | Successful category edits move usage with the same save. Failed forward/undo saves restore exact counter snapshots. Undo preserves later logs. Pending confirmation uses its original date. | Counter, rollback and date regressions. |
| R7 paywall | Loading/unavailable/retry/pending/unverified states, no false charge guarantee, no overlapping purchase/restore operations and stale notice cleanup after verified entitlement. | Production state/operation tests and native loading/unavailable UI. |

An offline Privacy Policy screen is reachable from Settings. RecapNotifier's actor-isolation warning is fixed. Release documentation now distinguishes measured behavior from goals and keeps contacts/URLs unresolved. No signing team, account agreement, pricing account, deployment, upload or purchase was changed.

## Verification

- Final full suite: **423 test executions, zero failures**. Source: `/private/tmp/taplog-final-tests.log` and `/private/tmp/taplog-combined-derived/Logs/Test/Test-TapLog-2026.10.11_16-56-48-+0530.xcresult`. Window: 11 October 2026, 16:56:48–16:57:03 IST. Filter: entire TapLog scheme, no only-testing filter, parallel testing disabled, dedicated iOS 26.5 iPhone simulator. Join key: XCTest identity. Row count: 423 test executions, no production-data join.
- Exact test command: `xcodebuild test -project TapLog.xcodeproj -scheme TapLog -destination 'platform=iOS Simulator,id=310F05DC-8DC4-4B38-AFF4-D5970E5DF863' -parallel-testing-enabled NO -derivedDataPath /private/tmp/taplog-combined-derived CODE_SIGNING_ALLOWED=NO` in `/private/tmp/taplog-combined-check`.
- Final unsigned iPhone Release build passed. Source: `/private/tmp/taplog-final-release.log`. Same frozen source. This proves compilation, not distribution signing or upload acceptance. No production-source warnings in that Release log. Existing low-impact test-only warnings remain outside the changed scope.
- Regenerated task project equals the tested generated project. Final source hashes matched the verification copy. Packaged app, widget and share extension each include privacy manifests and aligned versions. No signed archive was created.
- Device Hub simulator UI: Settings privacy link opens readable offline policy; selecting USD with demo history shows the reinterpretation warning; dismissing it and relaunching retains INR; paywall transitions from Checking the App Store to price-unavailable text with Try again. No purchase or restore was triggered during this UI inspection.
- Original worker test copies were mutable during concurrent work and had intermediate failures/stalls. Persistence original task was cancelled after a stale test process. The UI review task timed out after writing its patch. These are not hidden as successful worker runs. The parent independently reviewed and verified their exact combined source afterward.

## Still pending

- Actual support email and hosted support/privacy HTTPS URLs, App Store Connect metadata completion.
- Paid-team signing/provisioning and registered App Group, signed archive validation/upload and TestFlight installation.
- Real App Store product configuration, account agreements/tax/banking, sandbox purchase/restore/refund/pending flows.
- Physical-device Siri, Action Button, Home/Lock Screen widget, Control Center, share-sheet, data protection and capture-timing tests.
- Old-store upgrade/fallback recovery, true cross-process concurrency, crash/low-disk behavior and deletion across retained fallback copies. Current guards and injected failures do not establish those hardware properties.
- Real Numbers/Excel export checks, minimum-supported-OS and small-screen accessibility QA, final listing screenshots and listing accuracy.

Parser limitations are deliberate and visible: some receipt-style text with quantities or repeated monetary values is declined for manual entry. Currency conversion/mixed-currency records were not added. Share suggestions remain pending until confirmed. Mixed spending/balance text is still heuristic, so this is not a claim of universal bank-message recognition.

No confirmed P0 was found within the reviewed scope. This is a bounded release review, not exhaustive security certification. The full remaining checklist is `docs/appstore-readiness-checklist.md`; the original before-fix findings remain in `docs/appstore-code-review.md`. Worker work orders/results are under `docs/work-orders/`.

Final verification logs and source hashes are retained in `docs/review-evidence/final-tests.log`, `final-release.log` and `final-source-manifest.json`. Temporary task-scoped Relay registration was removed after every worker became terminal. Existing Relay agents were preserved.
