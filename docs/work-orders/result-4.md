# Worker 4 result — release docs and verification plan

Status: DONE for the documentation scope. No application code was changed. The combined
simulator suite was **not** run from this worker because worker 2 was running an
`xcodebuild build-for-testing` job in `/private/tmp/taplog-worker-2-check` at the time, and
this task is documentation-only. The orchestrator runs the combined suite.

## Review correction round 1 (documentation only)

Review said the App Store description still had an unmeasured comparative claim ("TapLog
is the fastest way") and that the README opening promised "under five seconds". This
round removed the remaining unsupported comparative/timing wording from the two
release-facing worker-4 paths and re-checked the metadata count annotations.

- `appstore/metadata.md` Description: "TapLog is the fastest way to write down what you
  just spent, and a small grove of trees that shows how your budgets are doing." →
  "TapLog writes down what you just spent, and grows a small grove of trees that shows
  how your budgets are doing." No comparative or timing claim. No price, contact, URL or
  legal text added.
- `README.md` opening: already read "log a purchase from the Action Button, a widget,
  Siri, or the share sheet" (round 4 had removed "capture a purchase in under five
  seconds"). Confirmed no timing claim there; no further change needed.
- `README.md` Status: "Capture timing. No route has a measured speed claim." → "Capture
  timing. The five-second capture goal is an unverified QA criterion, not a shipped
  claim. No route has a measured speed claim." The five-second goal now appears only as
  an explicitly unverified QA criterion.
- `README.md` widget step: "tap ☕️/$12 to log instantly." → "tap ☕️/$12 to log it."
  Removed the remaining timing adverb from the release-facing README.
- `appstore/metadata.md` Description heading: the count annotation was stale at
  `(1481/4000)` before this round while the text already measured 1542. Updated to the
  measured value after the text edit: `## Description  (1527/4000)`.

No new price, contact, URL or legal claim was introduced. No app code, test, project
file or generated project was touched in this round.

## Changed paths

- `README.md`
- `appstore/metadata.md`
- `appstore/support.html`
- `appstore/privacy-policy.html`
- `launch-distribution-kit.md`
- `docs/release-fix-verification-plan.md` (new)
- `docs/work-orders/result-4.md` (this file)

No edits to `docs/STATE.md`, `docs/appstore-code-review.md`,
`docs/appstore-readiness-checklist.md`, `project.yml`, `TapLog.xcodeproj`, source or tests.

## Concrete behavior and fixes (documentation)

1. **Code vs external steps are separated.** README Status and `appstore/metadata.md` now
   say the simulator/unit evidence is not distribution evidence, list the P1/P2 code fixes
   as in progress, and list signing, real-device, sandbox and Connect steps as unverified.
2. **Age rating corrected.** The old "4+ / answer None" row is replaced with the current
   requirement: complete Apple's questionnaire in App Information → Set Up Age Ratings.
   Since 31 January 2026 all apps use the updated system (4+, 9+, 13+, 16+, 18+, Unrated).
   No pre-answered "None" and no assumed 4+.
3. **Action Button reconciled to two workflows.** README, metadata review notes and
   support.html now describe both supported shortcuts: *Open Expense Capture* (opens the
   focused keypad) and *Log Expense* (headless, prompts for amount → category → optional
   note). Either can be assigned to the Action Button. The README/metadata mismatch is
   gone.
4. **Privacy policy is accurate about the network and backups.** Removed "makes no network
   requests of its own". Now: the only network communication is Apple's StoreKit for the
   Pro purchase; backup inclusion depends on backup configuration and is not verified for
   every configuration. Support page matches.
5. **Pending email and URLs are marked, not invented.** `support.html` and
   `privacy-policy.html` keep the `SUPPORT_EMAIL` placeholder with an `UNRESOLVED (owner
   pending)` HTML comment. `metadata.md` marks Support URL and Privacy Policy URL as
   **Unresolved — owner pending**. No fabricated contact or hosting.
6. **Marketing claims reviewed conservatively.** `launch-distribution-kit.md` banner now
   lists the unverified claims. Corrected inline: removed "2 seconds"/"2.3 seconds",
   "100% offline", "zero network requests", "0 network permissions", "SQLite" (now
   SwiftData), ₹299/₹499 pricing (now placeholder), iOS 16/17/18 (now iOS 17+), and
   aligned the Action Button wording. IAP price in metadata is marked a placeholder and an
   owner decision.
7. **New ordered verification plan.** `docs/release-fix-verification-plan.md` has phases
   for baseline reproduction, R1–R3 P1 regressions, R4–R7 P2 regressions, combined suite
   and Release build, storage/cross-process/notification/large-data runtime checks,
   packaging/assets, signing/device/Connect, and listing accuracy, plus an evidence-log
   template and stop rules.
8. **Free/Pro semantics preserved and documented.** The plan re-checks unlimited logging,
   CSV export, three budget trees, weekly recap and lifetime Pro. No product semantics
   were changed.

## Regression names

None. This work order forbids application code changes, so there is no new app regression
to name. The plan references the regressions assigned to other workers (confirm the final
file and method names in their result files):
`ReleasePersistenceRegressionTests`, `UndoStackTests`, `StoreLocatorTests`,
`CaptureBookkeepingTests`, `ShareParserTests`, `ReleaseInputRegressionTests`,
`CSVExporterTests`, `ProStoreTests`, `ReleaseSettingsRegressionTests`.

## Exact real checks and results

- Metadata field-length recheck (this round, 11 October 2026 IST): parsed
  `appstore/metadata.md` headings of the form `## Field  (N/M)`, extracted each fenced
  `text` block and compared `len(text)` to `N` and to the Apple limit `M`. Result:
  App name 23/23/30, Subtitle 26/26/30, Keywords 98/98/100, Promotional text 158/158/170,
  Description 1527/1527/4000, IAP display name 10/10/30, IAP description 39/39/45 — all
  seven annotations match the exact text, all under the limits. The Description
  annotation was stale before the edit (annotated 1481, measured 1542) and is corrected.
  Source: `appstore/metadata.md` only; no join, no filter.
- Unsupported-claim scan (this round): case-insensitive grep for
  `fastest|under (five|5) second|five second|instantly|in seconds|2.5 second|two second`
  across the two release-facing paths `README.md` and `appstore/metadata.md`. Result: no
  matches, so no comparative or timing claim remains. The only speed wording left is the
  README Status line that labels the five-second capture goal an unverified QA criterion.
- HTML well-formedness: parsed `appstore/support.html` and
  `appstore/privacy-policy.html` with Python `html.parser`. Result: both `OK`, no
  unclosed or mismatched tags. Run 11 October 2026 IST.
- Asset inspection with `sips`: `Sources/TapLog/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
  is 1024×1024, `hasAlpha: no`, PNG. Three `appstore/screenshots/*.png` are 1320×2868,
  `hasAlpha: no`. Filter: those four paths, no data join.
- Source checks (read-only): `TapLogShortcutsProvider.swift` registers *Log Expense* and
  *Open Expense Capture*; `ProGate.freeBudgetLimit = 3` and `canExportCSV` always true;
  `Money.supportedCurrencies` has 17 entries; all three `PrivacyInfo.xcprivacy` files
  declare UserDefaults reasons `1C8F.1` and `CA92.1`; `project.yml` sets
  `DEVELOPMENT_TEAM: 87VL9T9A8H` (personal) with the paid team noted in a comment.
- Official Apple docs read (HTTPS GET, no account, no write):
  - `https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/`
    (HTTP 200) — Set Up Age Ratings flow and questionnaire.
  - `https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions/`
    (HTTP 200) — rating values 4+, 9+, 13+, 16+, 18+, Unrated and content descriptors.
  - `https://developer.apple.com/news/upcoming-requirements/` (HTTP 200) — ratings updated
    since 31 January 2026 and updated questions required.
  - `https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/`
    (HTTP 200) — first non-consumable must be submitted with a new app version.
- `git status --porcelain` confirms only the seven paths above are touched by this worker.
  Correction round 1 added no new path: this round edited only `README.md`,
  `appstore/metadata.md` and this result file. The other modified source and test files in
  the working tree belong to the concurrent workers, not to worker 4.
- Correction round 1 verification commands (both run in this working tree):
  `python3 -` metadata length parser over `appstore/metadata.md`, and
  `grep -rniE "fastest|under (five|5) second|five second|instantly|in seconds|2.5 second|two second" README.md appstore/metadata.md`.
  Results recorded in the two round-1 checks above. No build or simulator job was started
  this round, so no simulator contention with other workers.

## Remaining limitations

- Correction round 1 was documentation-only. No code, test or generated project was
  touched, so no build or simulator run was needed or performed this round; the
  round-4 note still stands that the combined suite is the orchestrator's step.
- `appstore/metadata.md` Subtitle still reads "Fast, private spending log". The review
  named the description and the README only, and "Fast" is a single adjective rather
  than a comparative or timing claim, so it was left unchanged and its count stays
  correct. Flag it if the owner wants it reworded too.
- `launch-distribution-kit.md`, `investor-pitch.md`, `build-plan.md`, the landing page
  and the UI mockups still contain speed claims (for example "under five seconds",
  "Under 2.5 seconds"). Those files are outside the two paths this review named. They
  are drafts and must be reconciled before anything is published.
- Combined `xcodebuild test` was not run here (documentation-only scope and a concurrent
  worker build). The orchestrator must run it after all workers stop.
- The support email and public support/privacy URLs remain unresolved per the owner. No
  contact or host was invented.
- Signing, real-device QA, sandbox purchase, archive validation, App Store Connect records,
  the age-rating questionnaire result and the first-IAP submission are unverified.
- Marketing copy in `launch-distribution-kit.md` is still a draft; every claim needs a
  final check against the Release build before posting.
- No stop-rule conflict was hit. No destructive migration, purchase, upload, registration
  or network write occurred.
