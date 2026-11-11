# TapLog code review before submission

Historical before-fix review. The named code findings were addressed afterward. See [current verified fixes and remaining limits](release-fix-results.md), local commit 92fcd99.

**Verdict: no confirmed P0 found in this review. Fix the P1 data-integrity paths and submission blockers before external beta or submission.** This is a bounded release review, not a claim that all defects or security vulnerabilities have been exhausted.

Reviewed 11 October 2026 IST. Source baseline: `6738695dfce94ac90d32ccd5f5617f1ba7af1b7d` plus existing uncommitted changes on `budget-trees-redesign`. Assumption: ship the current local-first iPhone product with lifetime Pro. App code was not changed. Reproduction tests ran in a disposable copy. Their evidence source is retained under docs/review-evidence and is not part of the app test target.

Priorities: P0 = demonstrated catastrophic/urgent failure needing immediate stop. P1 = data integrity or launch correctness that should block release. P2 = limited/conditional defect to fix or consciously accept. Submission requirements are separate from code severity. Lack of evidence is not a passing check.

## Findings

### R1 — P1: failed Siri/widget insert can be saved by the next operation

Locations: `Sources/TapLog/AppIntents/LogExpenseIntent.swift:61` and `Sources/TapLog/AppIntents/QuickLogIntent.swift:34`.

Both insert into the cached container's `mainContext`. Their catch blocks log and throw `saveFailed` but do not rollback or remove the inserted entry. The shared context retains that change. When storage becomes writable and a retry or another action saves, it can persist both the refused attempt and the new expense. The first attempt skips success bookkeeping, so totals and counters can also disagree.

Example: Siri reports that the Chai log failed. Retry succeeds. Both staged expenses can now be durable, even though only the retry received success bookkeeping.

Evidence: temporary XCTest used a real in-memory SwiftData context with autosave disabled, injected a save-refusal error at the same boundary, then performed a later save. A fresh context read both refused and retry rows. This reproduces the consequence of the missing rollback. It did **not** force a real low-disk save failure or invoke Siri end to end.

Smallest fix: undo the staged insert before throwing at both intent save sites, using an isolated context or the existing failure policy carefully. Do not accidentally rollback unrelated live edits. Regression: rejected save followed by retry persists only the retry, and failed attempts change no counters. Add an injectable save seam so the regression exercises the production catch path.

### R2 — P1: permanent wipe leaves undo actions able to restore records

Locations: `Sources/TapLog/Settings/SettingsView.swift:191`, `Sources/TapLog/Undo/UndoStack.swift:24`, `Sources/TapLog/List/EntryListView.swift:456`.

Delete All saves the removal and resets counters, but never invalidates the shared undo stack. The stack retains closures after the toast times out. History's undo-of-delete closure contains a snapshot and can insert it again. Settings even presents the same undo toast. A recent delete action followed quickly by Delete All can therefore leave a visible Undo that restores an expense after the permanent-deletion promise. Other retained closures can refer to now-deleted model objects.

Evidence: temporary XCTest exercised the actual `UndoStack` and `DeletedEntrySnapshot`, deleted all current entries using the same independent sequence as Settings, then executed retained undo. A fresh SwiftData context read the restored private note. This verifies the data-layer route. The rapid UI sequence has not been tapped on hardware.

Smallest fix: after successful permanent wipe, cancel the dismiss task and clear current action/history, and clear the widget receipt. Never clear undo state on a failed wipe. Regression: prior delete/edit/archive/log undo cannot act after a successful permanent wipe. Failed wipe preserves valid undo actions. Consider bounding ordinary session undo history separately.

### R3 — P1, conditional: widget quick-log can write into an invisible private store

Locations: `Sources/TapLog/AppIntents/QuickLogIntent.swift:29`, `Sources/TapLog/Shared/StoreLocator.swift:131`, `Sources/TapLog/Shared/StoreLocator.swift:449`.

