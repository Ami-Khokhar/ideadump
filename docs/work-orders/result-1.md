# Worker 1 result — R1/R3/R6 + undo invalidation, correction round 1

Status: DONE for the owned scope (corrections + regressions authored). No commits,
no pushes, no nested agents. The combined runtime gate is owned by the parent and
was intentionally not started here.

Worked 11 October 2026 IST in `/private/tmp/taplog-release-fixes`. Isolated
verification copies may be created only under
`/private/tmp/taplog-worker-1-check`; none were needed for this round.

## Owned paths touched

App:
- `Sources/TapLog/Shared/CaptureBookkeeping.swift`
- `Sources/TapLog/Capture/CaptureForm.swift`
- `Sources/TapLog/Shared/IntentSupport.swift`
- `Sources/TapLog/AppIntents/QuickLogIntent.swift`

Tests:
- `Tests/TapLogTests/CaptureBookkeepingTests.swift`
- `Tests/TapLogTests/ReleasePersistenceRegressionTests.swift`

Result:
- `docs/work-orders/result-1.md`

Original worker-1 patch already in the worktree and retained unchanged in intent:
the R1 `IntentEntryWriter` helper + `LogExpenseIntent`/`QuickLogIntent` use,
the R2 `UndoStack.invalidateAll()` API (worker 3 calls it in Settings), the R3
extension-process-aware widget gate, the R6 category-usage move, and the original
`ReleasePersistenceRegressionTests`. Not touched: `OnboardingFlowTests.swift`
(not needed), `SettingsView`/HistoryWipe (worker 3), CSV/parser (worker 2),
`project.yml`, the generated project, `.git`.

## Behavior changed in this correction round

### 1. Exact category-usage rollback (R6 follow-up)

`CaptureBookkeeping.stageCategoryUsageMove` now returns a
`CaptureBookkeeping.CategoryUsageSnapshot` (pre-move `from`/`to` counts) instead
of `Void`. A refused save restores that snapshot with
`CategoryUsageSnapshot.restore(in:)` rather than running a reverse move.

- Failed forward edit: `CaptureForm.save()` snapshots before the move and its
  `EntryPersistence.commit` rollback restores the exact pre-operation counts.
  A stale `chai.logCount == 0` therefore comes back as 0, not 1.
- Undo of an edit: the undo closure stages a move **relative to the current
  counts** (`categoryKey -> previous.category`) and snapshots those pre-undo
  counts. A log added after the edit keeps its own usage. Only if the undo save
  is refused is that pre-undo snapshot restored.
- Entry field changes and the usage move are still staged before the single
  `modelContext.save()`, so they commit in one transaction.
- The forward-edit snapshot is never reused for undo, so later legitimate logs
  are not overwritten.

### 2. Pending confirmation uses the row's own date

`CaptureForm.save()` now calls `CaptureBookkeeping.apply(... entryDate: entry.date)`
when confirming a pending share-sheet entry. A prior-week/day pending row lights
its own day (or no day of the current week) instead of today. The inverse
undo path already passed `entry.date` and is unchanged.

### 3. Widget gate retained; refusal path now testable

`IntentSupport.swift` gains `WidgetQuickLogWriter.log(...)`, the production
quick-log write path. `QuickLogIntent.perform()` still validates the amount first,
opens the process container, fetches categories, then calls the writer with
`StoreLocator.widgetWriteDecision(isUsingSharedStore:isExtensionProcess:)`.

- The gate runs before any insert/save/bookkeeping/receipt. A refused write throws
  `TapLogIntentError.storeUnavailable` and writes nothing.
- The app process (`isExtensionProcess == false`) still saves its own fallback
  store; only an extension process with an unshared store is refused.
- `IntentEntryWriter.insert` still unstages a refused insert, and the receipt is
  written only after a durable save.
- The app-host `OnboardingFlowTests` quick-log tests keep running the real
  `QuickLogIntent.perform()` and remain meaningful successes. That file was not
  edited.

