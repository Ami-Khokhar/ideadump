# TapLog release-fix verification plan

Purpose: an ordered, concrete way to prove the P1/P2 fixes from
`docs/appstore-code-review.md` and to separate **code-fix evidence** from
**unverified signing / device / App Store Connect steps**. This plan does not claim
readiness. Every step ends with evidence written down: command, source log, time window
(IST), filter, row/test count and join key. Funnel stages must not increase.

Baseline for "fails without the fix": commit `54f7b31` (owner's snapshot) in a disposable
copy. Do not run baseline-reverting experiments in the shared worktree.

Status legend: **Code** = can be proven locally in the simulator; **Runtime** = needs a
real device or a second process; **External** = needs Apple account, signing, App Store
Connect or the owner.

## Phase 0 — Freeze and reproduce the baseline

1. Record `git rev-parse HEAD` and `git status --porcelain` for the fix worktree. Confirm
   no worker edits are uncommitted when the combined run starts.
2. Confirm the existing baseline suite: full `TapLogTests` scheme, 355 executions, zero
   failures, as recorded in `docs/appstore-code-review.md`. Re-run only if the toolchain
   changed.
3. Confirm the reproduction fixtures in `docs/review-evidence/ReleaseReviewReproductionTests.swift`
   still assert the defects. These prove the defect existed; they are not fixed-behavior
   regressions.
4. For each fix, copy the new regression test file plus the fixed source file into a
   disposable baseline copy, run only that test, and confirm it **fails** on `54f7b31`
   source. Record the failure message. Then run it on the fixed worktree and confirm it
   **passes**. A regression that passes on both is not evidence.

## Phase 1 — P1 code fixes (Code)

Run each regression with `-only-testing:TapLogTests/<ClassName>/<testMethod>` and the
command in Phase 3. Worker 1 owns the source and tests for R1, R2 and R3.

1. **R1 — rejected intent insert cannot persist.**
   - Fix: the intent save catch path unstages the inserted entry before throwing.
   - Regression: `ReleasePersistenceRegressionTests` (or `EntryPersistenceTests`) with an
     injectable save seam. Assert: a rejected save followed by a retry persists exactly
     one row (the retry); counters/usage do not move for the refused attempt.
   - Prove: run the same test against `54f7b31` source and confirm both rows persist (the
     failure the review reproduced).
2. **R2 — permanent wipe invalidates undo.**
   - Fix: `UndoStack.invalidateAll()` cancels the dismiss task and clears current action
     plus history; Settings calls it after a **successful** wipe, then
     `WidgetLogReceipt.clear()`.
   - Regression: `UndoStackTests` plus `ReleaseSettingsRegressionTests`. Assert: after a
     successful Delete All, a prior delete/edit/archive/log undo cannot reinsert a row.
     Assert: a **failed** wipe preserves the valid undo action.
   - Prove: the invalidation test fails on baseline `UndoStack` (no API) and the
     wipe-then-undo fixture restores a row, as in `ReleaseReviewReproductionTests`.
3. **R3 — widget refuses a private-fallback write.**
   - Fix: `QuickLogIntent` requires a usable shared store before writing; returns an intent
     error otherwise; widget shows an unavailable state instead of a misleading zero.
   - Regression: `StoreLocatorTests` / `ReleasePersistenceRegressionTests`. Assert: an
     unavailable App Group creates no private entry and no widget receipt, and does not
     increment counters.
   - Prove: on baseline source the same setup writes into the fallback store.

## Phase 2 — P2 code fixes (Code)

Worker 2 owns R4/R5 export/parser; worker 3 owns R5 warning and R7 paywall.

4. **R4 — full localized amount or honest rejection.**
   - Regression: `ShareParserTests` / `ReleaseInputRegressionTests`. Cases:
     `Paid €1.234,56 at Cafe` parses to 1234.56 or is rejected as ambiguous — never
     `1.23`; no partial numeric prefix is accepted; OTP-only text stays rejected; account
     / balance-before-debit text declines rather than guesses; the amount cap applies to
     the complete candidate; all shares remain pending.
   - Prove: baseline parser prints `1.23` for the European example.
5. **R5 — currency is explicit, not silently reinterpreted.**
   - Regression: `CSVExporterTests` and `ReleaseSettingsRegressionTests`. Assert: CSV
     includes the single current currency code while preserving existing row semantics
     (archived included, pending excluded); changing currency with stored entries or
     budgets requires confirmation and cancellation keeps the original code. No conversion
     is added.
   - Prove: baseline CSV has no currency column and the picker changes silently.
6. **R6 — category usage moves with the edit.**
   - Regression: `CaptureBookkeepingTests`. Assert: moving Chai → Food moves only
     category usage; undo reverses the move; delete/archive afterwards matches confirmed
     active rows; no new log day or totalLogs increment for an edit.
   - Prove: baseline leaves the old category's `logCount` elevated after the row is gone.
7. **R7 — paywall states are honest.**
   - Regression: `ProStoreTests` / `ReleaseSettingsRegressionTests`. Assert: loading,
     unavailable-with-retry, pending, unverified and cancellation states are distinct;
     unverified results grant no access; the generic error does not guarantee "you have
     not been charged"; restore-with-none explains no purchase found.
   - Prove: baseline leaves `product` nil with a disabled button and no explanation.

## Phase 3 — Combined code verification (Code)

Command (from the fix worktree; one simulator job at a time):

```sh
xcodebuild test -project TapLog.xcodeproj -scheme TapLog \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -parallel-testing-enabled NO \
  -derivedDataPath /private/tmp/taplog-worker-4-check/DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

- Record test execution count, failures and the time window. The count must be at least
  the 355 baseline executions plus every new regression. Zero failures required.
- Then a Release build for generic iOS with `CODE_SIGNING_ALLOWED=NO` and confirm the
  `RecapNotifier` actor-isolation warning is gone (worker 3). A no-sign build is
  compilation evidence only.
- Regenerate the project only inside a disposable copy with the installed XcodeGen and
  diff against the shared generated project. Never regenerate the shared source project.

## Phase 4 — Storage, cross-process, notification and large-data runtime checks (Runtime)

These are the "other risks" in the review. Source guards are not device evidence. Run on
a real device with a paid team when available; until then record them as **unverified**.

### Storage and store selection
8. **Fallback vs shared coherence.** Force an App Group failure and a shared-store open
   failure. Confirm: the app reports an unavailable/setup state rather than silently
   showing a different empty store; the original data is not deleted; recovery UI is
   visible. Check both the Application Support fallback and the group store after the
   failure clears.
9. **Split-store healing and wipe.** Seed an old fallback store, trigger healing, then
   Delete All. Confirm the deletion promise holds across the transition and that a normal
   next launch does not automatically re-copy an emptied group store. Corrupt or locked
   old history must not be presented as safe recovery.
10. **Wipe across stores.** Confirm Delete All removes active, archived and pending rows
    in the selected store, clears intended counters and notifications, and cannot be
    undone by a stale session action (ties to R2). Inspect both stores on an upgrading
    build.
11. **Upgrade fixtures.** Open real prior-schema stores (previous app versions), including
    a denied-storage and low-disk case. Confirm the row is durable or the failure is
    reported, never a silent success.
12. **Entry vs bookkeeping split.** Force a bookkeeping/defaults write to fail after the
    entry save. Confirm the product does not show derived counters that contradict
    entries, or document the exact divergence. Consider reconciling counters from entries.
    Verify `logsLogged` increments are safe under the retention file lock.

### Cross-process
13. **Widget/share write while the app is foreground.** Log from the widget and share
    sheet while the app is open; confirm the app observes the new row without a relaunch
    (SwiftData cross-process observation), and totals agree.
14. **Simultaneous saves.** Trigger app + widget saves at the same instant and confirm no
    lost row or duplicate counter. Confirm `UserDefaults` cache coherence for currency,
    today's total and the widget receipt.
15. **Locked device.** Invoke the widget/intent on a locked device. Confirm the save
    succeeds or reports unavailable; confirm Lock Screen totals match the privacy promise
    (no amounts on the Lock Screen).

### Notifications
16. **Permission timing.** Confirm the system prompt appears only after a recap is opened
    or a week is completed, never at launch, and never twice.
17. **Sunday delivery and tap route.** Confirm the weekly notification fires at the
    intended local time and a tap routes to the recap. Test cold launch: tap before
    `ContentView` subscribes, and confirm the route is not dropped (the review flags a
    possible race).
18. **Wipe clears the reminder.** After Delete All, confirm no misleading recap reminder
    remains scheduled.

### Large data and export
19. **Undo history growth.** Log for a long session and profile retained closures after
    toast expiry. Bound the history if memory grows.
20. **Large history.** Seed a realistic multi-year history and measure fetch/scroll cost,
    widget memory and extension time limits.
21. **CSV overlapping exports.** Start two exports that share at completion and confirm
    each attachment is the correct file (unique temp path fix). Open the CSV in Numbers
    and Excel: confirm currency is identifiable and formula-leading text with leading
    whitespace/control characters is neutralized in the real apps before claiming
    universal spreadsheet safety.
22. **Duplicate category keys.** Test migration and cross-process seeding for duplicate
    keys that could trap `Dictionary(uniqueKeysWithValues:)` in the widget.

## Phase 5 — Packaging and asset checks (Code)

23. **App icon.** Confirm `Sources/TapLog/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
    is 1024×1024, opaque, single-size universal (verified 11 October 2026 IST with
    `sips`). Re-check the signed archive's rendered icon.
24. **Privacy manifests.** Confirm `PrivacyInfo.xcprivacy` is embedded in the app and both
    extensions in the **archive**, and that required-reason declarations match the archive
    privacy report. The current manifests declare UserDefaults reasons `1C8F.1` and
    `CA92.1`. Do not assume one declaration covers every API.
25. **Info.plist and resources.** Confirm `ITSAppUsesNonExemptEncryption=false`, iOS 17
    minimum, iPhone-only, portrait, URL scheme `taplog`, and app/widget/share
    bundle/version/build alignment in the archive.
26. **Debug hooks.** Confirm no seed data, fake product or debug navigation ships in
    Release and that no local `.storekit` file is used in the uploaded build.
27. **Screenshots.** Confirm the three `appstore/screenshots/*.png` are 1320×2868, opaque,
    match current screens, and use no sample data that misrepresents functionality.
    Regenerate if the UI changed during the fixes.

## Phase 6 — External signing, device and Connect steps (External)

These cannot be proven from the repository. Mark them **unverified** until the owner
supplies access and evidence.

28. **Paid-team signing.** The paid team is already in `project.yml`; provision app +
    widget + share with the same registered App Group, create a signed archive and inspect
    entitlements. A no-sign build is not evidence.
29. **Archive validation/upload.** Validate in Organizer, upload, wait for processing,
    resolve warnings, preserve dSYMs with the release revision. Raise the build number for
    every upload.
30. **Real-device QA.** Run the full "Real-device functional QA" list in
    `docs/appstore-readiness-checklist.md`: fresh install, keypad, history, categories,
    Siri, Action Button (both workflows), widget, Lock Screen, Control Center, share
    sheet, deep links, budgets/recaps, currency, CSV, notifications. Record device, OS and
    build.
31. **Sandbox purchase.** Without the local `.storekit` file, exercise success, cancel,
    pending/Ask to Buy, delayed approval, interruption, unverified result, refund and
    network error; restore after reinstall and on a second device; signed-out flow.
    Confirm Pro survives cold launch/offline and never unlocks on an unverified result.
32. **App Store Connect records.** Confirm the app record, product ID
    `dev.amteshwar.taplog.pro.lifetime`, agreements, tax/banking, regional availability
    and privacy answers. A local StoreKit file proves none of these exist.
33. **Age-rating questionnaire.** Complete Apple's current questionnaire in App
    Information → Set Up Age Ratings. Since 31 January 2026 all apps use the updated
    system (4+, 9+, 13+, 16+, 18+, Unrated) and the updated questions. Do not assume 4+
    or pre-answer "None". Record the calculated rating and any override.
34. **First IAP submission.** Apple requires the first non-consumable to be submitted
    with a new app version. Add the IAP to the same draft submission as the app version.
35. **Reviewer package.** Provide exact steps for both paywall entry points, both Action
    Button workflows, restore and the extensions. No login is required.
36. **Public URLs and support contact.** The owner has not supplied the support email or
    the hosted support/privacy URLs. `appstore/support.html` and
    `appstore/privacy-policy.html` retain the `SUPPORT_EMAIL` placeholder with an
    `UNRESOLVED` comment, and `appstore/metadata.md` marks both URLs *Needed*. Do not
    invent a contact or host a page under a fabricated address. Verify
    HTTPS, mobile rendering, no login, a working contact route and policy accuracy once
    the owner supplies them.

## Phase 7 — Listing accuracy (Code + External)

37. Confirm the listing claims match the Release build: no unmeasured speed number, no
    absolute "100% offline" claim, StoreKit network communication described accurately,
    and backup inclusion described as configuration-dependent.
38. Confirm Free stays Free: unlimited logging, CSV export, three budget trees, weekly
    recap, lifetime Pro semantics (one non-consumable unlocks all trees and the monthly
    recap). Editing or deleting a budget must free a slot.
39. Review keywords against App Review Guideline 2.3.7 and remove inappropriate
    trademark terms.

## Evidence log template

For every completed step write:

```
Step:            <number and name>
Status:          Code / Runtime / External — pass, fail or unverified
Command/method:  <exact command or manual steps>
Source log:      <absolute path>
Time window:     <start–end IST>
Filter:          <test filter / device / storefront>
Result:          <counts, pass/fail>
Join key:        <XCTest identity / file path / no data join>
Notes:           <what was not verified>
```

## Stop rules

- Stop a dependent change and report if a fix conflicts with another worker's owned path,
  needs an unavailable external fact, introduces an unexplained destructive migration, or
  collides with an owner decision.
- Do not report completion from a plan or a source trace alone. Completion needs the
  command, the log and the count.
- Do not submit, purchase, upload, host, register or change accounts without explicit
  owner authorization.