StoreLocator deliberately allows Application Support fallback. In the widget process this is the widget's own container, which the app cannot read. The share extension explicitly refuses writes unless `isUsingSharedStore` is true. QuickLogIntent lacks that gate, so a disconnected/failed App Group route can report success and write an expense outside the app's store. The widget also shows tappable default amounts when the store cannot be read.

Evidence: source trace, not a reproduced physical widget invocation. Condition: missing/inaccessible App Group or failed shared-store opening while private fallback opens. Correct paid signing reduces the normal path's likelihood but does not enforce the save invariant. Current personal-team configuration makes the fallback path particularly relevant to development builds.

Smallest fix: require a usable shared store before a widget write and return a useful intent error otherwise. Render an unavailable/setup state instead of a misleading zero-success state. Regression: unavailable App Group creates no private entry/receipt and does not increment counters. Device QA: verify a successful widget expense is visible in the app after force-quit/relaunch.

### R4 — P2: shared European amounts are truncated before validation

Location: `Sources/TapLog/Shared/ShareParser.swift:39`.

The regex accepts a dot followed by at most two digits and does not require an end-of-number boundary. `Paid €1.234,56 at Cafe` captures `€1.23`, so Money.parse never sees the full number. It returns 1.23 rather than the intended 1234.56. Other numeric prefixes and account/balance text also need conservative tests.

Evidence: standalone Swift fixture ran the exact current Money/ShareParser source with a dummy StoreLocator constant. It printed `Parsed: 1.23`. No production data or service was used. Shared entries remain pending until confirmation, which limits impact and keeps this below P1.

Smallest fix: tokenize the full numeric candidate, then apply consistent grouping/decimal rules or decline ambiguous text. Do not accept a prefix of a larger number. Regress localized formats, excessive precision, account numbers before amounts, balance-before-debit messages and OTP text. Never count a guess without confirmation.

### R5 — P2: currency change relabels history and exports omit currency

Locations: `Sources/TapLog/Models/Entry.swift:25`, `Sources/TapLog/Shared/Money.swift:58`, `Sources/TapLog/Settings/SettingsView.swift:29`, `Sources/TapLog/Export/CSVExporter.swift:39`.

Entry stores amount without denomination. All historical amounts and budget targets use the current global currency. Changing INR to USD displays the same nominal amount in USD without conversion or warning. CSV contains a bare Amount column and no currency, despite Settings saying currency is used in exports.

Evidence: temporary simulator XCTest created an amount, switched global currency, confirmed display changed while amount did not, and checked CSV included neither currency code. This is a single-currency product-policy ambiguity, not proof that exchange-rate conversion was promised.

Smallest launch fix: explicitly explain that changing the single app currency reinterprets existing history without conversion, require confirmation when records exist, and put the current currency code in exports. If the intended product supports mixed-currency records, per-entry currency and migration need a separate design. Do not silently add conversion logic to this release.

### R6 — P2: editing category leaves usage counters attached to the old category

Locations: `Sources/TapLog/Capture/CaptureForm.swift:182`, `Sources/TapLog/Shared/CaptureBookkeeping.swift:27` and `:65`.

For an existing confirmed entry, CaptureForm changes `entry.category` but moves no category logCount. Later delete/archive/undo decrements the new category's counter. The old counter remains elevated after the row is gone, affecting category ranking and suggestions. Actual spending totals use entries and are not inflated by this counter.

Evidence: dedicated-simulator XCTest exercised actual CaptureBookkeeping around the same edit sequence. After editing and deleting the sole entry, the original category still had usage while no entry remained. This verifies the data-layer sequence, not UI taps.

Smallest fix: move only category-usage counts on a successful category edit and reverse that move on undo. Do not count a second log day or increment totalLogs for an edit. Regression: move Chai to Food, undo edit, archive/delete, and verify usage matches confirmed active rows.

### R7 — P2: unavailable product lookup produces an unexplained disabled paywall

Locations: `Sources/TapLog/Pro/ProStore.swift:69`, `Sources/TapLog/Pro/PaywallView.swift:247`.

