# TapLog — open items, 11 November 2026

Supersedes the "clear the open issue queue" framing in `docs/STATE.md` and
`docs/plan-issue-queue-2026-11-09.md`. That queue is empty; the gate is working
again. What is left is (a) work that exists only on this disk, (b) one open
issue, and (c) the submission gates.

Live state at the time of this scan:

| Fact | Value |
|---|---|
| Open issues | **#79 closed** by PR #97 on 11 Nov 13:27 UTC; #98 was its follow-up |
| Open PRs | **0** |
| Default branch | `budget-trees-redesign` @ `130801d` |
| Gate | working — `pr-gatekeeper` succeeded 2026-11-09 17:08Z on PR #90 |
| CI on default branch | `success` on `a235dfc` (PR #77 merge) |
| Local checkout | `6738695` — **51 commits behind** origin, 0 ahead, dirty |
| Tracked release gate list | `docs/release-runbook.md`, S1–S12 and L1–L8, **all unclosed** |
| Untracked gate list | `docs/appstore-readiness-checklist.md`, "20 proven, 61 open" (12 Oct) |

**Status 11 Nov, 16:30 IST.** The checkout is reconciled and published, the
documents are in git, the test baseline is recorded, and #79 is closed by PR #97.
Issue state: #92, #93, #94 and #95 closed; #97 merged; #98 is the follow-up this
edit answers; #96 stays open because it needs the owner and Apple.

| Issue | Work | State |
|---|---|---|
| #92 | Reconcile the checkout; archive and retire the superseded source | closed |
| #93 | Archive or land `chatgpt-plugin` | closed — not built, branch kept |
| #94 | Local test baseline on the merged head | closed — 512 tests, 0 failures |
| #95 | Branches and stale `pr/*` refs | closed |
| #96 | Owner inputs and App Store Connect gates | open |

---

## P0 — Stop the only copy of the release work from being lost

The release review, its evidence, the submission checklist and the phone QA sheet
exist **only as untracked files in this checkout**. No commit, no branch, no remote.

- [x] **Capture the untracked documentation.** Done in `bc15e57` on
      `docs/release-gate-evidence-2026-11-11` (124 files, 7.3 MB). Original text:
      39 modified tracked files
      (+2,290/−388) and 34 untracked paths, of which these have no other copy:
      - `docs/STATE.md`, `docs/plan-issue-queue-2026-11-09.md`
      - `docs/appstore-readiness-checklist.md`, `docs/appstore-code-review.md`,
        `docs/release-fix-verification-plan.md`, `docs/release-fix-results.md`
      - `docs/signed-build-testflight-runbook.md`, `docs/physical-device-qa-sheet.md`,
        `docs/iphone-setup-guide.md`
      - `docs/review-evidence/` (4.5 MB of test + Release logs and screenshots),
        `docs/work-orders/`, `docs/logo-design/` (2.5 MB)
      - `reports/taplog-on-device-tests-2026-10-24.html`
      Suggested capture, reviewed before running — commit to a branch, do not push:
      ```sh
      git switch -c docs/release-gate-evidence-2026-11-11
      git add docs reports
      git commit -m "docs: capture the release gate, review evidence and device QA plan"
      ```
- [x] **Decide what happens to the divergent code, then discard it.** Archived as
      `94609be`, then deleted after a compile test proved all three archived test
      files fail to build against the merged head (`CaptureBottomBar` constants,
      `CurrencyChange`, `WidgetQuickLogWriter` are gone). The dirty source was the
      *pre-supersession* design, never new value:
      - `Sources/TapLog/AppIntents/AmountEntity.swift`, `LogAmountIntent.swift`,
        `Shared/SpokenAmountParser.swift` — the numeric intent and entity that
        origin's `docs/decisions.md` says were **removed** ("the removed numerical
        intent and entity are not part of the supported flow"; "`Log 50 in TapLog`
        is unsupported"). Never committed on any branch.
      - `Sources/TapLog/Settings/PrivacyPolicyView.swift` — committed once in
        `92fcd99`, then superseded upstream by `PrivacyView`
        ("The privacy screen states current behavior and links no policy page").
      - `README.md` in this checkout still promises "Hey Siri, log 25 rupees"; the
        merged README says that phrase is unsupported.
      - `project.yml`, `TapLog.xcodeproj`, `appstore/*` here are older than origin.
- [x] **Reconcile the main checkout to origin.** Done 11 Nov: `budget-trees-redesign`
      moved to `origin/budget-trees-redesign`, the captured docs merged, and the
      documentation pushed (`130801d..1c46f2b`). Working tree clean apart from
      untracked tooling.
- [x] **Push or archive `chatgpt-plugin`.** Pushed to origin, then recorded as not
      built and not landed (#93). The branch is the only copy, so it is kept.
- [x] **Delete the stale state docs or mark them resolved.** Both carry a
      superseded banner in `a810bf3`; they describe 9 open issues, 10 open PRs and
      a dead `GATEKEEPER_READ_TOKEN`, all false now.

## P1 — Issue #79 (closed 11 Nov 2026)

The five questions are answered, the decision is recorded, and the prompt pack is
merged. The plugin is not built. The report page stays on `spike/issue-79` as the
research record and needs no PR now that the decision supersedes it.

- [x] **Answer the five questions.** Answered 11 Nov; the table is in #79.
- [x] **Record the decision** in `docs/decisions.md` ("Assistant access starts as an
      export pack, and Siri comes second"). Merged in #97.
- [x] **Draft the prompt pack** in `docs/assistant-export-prompts.md`. Merged in #97.
- [x] **Raise the PR for the spike.** The decision PR supersedes the branch-only
      report, so the report is not merged.
- [x] **Decide the parked plugin's fate.** Not built and not landed; the branch is
      pushed as the only copy, recorded in #93.

## P2 — Repo hygiene

- [x] Prune **14 prunable worktrees** (`git worktree prune`): done 11 Nov 15:47 IST,
      3 worktrees remain. Original list: `idg-issue79`,
      `idg-issue84`, `idg-pr77`, `taplog-release-fixes`, `idg-pr67`–`idg-pr76`, `idg-scratch`.
      Two live worktrees stay: `ideadump-worktrees/chatgpt-plugin` and `/review-fixes`.
- [x] Delete merged local branches and the 39 stale `remotes/pr/*` refs. Done 11 Nov:
      11 branches deleted, refs at 0, archive branch removed after the compile test.
- [ ] Decide whether agent tooling belongs in the repo: `.agents/`, `agent/`,
      `.claude/`, `skills-lock.json` are untracked and unignored.
- [ ] One Release build for generic iOS after the reconciliation, to confirm no
      warnings regressed (last evidence: 11 Oct, `docs/review-evidence/final-release.log`).

## P3 — Verification baseline

- [x] Run the suite on the reconciled `budget-trees-redesign` and record the count.
      **Done 11 Nov 2026, 15:34–15:36 IST**: a clean worktree at
      `origin/budget-trees-redesign` (`130801d`), regenerated with XcodeGen 2.46
      (no project diff), and **512 tests executed, 0 failures, `** TEST SUCCEEDED **`**
      on Xcode 27.2, simulator iPhone 17. Log: `/tmp/taplog-verify-tests.log`.
      The count matches the 512 declared test functions on origin.
      ```sh
      xcodegen generate
      git status --porcelain -- TapLog.xcodeproj        # must be empty
      xcodebuild test -project TapLog.xcodeproj -scheme TapLog \
        -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
        -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
      ```
- [ ] Re-run the four device-traced fixes from the closed queue — #63 widget totals,
      #65 share parsing, #64 Siri category, #60 splash-from-widget — once on hardware.
      Merge did not prove them.

## P4 — Owner inputs (nothing else unblocks without these)

- [ ] Support email → replaces `SUPPORT_EMAIL` in `appstore/support.html`.
- [ ] Two hosted HTTPS URLs → `appstore/metadata.md` has both marked
      **Unresolved — owner pending**, and the listing cannot be submitted without them.
- [ ] Review contact (name, email, phone) for App Review.
- [ ] `DEVELOPMENT_TEAM` flip from the personal team (`87VL9T9A8H`) to the paid team,
      with the App Group `group.dev.amteshwar.taplog` registered for all three targets.
- [ ] Pro price, launch countries, and the `siri` keyword decision (guideline 2.3.7).
- [ ] Legal decisions L1–L8 from `docs/release-runbook.md`: enrollment, Paid Apps
      Agreement, W-8BEN, bank, EU DSA trader status, trademark, jurisdiction review,
      IAP attached to version 1.0.

## P5 — Signing, TestFlight and App Store Connect

- [ ] S1–S2 of `docs/release-runbook.md`: signed Release build of app + both
      extensions, archive entitlements inspected; Xcode 26 / iOS 26 SDK minimum.
- [ ] Run `docs/signed-build-testflight-runbook.md` steps 2–6: archive, validate,
      upload, resolve processing warnings, install the processed build via TestFlight.
      Raise `CURRENT_PROJECT_VERSION` per upload.
- [ ] App Store Connect: app record, product `dev.amteshwar.taplog.pro.lifetime`,
      agreements/tax/banking, regional availability, privacy answers.
- [ ] Current age-rating questionnaire (post-31 Jan 2026 system; 4+/9+/13+/16+/18+/Unrated).
- [ ] First non-consumable submitted with the 1.0 version, with a review screenshot.
- [ ] Screenshots: confirm 1320×2868, opaque, current UI, no misleading sample data.
- [ ] Listing accuracy: no unmeasured speed claim, no absolute "100% offline",
      StoreKit network use described, backup inclusion stated as configuration-dependent.

## P6 — Physical device QA (`docs/physical-device-qa-sheet.md`)

- [ ] 1. Core capture and persistence · 2. Siri (both intents, missing params, cancel)
      · 3. Action Button (both advertised shortcuts) · 4. Widgets (all families, Lock
      Screen circular/rectangular, daily total, one tap one save) · 5. Share sheet
      (SMS, bank text, OTP-only, no amount) · 6. Persistence and storage (kill/relaunch,
      cross-process, locked device, fallback-vs-shared store, upgrade from a prior
      schema) · 7. Export (CSV opened in Numbers and Excel, two concurrent exports)
      · 8. Purchase and restore (success, cancel, pending/Ask to Buy, delayed approval,
      unverified, refund, offline, reinstall, second device) · 9. Notifications
      (permission timing, Sunday delivery, cold-launch tap, wipe clears the reminder)
      · 10. Accessibility (VoiceOver, Dynamic Type to AX sizes, Reduce Motion,
      high contrast, light/dark).
- [ ] Measure capture speed on hardware for each route, or keep the five-second claim
      out of the listing. No route has a measured number today.

---

## Order of work

1. **P0 docs capture** — minutes, and it is the only irreversible risk here.
2. **P0 reconciliation + P3 test run** — puts the checkout back on the real head and
   gives a trustworthy baseline.
3. **P1 #79** — the one open issue, and its research is already done.
4. **P4 owner inputs** — the long pole for launch; ask for all five in one message.
5. **P5 then P6** — signing/TestFlight first (it is the gate for the device pass),
   then the phone QA run against the processed build.

Nothing in P4–P6 can be closed by an agent. `docs/release-runbook.md` states it
plainly: no gate in that list has been closed, and an item with no artifact is not
tested.
