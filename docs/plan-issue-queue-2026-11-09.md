# Plan — clear the open issue queue (Ami-Khokhar/ideadump)

Inventory verified 2026-11-09 02:15 IST with `gh` as Ami-Khokhar. Supersedes the
progress section of docs/STATE.md (2026-11-07); the blocker changed.

## Where things actually stand

| Fact | Value | How checked |
|---|---|---|
| Open issues | 9 — #76, #66, #65, #64, #63, #62, #60, #59, #58 | `gh issue list --state open` |
| Open PRs | 10, one per issue, plus 2 orphans (#77 docs policy, #57 factory bootstrap) | `gh pr list` |
| PR mergeability | all 10 `MERGEABLE`, no conflicts | `gh pr list --json mergeable` |
| CI on every PR | `Build and test = pass` on all 10 | `gh pr checks` |
| Closes link | all 9 issue PRs carry `Closes #n`, so merge closes the issue | `gh pr view --json body` |
| Only failing check | `gatekeeper / gates = fail` on all 10 | `gh pr checks` |
| Last green gate run | 2026-10-30 | `gh run list --workflow pr-gatekeeper` |

So the code work is done and green. **Nothing is left except a broken credential.**

## The one blocker, diagnosed

`gatekeeper / gates` dies at:

```
##[error]fatal: could not read Username for 'https://github.com': terminal prompts disabled
```

The gate workflow clones the private tool repo `Ami-Khokhar/pr-gatekeeper` at
`ee2f2dc` using secret `GATEKEEPER_READ_TOKEN`. That secret was set 2026-10-04 and
the last successful clone was 2026-10-30 — a fine-grained PAT that expired.

New evidence today: the local keychain item `pr-gatekeeper-read-token` **still reads
the private repo** (verified: `repos/Ami-Khokhar/pr-gatekeeper` returns
`private=true`). The local token is good; the copy in GitHub is stale.

Fix (owner or approved-by-owner, writes a secret to GitHub):

```sh
security find-generic-password -s pr-gatekeeper-read-token -w \
  | GH_TOKEN="$(gh auth token --user Ami-Khokhar)" gh secret set GATEKEEPER_READ_TOKEN --repo Ami-Khokhar/ideadump
```

Second option if that token is also near expiry: make `Ami-Khokhar/pr-gatekeeper`
public, then `github.token` can clone it and the secret stops mattering.

## The nine work units

All are already built and pushed. The column that matters now is "what could still
bounce back in review".

| Issue | PR | Branch | What the PR does | Tests | Risk on round 2 |
|---|---|---|---|---|---|
| #76 accessory widget follow-up | #78 | `followup/issue-76` | routes accessory families through a data model, fixes VoiceOver labels, drops dead `.accessoryInline` | +4 (427→431) | needs one device check of tap/accessory background |
| #66 dead gap above keypad | #75 | `codex/issue-66` | `CaptureFit` decides fill vs scroll, viewport frame is a minimum | +6 | layout is only statically reviewed |
| #65 share sheet finds no amount | #74 | `codex/issue-65` | reads `attributedContentText`, accepts `Data`/`NSAttributedString`, splits "nothing shared" from "no amount" | +10 | parser still untested on the owner's real SMS |
| #64 Siri refuses to log | #73 | `codex/issue-64` | surfaces `CategoryEntity` store failure, SSU check, prunes unsupported phrases | +6 | SSU drop cause not proven on device |
| #63 widget shows stale totals | #72 | `codex/issue-63` | fresh `ModelContext` per timeline read, logs store path and total | +5 | needs a physical-device confirm |
| #62 widget cadence and rollover | #71 | `codex/issue-62` | midnight entry, reload on currency change and foreground, `WidgetReload` seam | +14 | refresh budget is still best-effort by design |
| #60 splash aborted from widget | #69 | `codex/issue-60` | `OpeningAction` decides before first render, splash not mounted when skipping | +5 | cold-launch timing needs a device run |
| #59 paywall criteria and placement | #68 | `codex/issue-59` | Settings gets its own honest reason, policy written in `docs/decisions.md` | +2 | it is a decision record, not a behaviour change |
| #58 History edit/delete invisible | #67 | `codex/issue-58` | visible row actions, full swipe becomes Delete, context menu | +5 | none known |

Orphans: PR #77 (documentation-policy migration — never got a gate verdict, decide
keep or close), PR #57 (factory bootstrap, gate CLEAN, never merged).

## Phases

**P0 — unblock the gate (owner, 1 minute).** Refresh `GATEKEEPER_READ_TOKEN`
(command above). Verify with `gh secret list --repo Ami-Khokhar/ideadump` (timestamp
must be today).

**P1 — re-review all 10 PRs (no code).** One `workflow_dispatch` per PR, which is
free of side effects:

```sh
for n in 78 75 74 73 72 71 69 68 67 77; do
  GH_TOKEN="$(gh auth token --user Ami-Khokhar)" gh workflow run pr-gatekeeper.yml -f pr=$n
done
```

