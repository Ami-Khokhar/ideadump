# Worker 2 result — R4 share amount parsing + R5 export currency + CSV hardening

Status: DONE for the owned scope. Combined-tree suite not run (see Blocker).
Worked 11 October 2026 IST in /private/tmp/taplog-release-fixes. No commits, no
pushes. Isolated verification copies live only under
/private/tmp/taplog-worker-2-check.

## Changed paths

- `Sources/TapLog/Shared/ShareParser.swift`
- `Sources/TapLog/Export/CSVExporter.swift`
- `Tests/TapLogTests/ShareParserTests.swift`
- `Tests/TapLogTests/MoneyTests.swift`
- `Tests/TapLogTests/CSVExporterTests.swift`
- `docs/work-orders/result-2.md`

`Money.swift` was inspected but not changed. All existing `Money` APIs
(`parse`, `format`, `plainString`, `currencyCode`, …) are unchanged, and the only
`makeCSV` caller (`WeeklyRecapView`) still compiles because the new parameter has
a default. No `Entry` schema field changed. Share entries still stay pending.

## What changed (behavior)

### R4 — complete localized amounts, never a numeric prefix

`ShareParser.extractAmount` replaced the per-pattern "first fragment" match with
one scan for a **complete** numeric candidate (greedy across `.` and `,`) plus an
optional currency prefix:

- `Paid €1.234,56 at Cafe` now parses `1234.56` (was `1.23`) and the note keeps
  `Cafe`.
- The `Money.parse` amount cap is applied to the whole candidate, so
  `Paid €1.234.567.890,00 at Cafe` is `nil` (was `1.23`), not a fragment.
- A decisive currency amount that fails validation makes the text decline; the
  loose scan can no longer degrade to a fragment of it.
- New strict rule for untrusted text: a fractional part longer than two digits is
  declined, e.g. `spent $1,234.567 at Amazon` → `nil` (was `1234.56`).
- Conservative fallback when no currency amount exists: unseparated digit runs of
  seven or more digits (account/reference numbers) and candidates next to
  OTP / verification-code markers are dropped. `A/c 12345678 debited` → `nil`
  (was `12345678`). `Your payment OTP is 482910` → `nil` (was `482910`).
- Balance handling: among candidates the one next to a spending verb wins, so
  `Bal Rs 12,345.67 Rs 500 debited` → `500` (was `12345.67`). A balance-only
  message (`Your available balance is Rs 12,345.67`) now declines.
- Existing behavior preserved: OTP-only text, `Rs 500 paid to Uber`, `450 debited
  from your account`, `₹99 only for snacks`, large-junk input, etc.

### R5 — currency in export, unique export file, hardened escaping

- CSV header is now `Date,Amount,Currency,Category,Note,Archived,Intent`. The
  `Currency` cell is the app's single current `Money.currencyCode` on every row
  (defaulted, injectable for tests). Archived rows still included, pending rows
  still excluded. No conversion and no mixed currencies.
- `CSVFile.writeTemporaryExport(text:)` writes `taplog-export-<UUID>.csv`; the
  `Transferable` representation uses it. The constant `taplog-export.csv` name
  that let overlapping exports overwrite each other is gone.
- `quote(_:)` now looks at the first *visible* character, skipping leading
  whitespace and control/format characters, so `" =1+1"`, `"\t=1+1"`,
  `"\u{FEFF}-2"` get the apostrophe prefix just like `"=1+1"`. RFC 4180 quoting
  is unchanged. This is best-effort: no spreadsheet app was opened.

## Regressions added

ShareParserTests: `testLocalizedEuropeanAmountIsParsedWhole`,
`testLocalizedAmountsUseTheCompleteCandidate`,
`testAmountCapAppliesToTheCompleteLocalizedCandidate`,
`testExcessPrecisionIsDeclinedNotTruncated`, `testBareAccountNumberIsNotAnExpense`,
`testBalanceFigureDoesNotBeatTheDebitThatFollows`,
`testDebitBeforeBalanceUsesTheDebit`, `testBalanceOnlyMessageYieldsNoAmount`,
`testOTPWithPaymentWordStillProducesNoAmount`.

MoneyTests: `testParsesCurrencySymbolWithEuropeanGrouping`.