Product lookup failure and an empty result both leave product nil without a failure message or loading state. The paywall displays a dash for price and disables purchase. The unreachable-store message in purchase() cannot normally be reached because the UI disables that button when product is nil. Pending and unverified purchase outcomes also provide no explicit feedback. The generic thrown-error message claims the user has not been charged without reconciling eventual transaction state.

Evidence: source trace. No live App Store product lookup was inspected.

Smallest fix: distinguish loading, unavailable and pending states, offer retry for unavailable lookup, and show safe transaction-verification feedback without unlocking unverified results. Use wording that does not make an unsupported charge guarantee. Test actual sandbox outages, cancellation, pending approvals and delayed transactions.

## Separate submission blockers

- Settings has no accessible privacy-policy link. Apple guideline 5.1.1 requires it. Both support/privacy HTML files still contain `SUPPORT_EMAIL`. Metadata has unresolved public URLs.
- project.yml selects the personal signing team. Paid-team app/extension provisioning and signed archive validation remain necessary. Paid membership status was not read.
- App Store Connect app/IAP records, agreements, tax/banking, privacy answers, current rating questionnaire, regional availability and reviewer package are unverified.
- Existing listing directions are stale in places: Action Button setup differs between README and review notes, age-rating guidance assumes old 4+ answers, and marketing claims need a final behavior check.
- Real-device and TestFlight release QA remain missing evidence. Follow every unchecked gate in the checklist.

## Other risks needing validation, not confirmed critical findings

- StoreLocator tries another location after any shared-store open error. Corrupt/locked old history can therefore lead to a different empty store being shown. Original data is not deleted by that path. Verify recovery UI, shared-vs-fallback coherence and upgrades with actual old-store fixtures. Do not describe this as demonstrated permanent data loss.
- Split-store healing copies records into an empty group store and preserves the fallback. Wipe currently operates on the selected store only. Verify the product's deletion promise across fallback transitions. Normal subsequent launch should not automatically re-copy an emptied group store because its history marker remains. Do not claim normal wipe resurrection through this marker path.
- Entry save and bookkeeping save/defaults writes are separate. A later bookkeeping failure can leave a durable row without matching usage/retention state. Verify failure semantics and consider reconciling derived counters from entries. `logsLogged` increments are outside the retention file lock.
- Real cross-process SwiftData observation, locked-device data protection, simultaneous saves, crash-interrupted healing and UserDefaults cache coherence were not reproduced.
- Undo history grows and retains closures after toast expiry. No memory exhaustion was measured. Bound history if long-session profiling shows a problem.
- CSV neutralizes formula characters only at the first character. Test leading tabs/newlines/control characters in actual supported spreadsheet apps before claiming universal formula safety. No formula execution exploit was reproduced.
- CSV exports reuse the same temporary filename. Test overlapping exports/share completion before claiming a race. No incorrect attachment was reproduced.
- Duplicate category keys can trap `Dictionary(uniqueKeysWithValues:)` in the widget. Current creation uses unique slugs, so a real duplicate-producing route has not been established. Test migration/cross-process seeding before elevating it.
- RecapNotifier's actor-isolation warning is a future Swift 6 compile failure, not a current Release build failure. Correct the immutable identifier's isolation in a separate small change.
- Cold notification taps may arrive before ContentView subscribes to the notification. Verify the real cold-launch route rather than assuming NotificationCenter posts are durable.

## Coverage and verification

Source review traced launch/onboarding, SwiftData models and store selection/healing, capture/edit/history/undo/deletion, category/budget save paths, retention/notifications, recap filtering/math, Pro product verification/restore/gates, deep links, share parser/extension, widget quick log/timeline and CSV export. Theme/tree drawing was scanned for availability, motion and query coupling, not exhaustively reviewed as artwork. No formal security-audit workflow or independent external reviewer was run. No previous structured audit ledger was available in this review.

