# Worker 3 result

Status: DONE with one cross-worker test collision reported below.

Scope: R7 purchase feedback, R2 wipe integration, R5 currency warning, offline
in-app privacy policy, RecapNotifier actor-isolation warning. No other worker's
paths edited. All fixes verified in a disposable copy at
`/private/tmp/taplog-worker-3-check/source` (shared `TapLog.xcodeproj` untouched);
the copy's project was regenerated with the installed XcodeGen 2.46.0 so the new
files are compiled.

## Changed paths

- `Sources/TapLog/Pro/ProStore.swift`
- `Sources/TapLog/Pro/PaywallView.swift`
- `Sources/TapLog/Settings/SettingsView.swift`
- `Sources/TapLog/Settings/PrivacyPolicyView.swift` (new)
- `Sources/TapLog/Retention/RecapNotifier.swift`
- `Tests/TapLogTests/ProStoreTests.swift` (new)
- `Tests/TapLogTests/ReleaseSettingsRegressionTests.swift` (new)
- `docs/work-orders/result-3.md` (this file)

## Concrete behavior changes

### R7 — honest paywall states
- `ProStore` now has `ProductLoadState` (`idle`/`loading`/`loaded`/`unavailable`)
  and `ProNotice` (`none`/`pending`/`unverified`/`failure`). `loadProduct(force:)`
  moves through the states, and an empty answer is `unavailable`, not forever
  "loading".
- The paywall shows "Checking the App Store…" while loading, a real purchase
  button only when the price loaded, and "The App Store price isn't available
  right now." plus a **Try again** button on `unavailable`. The dead dash and
  disabled button are gone.
- `pending` shows "Waiting for approval. Pro unlocks automatically once it's
  approved." and never unlocks. An `unverified` result shows "This purchase
  couldn't be verified, so Pro wasn't unlocked. Try Restore purchase." and is not
  finished or trusted. Cancellation stays silent.
- A thrown purchase error no longer claims the user was not charged. It says the
  charge, if any, will appear in purchase history.
- `isPro` is still only derived from `Transaction.currentEntitlements`; the new
  seam injects the product lookup only, never the entitlement flag.