Gate runs on GitHub's macOS runners, so this costs nothing locally. Expect most to
come back `MERGE` — round-1 findings were the "no test that fails without it" class
and every PR now carries the seam plus test the finding asked for.

**P2 — fix only what comes back `CHANGES`.** One worker at a time: swap is at
2.19 GB of 3.07 GB, above the 2 GB line in `~/.config/agent-shared/LEARNINGS.md`, so
no parallel `xcodebuild`. One build ≈ 12–20 min. Max 3 rounds, then it goes HUMAN by
design. The 2026-11-07 worktrees live in `/private/var/folders/.../T/opencode/` and
will be wiped on reboot — recreate with `git worktree add` if needed.

**P3 — gate merges.** Each merge closes its issue automatically. Target:
`gh issue list --state open` returns 0.

**P4 — the two orphans.** #77: run the gate, then keep or close. #57: it is already
CLEAN, it just needs the gate to merge it.

**P5 — post-merge verification.** On the merged default branch:

```sh
xcodegen generate && git status --porcelain -- TapLog.xcodeproj   # empty
xcodebuild test -project TapLog.xcodeproj -scheme TapLog \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' CODE_SIGNING_ALLOWED=NO
```

Baseline was 427 tests, 0 failures. Anything below that is a bad merge.

## What I will not do

- Merge by hand while the gate can still be fixed.
- Touch `.github/` in any PR branch.
- Force-push anything.
- Write the secret without your OK.

## Still unverified by anyone

Four of the nine fixes were traced from code, not reproduced on hardware: #63, #65,
#64, #60. Merge does not make them true. Each needs one device run of the steps in
its issue body — that is a separate, physical-device pass, not part of this queue.

## Round 1 gate verdicts (2026-11-09 03:26 IST)

The gate was run **locally** with its own tool (`python3 -m gatekeeper review --dry-run`,
`OPENCODE_GO_API_KEY` from `~/.pi/agent/auth.json`), because the hosted job cannot clone
the private tool repo. This is the real pipeline: stage-0 lint, the verify command on the
PR head, and the model review. It writes nothing to GitHub.

| PR | Issue | Verdict | Blocking finding |
|---|---|---|---|
| #71 | #62 | **MERGE** | none |
| #67 | #58 | CHANGES | the new tests assert constants; nothing reads `EntryListView`, so removing the pencil/trash fails nothing |
| #69 | #60 | CHANGES | the widget/URL cold-launch path is still unfixed — `skipSplash` is false at first render, so the plant still starts and is cut |
| #74 | #65 | CHANGES | the two failure sentences lived in the untested extension |
| #78 | #76 | CHANGES | reverting the label fix left all four tests green |
| #75 | #66 | HUMAN | 0 blocking, 3 minor (docstrings, constant assertions, a duplicated decision path) |
| #68 | #59 | HUMAN | 0 blocking, 3 minor |
| #73 | #64 | HUMAN | reviewer verdict `invalid` twice — model output not parseable, retry |
| #72 | #63 | HUMAN | reviewer verdict `invalid` twice — retry |

Also fixed before the run: all ten PR bodies failed the body lint (`## What changed`
listed `path:line` instead of bare paths, or omitted changed files). Every body now lists
exactly the changed paths.

## Work pushed after round 1

- **#78** `b8c106e` — two source assertions that fail when the accessibility fix is
  reverted (verified by putting the `ZStack` back: test fails, passes with the fix).
- **#74** `c659cb6`, `21476ab` — `ShareOutcome` owns both failure sentences and the rule
  that picks them; the extension asks it (source assertion guards the call site, verified
  failing when reverted). Plus a test for the boxed `NSAttributedString?` the extension
  actually passes, which was round 2's blocking finding.

## What the gate taught us about the queue

A CHANGES verdict with minors only still escalates to HUMAN, so a PR reaches MERGE only
with zero findings. Every PR needs one more pass:

| PR | Next step |
|---|---|
| #71 | ready; needs a publish and merge (secret, or a local non-dry-run gate) |
| #78 | update the body's test counts, fix the `captureURL` claim in `docs/decisions.md` (or the second site in `TapLogControlWidget`), strengthen or delete the constant-label test |
| #74 | seven minors: make `ShareOutcome` carry the amount so the unreachable guard goes, align the zero-amount rule with `ShareTextCollector`, bound payloads at load, fix two doc comments and one body claim |
| #75 | three minors: two stale docstrings, replace the constant assertions with two relationship assertions, and either drop the duplicate `usesScroll` pre-check or say plainly that it is a fast path |
| #69 | one real blocking finding: decide the opening action after one runloop yield so the widget/URL launch never mounts the plant; then name the parameter for what it is |
| #67 | one blocking finding: read `EntryListView` in the test, or move the row controls behind a testable seam |
| #68 | three minors |
| #73, #72 | rerun the review; the verdict came back `invalid` twice |
