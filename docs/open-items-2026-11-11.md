# TapLog — open items, 11 November 2026

Supersedes the "clear the open issue queue" framing in `docs/STATE.md` and
`docs/plan-issue-queue-2026-11-09.md`. That queue is empty; the gate is working
again. What is left is (a) work that exists only on this disk, (b) one open
issue, and (c) the submission gates.

Live state at the time of this scan:

| Fact | Value |
|---|---|
| Open issues | **1** — #79 (assistant-access spike) |
| Open PRs | **0** |
| Default branch | `budget-trees-redesign` @ `130801d` |
| Gate | working — `pr-gatekeeper` succeeded 2026-11-09 17:08Z on PR #90 |
| CI on default branch | `success` on `a235dfc` (PR #77 merge) |
| Local checkout | `6738695` — **51 commits behind** origin, 0 ahead, dirty |
| Tracked release gate list | `docs/release-runbook.md`, S1–S12 and L1–L8, **all unclosed** |
| Untracked gate list | `docs/appstore-readiness-checklist.md`, "20 proven, 61 open" (12 Oct) |

---

## P0 — Stop the only copy of the release work from being lost

The release review, its evidence, the submission checklist and the phone QA sheet
exist **only as untracked files in this checkout**. No commit, no branch, no remote.

- [ ] **Capture the untracked documentation.** 39 modified tracked files
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
- [ ] **Decide what happens to the divergent code, then discard it.** The dirty
      source is the *pre-supersession* design, not new value:
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
- [ ] **Reconcile the main checkout to origin** once the docs are committed
      (`git switch budget-trees-redesign && git reset --hard origin/budget-trees-redesign`),
      so future work starts from `130801d`, not from a 51-commit-old tree.
- [ ] **Push or archive `chatgpt-plugin`.** One local-only commit, `f6b8434`,
      21 files / 2,774 lines: `plugins/taplog` MCP server (Node), two skills, a
      recap widget. Not on any remote. Ten minutes to lose.
- [ ] **Delete the stale state docs or mark them resolved.** `docs/STATE.md` and
      `docs/plan-issue-queue-2026-11-09.md` both describe 9 open issues, 10 open
      PRs and a dead `GATEKEEPER_READ_TOKEN`. All three facts are false now.

## P1 — Close issue #79 (the only open issue)

The spike is written but not delivered against its own acceptance criteria: a
decision in `docs/decisions.md` plus the prompt pack. `spike/issue-79` (6 commits,
pushed) carries only a report page; no PR, no decision entry, and the issue body
still says nothing has been designed.

- [ ] **Answer the five questions the report is waiting on** (pinned in the page's
      "Four things to settle"): A before D? · is the 1-in-100 share threshold fair? ·
      does the self-hosted bridge go in the record as "possible, not distributed"? ·
      who writes the six prompts? · are four read-only tools the whole surface?
- [ ] **Record the decision** in `docs/decisions.md`: Shape A (export pack today) then
      Shape D (Siri / Apple Intelligence), with cost, privacy-policy delta and the
      trigger that would justify Shape C (hosted connector).
- [ ] **Draft the prompt pack** against a real CSV export from the simulator
      (six prompts; the report claims it is a day's work).
- [ ] **Raise the PR for the spike** and drop `.taste-skill/direction.json` from the
      branch — it is a build-tool artifact, not a deliverable.
- [ ] **Decide the parked plugin's fate.** `f6b8434` implements Shape B/C ahead of the
      decision; the spike's own last commit parks it as "Ask AI". Keep as reference in
      a branch, or delete.

## P2 — Repo hygiene

- [ ] Prune **14 prunable worktrees** (`git worktree prune`): `idg-issue79`,
      `idg-issue84`, `idg-pr77`, `taplog-release-fixes`, `idg-pr67`–`idg-pr76`, `idg-scratch`.
      Two live worktrees stay: `ideadump-worktrees/chatgpt-plugin` and `/review-fixes`.
- [ ] Delete merged local branches: `codex/issue-58` … `codex/issue-66`,
      `followup/issue-76`, `followup/issue-84`, `chore/documentation-policy-migration`;
      and the 39 stale `remotes/pr/*` refs.
- [ ] Decide whether agent tooling belongs in the repo: `.agents/`, `agent/`,
      `.claude/`, `skills-lock.json` are untracked and unignored.
- [ ] One Release build for generic iOS after the reconciliation, to confirm no
      warnings regressed (last evidence: 11 Oct, `docs/review-evidence/final-release.log`).

## P3 — Verification baseline

- [ ] Run the suite on the reconciled `budget-trees-redesign` and record the count.
      Origin has 512 `func test` declarations; the newest recorded execution count is
      **423** (11 Oct, different tree). The two numbers are not comparable evidence.
      ```sh
      xcodegen generate
      git status --porcelain -- TapLog.xcodeproj        # must be empty
      xcodebuild test -project TapLog.xcodeproj -scheme TapLog \
        -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
        CODE_SIGNING_ALLOWED=NO
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