CSVExporterTests: `testPlainRowHasSevenColumns` (updated),
`testDefaultExportUsesTheAppsCurrentCurrencyCode`,
`testCurrencyCodeIsWrittenOnEveryRow`,
`testArchivedRowsKeepCurrencyAndPendingRowsStayExcluded`,
`testFormulaPrefixesAreNeutralized` (updated),
`testFormulaPrefixAfterLeadingWhitespaceOrControlIsNeutralized`,
`testFormulaPrefixAfterLeadingNewlineIsNeutralized`,
`testOverlappingExportsWriteToDistinctFiles`.

`testOverlappingExportsWriteToDistinctFiles` is new-API coverage: with the old
constant name the two URLs would be equal and the second write would clobber the
first, so the `NotEqual` and content assertions would fail. It cannot be compiled
against pre-fix source because `writeTemporaryExport` did not exist.

## Real checks and results

1. **Pre-fix failure proof (standalone, exact source).** Compiled
   `ShareParser.swift` + `Money.swift` from the working tree and from
   `git show HEAD:` with the same harness and `swiftc -O` in
   `/private/tmp/taplog-worker-2-check/harness` and `…/harness-old`.
   Window 11 Oct 2026 ~12:14 IST. Filter: 34 parser assertions. Fixed source:
   34/34 pass. Baseline `HEAD` source: 12 fail (`€1.234,56`→1.23,
   localized cap→1.23, excess precision truncation, account number→12345678,
   balance→12345.67, `Your payment OTP is 482910`→482910).
2. **Full unit suite on the owner baseline + my files.**
   Copy `git archive HEAD` overlaid with only my five files, under
   `/private/tmp/taplog-worker-2-check/src-base`.
   `xcodebuild test -project TapLog.xcodeproj -scheme TapLog -destination
   'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -parallel-testing-enabled
   NO -derivedDataPath /private/tmp/taplog-worker-2-check/DerivedDataTest
   CODE_SIGNING_ALLOWED=NO`.
   Log `/private/tmp/taplog-worker-2-check/tests-base2.log`, finished
   12:20:08 IST. Result: **371 tests executed, 0 failures, exit 0**, including
   every regression above. Join key: XCTest identity; no production data. This is
   test-run count, not rows.
3. **Compile check.** `build-for-testing` for `generic/platform=iOS Simulator`
   on the same baseline+my-files copy: `** TEST BUILD SUCCEEDED **`.

## Blocker / not verified

- **Combined working-tree suite not run.** The shared generated
  `TapLog.xcodeproj` does not reference several new untracked files
  (`Sources/TapLog/Settings/PrivacyPolicyView.swift`, `ProStoreTests.swift`,
  `ReleasePersistenceRegressionTests.swift`,
  `ReleaseSettingsRegressionTests.swift`), so a combined `build-for-testing`
  fails with `cannot find 'PrivacyPolicyView' in scope`. Those files are other
  workers' paths and the generated project/project.yml are forbidden to me.
  The orchestrator must regenerate the project before running the combined suite.
- Simulator was shared with worker 1's job finishing around the same time; my run
  returned exit 0 with all 371 tests reported. No `Transferable` share UI was
  invoked, only `writeTemporaryExport`.
- Formula neutralization was reasoned from source, not tested in Numbers/Excel/
  Sheets. It is a best-effort mitigation, not a universal spreadsheet-safety claim.
- Single-currency only. Settings confirmation for currency reinterpretation is
  worker 3's scope. Zero-decimal currencies were not specially handled; the
  export carries only the ISO code.

## Round 1 correction (review) — DONE

Worked 11 October 2026 IST. Same owned paths only: `ShareParser.swift` and
`ShareParserTests.swift`. No nested agents. CSV/export work from the first
round is unchanged. No commits, no pushes.

### Fixes