### R2 — wipe integration
- New `HistoryWipe.commit(save:rollback:report:undoStack:defaults:)` runs the
  existing `EntryPersistence.commit` and, **only on a successful save**, calls
  `undoStack.invalidateAll()` (worker 1's API) and `WidgetLogReceipt.clear()`.
- `SettingsView.clearAllEntries()` now goes through that function before the
  counter/streak/notification reset. A refused wipe returns false and leaves the
  undo stack and widget receipt untouched.

### R5 — currency change warning
- `CurrencyChange.decide(current:requested:hasStoredRecords:)` returns `.none`,
  `.apply`, or `.confirm`. The currency picker uses a binding that only writes
  `currencyCode` immediately when nothing is stored. With any stored entry or
  budget target it shows a confirmation dialog explaining that TapLog does not
  convert money. Cancel never writes, so the original denomination is retained.
- `hasStoredRecords` counts any entry (pending/archived included) or any category
  with a budget target.

### Privacy policy
- New `PrivacyPolicyView` is a local, offline page reached from a Settings
  `NavigationLink`. It covers local storage, the App Group, StoreKit/Apple
  payments, Siri speech processing by Apple, user-initiated CSV exports, local
  notifications, device backups as configuration-dependent and unverifiable by
  TapLog, and Delete All / uninstall deletion. It invents no URL, contact or
  backup guarantee. Headings carry the VoiceOver header trait.

### RecapNotifier
- `requestIdentifier` and `openRecapNotification` are now `nonisolated static let`,
  which removes the Swift 6 actor-isolation warning on the `nonisolated` delegate
  callback without changing the identifier value.

## Regressions added

`ProStoreTests`:
- `testRefusedLookupLeavesThePriceUnavailable`
- `testEmptyLookupLeavesThePriceUnavailable`
- `testRetryAfterUnavailableLooksUpAgain`
- `testVerifiedPurchaseShowsNoMessage`
- `testCancellationStaysQuiet`
- `testPendingIsExplicitAndDoesNotUnlock`
- `testUnverifiedIsExplicitAndDoesNotUnlock`
- `testFailedPurchaseDoesNotPromiseNoCharge`

`ReleaseSettingsRegressionTests`:
- `testSuccessfulWipeInvalidatesUndoAndWidgetReceipt`
- `testFailedWipePreservesUndoActionsAndReceipt`
- `testCurrencyChangeWithNoRecordsAppliesImmediately`
- `testCurrencyChangeWithRecordsNeedsConfirmation`
- `testSelectingTheSameCurrencyIsANoOp`
- `testConfirmationDoesNotApplyOnItsOwn`

## Exact checks and results

All in `/private/tmp/taplog-worker-3-check/source`, iPhone 17 Pro simulator,
OS 26.5, `-parallel-testing-enabled NO`, `CODE_SIGNING_ALLOWED=NO`.

1. Focused tests:
   `xcodebuild test ... -only-testing:TapLogTests/ProStoreTests
   -only-testing:TapLogTests/ReleaseSettingsRegressionTests
   -only-testing:TapLogTests/RecapNotifierTests`
   Window 2026-10-11 12:16–12:17 IST (re-run after the final `refresh()` notice
   tweak). Result: 23 test executions, 0 failures, **TEST SUCCEEDED**. Join key:
   XCTest identity; no data join.
2. Full suite before the accessibility-only privacy tweak:
   same command without `-only-testing`. Window 2026-10-11 12:12:47–12:13:14 IST.
   Result: 375 executions, 2 failures. Both failures are in `OnboardingFlowTests`
   (`testWidgetQuickLogSavesEntry`,
   `testWidgetQuickLogFallsBackToOtherForDeletedCategory`) and fail with
   `storeUnavailable` from worker 1's QuickLogIntent/StoreLocator change, not from
   this worker's paths. The success-path undo-stack note the review warned about
   is covered by `UndoStackTests.testInvalidateAllForgetsVisibleActionAndHistory`.
3. Release build: `xcodebuild clean build ... -configuration Release
   -destination 'generic/platform=iOS'` with `CODE_SIGNING_ALLOWED=NO`.
   Window 2026-10-11 12:14–12:16 IST. Result: **BUILD SUCCEEDED**, zero
   `warning:` lines, so the RecapNotifier concurrency warning is gone.
4. iOS 17 compatibility: deployment target is iOS 17.0 in `project.yml`; the
   Release device build above compiled against the iPhoneOS SDK with that target.
   No API newer than iOS 17 is used (`@Observable`, `NavigationLink`, iOS 16
   `scrollBounceBehavior`).

## Remaining limitations / handoff

- The shared, checked-in `TapLog.xcodeproj` does **not** contain the new files
  (`PrivacyPolicyView.swift`, `ProStoreTests.swift`,
  `ReleaseSettingsRegressionTests.swift`). Workers may not edit it. Whoever runs
  the combined suite must regenerate the project from `project.yml` in a
  disposable copy, as done here, or those three files are silently skipped.
- R2 depends on worker 1's `UndoStack.invalidateAll()`; it exists in the shared
  tree as of this writing and the integration passed.
- The two `OnboardingFlowTests` failures are a live cross-worker collision. They
  assert the old private-fallback save behavior that worker 1 intentionally
  removed. They sit outside this worker's allowed test paths, so they were not
  edited. They need either a shared-store setup in the test or an update by the
  owner of the AppIntent/StoreLocator change.
- Purchase state and message logic are unit-tested; real sandbox pending,
  unverified and outage flows remain unverified on device (no live StoreKit).
- The privacy policy text is reachable offline and accurate for the current
  local-first build. The public HTTPS policy URL and support contact are still
  pending from the owner and are deliberately absent rather than invented.