### 4. R1 helper and invalidateAll inspection

- `IntentEntryWriter.insert`: inserts, saves through the injectable seam, and on
  refusal deletes the staged row before throwing `saveFailed`. This matches the
  R1 finding; no functional defect found. It deliberately does not
  `context.rollback()`, so unrelated in-flight edits stay staged.
- `UndoStack.invalidateAll()`: cancels the dismiss task, nils it, clears
  `current`, and removes all history; `record`/`report`/`undo` remain correct
  after invalidation (verified by existing `UndoStackTests`). No functional
  defect found. No destructive migration or corruption-recovery claim added.

## Regressions added (this round)

`Tests/TapLogTests/CaptureBookkeepingTests.swift`:
- `testRefusedCategoryEditRestoresStaleZeroCountsExactly` — zero/stale counts +
  injected save failure through `EntryPersistence.commit`.
- `testRefusedCategoryEditRestoresNormalUsageCounts` — ordinary pre-move counts.
- `testUndoingAnEditKeepsALaterLogsUsageAndRestoresBeforeRefusedUndoSave` — later
  independent log + refused undo restores the pre-undo snapshot.
- `testUndoingAnEditKeepsALaterLogsUsage` — successful undo keeps the later log.
- `testConfirmingAnOldPendingEntryLightsItsOwnDayNotToday` — 21-day-old pending
  row does not light this week.
- `testUndoingAnOldPendingConfirmationClearsItsOwnDay` — inverse bookkeeping.

`Tests/TapLogTests/ReleasePersistenceRegressionTests.swift`:
- `testRefusedWidgetWriteMutatesNothing` — simulated extension gate; no row, no
  `logCount`, no `logsLogged`, no receipt; throws `storeUnavailable`.
- `testSuccessfulWidgetWritePersistsRowCounterAndReceipt` — success through the
  production `WidgetQuickLogWriter`.

Pre-existing regressions retained: `testRejectedIntentInsertCannotPersistOnALaterSave`,
`testSuccessfulIntentInsertPersistsExactlyOnce`,
`testInvalidatedUndoCannotRestoreAPermanentlyWipedEntry`,
`testUndoRemainsUsableWhenTheWipeNeverInvalidatedIt`,
`testWidgetRefusesPrivateFallbackWrites`, and the R6 tests in
`CaptureBookkeepingTests`. `StoreLocatorTests` still pins both widget-gate
branches and the app-process exemption.

## Real checks run

- Static parse check only:
  `xcrun swiftc -parse` on the four changed app files and the two changed test
  files. Result: exit 0, no diagnostics, 11 October 2026 IST.
- No `xcodebuild` and no simulator job was started, per the correction
  instruction. Therefore no runtime test result is claimed here.

## Truthful test limitation

The original worker's full-suite run stalled after a mixed in-progress CSV test
crash and was cancelled. The new and existing regressions above have been authored
but not executed in this round. They must be treated as unverified until the
parent runs the combined suite on the merged worktree. Expected verification
command (parent-owned):
`xcodebuild test -project TapLog.xcodeproj -scheme TapLog -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -parallel-testing-enabled NO -derivedDataPath /private/tmp/taplog-worker-1-check/DerivedData CODE_SIGNING_ALLOWED=NO`.

## Remaining limitations

- No real widget/App Group, Siri, or device run; the gate regressions are
  pure/in-memory, not hardware proof.
- The pending-confirmation date fix is covered at the bookkeeping level, not by a
  UI tap through `CaptureForm`.
- `WidgetQuickLogWriter` still opens the process container before the gate check
  because `StoreLocator.isUsingSharedStore` is derived from the opened store; the
  gate still precedes every write, row, counter, and receipt.
- The existing review caveats about separate entry/bookkeeping transactions and
  store corruption/recovery remain open and were not changed.