**Existing baseline tests:** `xcodebuild test -project TapLog.xcodeproj -scheme TapLog -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /private/tmp/taplog-readiness-build CODE_SIGNING_ALLOWED=NO`. Source `/private/tmp/taplog-readiness-test.log`. Window 11 October 2026, approximately 11:45:11–11:45:43 IST. Filter: full TapLogTests scheme, no only-testing filter. Result: 355 test executions, zero failures. Join key: test identity within xcresult; no data join. This is test-run count, not production rows.

**First focused reproduction run:** only `TapLogTests/ReleaseReviewReproductionTests` in `/private/tmp/taplog-review-source`, same simulator/toolchain. Source `/private/tmp/taplog-review-reproductions.log`. Window approximately 11:53:22–11:53:46 IST. Result: three test executions passed, covering R1 consequence, R2 data-layer route and R5. Join key: XCTest identity; no production data join. Passing these assertions means the existing defects were reproduced, not that fixed-behavior regressions passed.

**Release:** unsigned generic-iPhone Release build succeeded. Source `/private/tmp/taplog-release-check.log`. Built products `/private/tmp/taplog-release-check/Build/Products/Release-iphoneos/TapLog.app`. App and extension plist/manifests were inspected. Archive signing, Organizer validation/upload, real hardware and live StoreKit were not verified.

**Project synchronization:** disposable copy with original source/tests regenerated via installed XcodeGen 2.46.0. Diff against current-worktree project.pbxproj was empty. The test-reproduction copy adds its own test source and intentionally has a different generated project. CI reproducibility against its intended generator version is still unverified.

**Assets:** `sips` inspected source app icon and listing PNGs on 11 October 2026 IST. Icon is 1024×1024 with no alpha. Each listed screenshot is 1320×2868 with no alpha. Filter: AppIcon.png and appstore/screenshots/*.png. Row count: one icon and three screenshot files. Join key: file path, no data join. Visual currency/layout/listing accuracy still needs final captures.

**Simulator limitation:** expanded run on the original simulator was rejected by SpringBoard as Busy/preflight failure and exited 65. This was a test-host launch failure, not a failing app assertion. A dedicated review simulator was created for retry. Dedicated-simulator retry passed. Source `/private/tmp/taplog-review-reproductions-isolated.log`. Window approximately 11:56:40–11:57:07 IST. Filter: ReleaseReviewReproductionTests only, parallel testing disabled. Result: five test executions, zero failures. Join key: XCTest identity, no production-data join. Fixture counts: R1 has refused + retry entries, R2 restores one wiped snapshot, R4 uses one dummy text, R5 uses one entry, and R6 edits/deletes one entry across two categories. These tests assert the defects, not fixed behavior. Temporary evidence source is retained under `docs/review-evidence/ReleaseReviewReproductionTests.swift`.

**Agent Relay:** no connected Relay MCP tool appeared and plugin-directory search found no matching integration. The local repository exists at `/Users/amteshwar/Documents/Coding projects/a2a-relay`. A read-only GET to its documented localhost agent registry worked outside the sandbox. The initial sandbox-only request could not connect. Availability is verified at HTTP registry level only. No delegate request or worker was started and no model/provider suitability was assumed.

## Order of work

Fix R1/R2/R3 and prove their regressions. Add the in-app privacy link and finalize support/privacy text. Decide/fix the limited R4–R7 issues, particularly amount parsing and store-unavailable messaging. Establish the paid signed build and real sandbox purchase. Complete device/TestFlight QA from the checklist. Submit the exact verified build only after the owner authorizes submission.

Primary sources: [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [current tooling/ratings requirements](https://developer.apple.com/news/upcoming-requirements/), [first IAP submission](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/). These support submission requirements, not repository defect claims. Source findings are supported by the local files and fixtures above.

Report verification: the self-contained HTML report rendered in Safari through a temporary localhost preview. Navigation, checkbox toggling, reset and hide-completed filtering were exercised. Desktop layout was visually inspected. Mobile report layout was not runtime-tested. Source inspection and tests do not complete the real-device/Connect checklist.