1. **Malformed precision/grouping is declined, not reinterpreted.**
   `hasExcessFractionDigits` (which only counted fractional digits and fell
   through to `Money.parse`'s lenient grouping) is replaced by
   `hasValidAmountShape` + `hasValidGrouping`. A single separator with more
   than two trailing digits is only accepted as thousands grouping when the
   groups are well formed: 3-digit US/European groups, or the Indian
   2-then-3 pattern. The first group may not be a bare/leading zero.
   - `Paid $12.3456 at Cafe` → `nil` (was `123456`).
   - `$0.001` and `Paid ₹0.001 debited` → `nil` (was `1`).
   - `Paid $1.234.56 at Cafe` → `nil` (was `123456`).
   - `spent $1,23,4.50 at Amazon` → `nil` (was `1234.5`).
   - `Rs 12.34.56 debited` → `nil` (was `123456`).
   - `$1,2345.67 debited` → `nil` (was `12345.67`).
   - Kept: `€1.234,56`→`1234.56`, `$1,234.56`→`1234.56`,
     `₹1,23,456.78`→`123456.78`, `1.234`→`1234`, `€1.234.567`→`1234567`,
     `$1.23`→`1.23`.
2. **A decisive invalid qualified amount no longer falls through.** The
   qualified pool no longer filters `value != nil`. All qualified candidates
   enter `bestCandidate`; the selected candidate is then gated by
   `let value = best.value`, so an over-cap or malformed decisive amount
   declines the whole text instead of a later amount standing in for it.
   - `Paid $1,000,000,000 then paid $12` → `nil` (was `12`).
   - `spent $999,999,999,999 then paid $12` → `nil` (was `12`).
   - Kept: `Rs 500 debited at Swiggy. Avl Bal Rs 999,999,999,999` → `500`;
     `Paid $12 at Starbucks. Avl Bal $999,999,999,999` → `12`;
     `spent $1,000,000,000 at Amazon` → `nil`.

### Regressions added (`Tests/TapLogTests/ShareParserTests.swift`)

- `testMalformedPrecisionIsNotReinterpretedAsGrouping` (fails pre-fix)
- `testSubCentCandidateIsNotInflatedToWholeUnits` (fails pre-fix)
- `testValidGroupingFormatsRemainSupported` (guard; passes both)
- `testInvalidDecisiveSpendDeclinesRatherThanFallingThrough` (fails pre-fix)
- `testValidSpendSurvivesInvalidUnrelatedBalance` (guard; passes both)

### Exact checks and results

1. **Fixed behavior, focused XCTest (actual `ShareParser.parse`).** Isolated
   copy `git archive HEAD` + my two files, under
   `/private/tmp/taplog-worker-2-check/round1-src` (shared generated project is
   missing other workers' untracked files, so it cannot host the focused run).
   `xcodebuild test -project TapLog.xcodeproj -scheme TapLog -destination
   'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -parallel-testing-enabled
   NO -derivedDataPath /private/tmp/taplog-worker-2-check/DerivedDataRound1
   CODE_SIGNING_ALLOWED=NO -only-testing:TapLogTests/ShareParserTests`.
   Log `round1-focused.log`, 12:27:41–12:28:42 IST. Result: **31 tests
   executed, 0 failures, exit 0** (26 existing + 5 new). Join key: XCTest
   identity; no production data.
2. **Pre-fix failure proof, same XCTest.** Same copy with the first-round
   `ShareParser.swift` (result-2 state) restored. Log `round1-prefix2.log`,
   12:39:33–12:50:15 IST, exit 65. Exactly the three regression tests fail (10
   assertion failures): `testMalformedPrecisionIsNotReinterpretedAsGrouping`,
   `testSubCentCandidateIsNotInflatedToWholeUnits`,
   `testInvalidDecisiveSpendDeclinesRatherThanFallingThrough`. Both guard tests
   pass, so the old code was not merely under-tested.
3. **Standalone source harness** (`swiftc -O`, real `ShareParser` + `Money`,
   dummy `StoreLocator`) under
   `/private/tmp/taplog-worker-2-check/round1-harness/{current,fixed}`. 17
   focused cases: pre-fix 5 fail, fixed 17/17 pass. This includes the
   `Paid $1,000,000,000 at Amazon. Avl Bal Rs 500` shape.

### Remaining limitations

- **Ambiguous multi-transaction where the invalid amount is second is not
  declined.** `Paid $12 then paid $1,000,000,000` returns `12` (first valid
  spend nearest a verb wins). Only the decisive-first shape declines. Reported,
  not guessed at. **Resolved in the round 2 correction below.**
- The leading-zero-first-group rule rejects any grouped token whose first group
  starts with `0` (e.g. `0.001`), even if a sub-cent decimal reading existed.
  Conservative by design.
- Indian grouping support is limited to the 2-then-3 pattern; other
  non-standard group sizes are declined.
- Focused suite only. Combined working-tree suite still not run; the parent must
  regenerate the project (other workers' untracked files) before combining.
- No UI/simulator share-sheet invocation and no physical-device evidence.

## Round 2 correction (review) — DONE

Worked 11 October 2026 IST, 16:51–16:56 IST. Same owned paths only:
`ShareParser.swift` and `ShareParserTests.swift`. No nested agents. No commits,
no pushes, no simulator. `xcodebuild` was skipped as instructed; verification
used the existing standalone source harness and `swiftc` only.

### Fix

`bestCandidate` gained one guard before it picks a winner. It already computed,
per candidate, whether a spending verb is within the context window
(`isSpending`) and whether a balance marker is too (`hasMarker`). It now counts
the candidates that are both spending and **not** next to a balance marker. If
more than one such candidate exists, the parse returns `nil`: two numbers each
beside a spending verb are two separate transactions in one shared text, and
picking the nearer one silently drops the other.

- `Paid $12 then paid $1,000,000,000` → `nil` (was `12`).
- `Paid $1,000,000,000 then paid $12` → `nil` (already nil, now for the
  multi-spend reason too). Already-nil shape is kept.
- `Paid $12 at Cafe then paid $20 at Uber` → `nil` (two valid distinct spends).
- `Paid $20 at Uber then paid $12 at Cafe` → `nil`.

A balance is not a second spend, so the existing single-spend-preserved cases
are unchanged: `Paid $12 at Starbucks. Avl Bal $345.67` → `12` and
`Rs 500 debited at Swiggy. Avl Bal Rs 999,999,999,999` → `500`. Several payment
synonyms around one amount are still one candidate and one transaction:
`Rs 500 debited as payment to Uber` → `500` and
`Your payment of Rs 500 was debited from your account` → `500`.

Smallest change: one computed filter plus a two-line early return in the
existing candidate/verb selection. No new type, helper, regex or framework.

### Regressions added (`Tests/TapLogTests/ShareParserTests.swift`)

- `testDistinctSpendsDeclineInEitherOrder` (fails pre-fix: first assertion
  returned `12`)
- `testTwoValidDistinctSpendsDecline` (fails pre-fix: returned `12` and `20`)
- `testSingleSpendSurvivesUnrelatedBalance` (guard; passes both)
- `testSynonymousSingleDebitStaysValid` (guard; passes both)

### Exact checks and results

1. **Standalone source harness, fixed vs pre-fix, real `ShareParser.parse`.**
   Harness `/private/tmp/taplog-worker-2-check/round2-harness/{fixed,prefix}`,
   built with `swiftc -O` from `ShareParser.swift` + `Money.swift` + dummy
   `StoreLocatorStub.swift`. `fixed` is the working tree; `prefix` is the
   round-1 `ShareParser.swift` (`round1-fixed-ShareParser.swift`). Window
   16:52–16:54 IST. Filter: 62 asserted parser cases (every existing
   `ShareParserTests` amount assertion plus the four new regressions).
   Join key: literal input text; no production data. Result: **fixed 62/62
   pass, exit 0**; **pre-fix 3 failures, exit 1** — exactly
   `Paid $12 then paid $1,000,000,000` (got 12), `Paid $12 at Cafe then paid $20
   at Uber` (got 12), `Paid $20 at Uber then paid $12 at Cafe` (got 20).
2. **Syntax/parse check on the real file.**
   `xcrun swiftc -parse Sources/TapLog/Shared/ShareParser.swift` → exit 0.
3. **No `xcodebuild`/simulator run**, per the instruction. The 62-case harness
   covers every existing `ShareParserTests` amount assertion, but the XCTest
   file itself was not recompiled or run in this pass.

### Remaining limitations

- **Conservative over-decline of an incidental second number.** Because the
  ambiguity rule counts any two nearby spending candidates, a message that
  names the spend and a quantity in the same window declines, e.g.
  `You spent 12.50 on 2 items` → `nil` (pre-fix `12.50`). This keeps the rule
  to the single smallest change and prefers a decline over a guess. It is
  recorded as an observation in the harness, not asserted as desired behavior.
  A quantity-aware rule was out of scope for this bounded pass.
- `Rs 500 and Rs 200 debited` and `Rs 500 debited. Amount Rs 500.` now decline
  (pre-fix returned `200` and `500`). Both are multi-amount texts, so declining
  is the conservative reading of "distinct spends must decline".
- The earlier precision, grouping, Indian-grouping and single-currency
  limitations above still stand.
- Focused harness only. The XCTest regression file was not run in this pass;
  the parent must run the combined suite after regenerating the project.
- No UI/simulator share-sheet invocation and no physical-device evidence.
