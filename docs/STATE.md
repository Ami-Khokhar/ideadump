# STATE — clear the open issue queue (Ami-Khokhar/ideadump)

Started: 2026-11-07. Updated: 2026-11-09 IST.

> **Superseded 2026-11-11** by `docs/open-items-2026-11-11.md`. Three facts
> below are no longer true: the open queue is 1 issue (#79) and 0 pull
> requests; the `pr-gatekeeper` credential works again (success 9 Nov 2026
> 17:08 UTC on PR #90); and this checkout is 51 commits behind
> `origin/budget-trees-redesign`. Kept as the record of the 7–9 November queue.

> 2026-11-09: current plan is `docs/plan-issue-queue-2026-11-09.md`. Blocker
> refined — local keychain token `pr-gatekeeper-read-token` still reads the
> private gate repo, so the GitHub secret is stale, not revoked. One command
> fixes it; see the plan. Code work is done and CI-green on all 10 PRs.

## Goal

Close all 9 open issues by getting one PR per issue to `gatekeeper:approved` and merged.

## Inventory (source: `gh issue list` / `gh pr list`, 2026-11-07 IST)

- Open issues: 9 — #76, #66, #65, #64, #63, #62, #60, #59, #58
- Closed issues: 28. Open PRs: 10. Merged PRs: 29.
- PRs still to raise: **1** (issue #76) — DONE, opened as PR #78.
- Issues with a PR already open: **8**, one PR each.
- Blocker: all 8 carried `gatekeeper:changes` (blocking finding almost always
  "behaviour change has no test that fails without it"). 7 also conflicted with
  base in `docs/decisions.md`.
- Not tied to an open issue: PR #57 (factory bootstrap, CLEAN), PR #77 (docs
  policy, gatekeeper run failed).

Work units = 8 PR fixes + 1 new PR = 9.

## BLOCKER — pr-gatekeeper infrastructure is down

The gate's `gates` job dies cloning its own tool repo:

    repository: Ami-Khokhar/pr-gatekeeper   (private)
    token: ${{ secrets.GATEKEEPER_READ_TOKEN || github.token }}
    ##[error]fatal: could not read Username for 'https://github.com': terminal prompts disabled

`GATEKEEPER_READ_TOKEN` is the only credential that can read that repo;
`GITHUB_TOKEN` is scoped to `ideadump` alone. Last success 2026-10-30 (9 runs),
first failure 2026-10-31T08:14Z, failing again 2026-11-07 on PR #78.

Fix is the owner's (never handled by an agent — secrets):

    gh secret set GATEKEEPER_READ_TOKEN --repo Ami-Khokhar/ideadump < /path/to/new-token

Until then no PR can reach `gatekeeper:approved`, so nothing can merge.
Per AGENTS.md ("pr-gatekeeper merges. If it is down, I merge.") and the skill's
hard rule, the agent does NOT merge. Work continues; merge waits for the owner.

## Done when

`gh issue list --state open` returns 0.

## Verify command (from `.github/workflows/ci.yml`)

```sh
xcodegen generate
git status --porcelain -- TapLog.xcodeproj        # must be empty
xcodebuild test -project TapLog.xcodeproj -scheme TapLog \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  CODE_SIGNING_ALLOWED=NO
```

Baseline on `origin/budget-trees-redesign`: **427 tests, 0 failures, TEST SUCCEEDED**
(Xcode 27.2). Note: `iPhone 17 Pro` does not exist on the installed OS — use
`iPhone 17` or `iPhone 18 Pro` (`OS=latest`), one simulator per concurrent worker.

## Progress

## Status: ALL 9 WORK UNITS PUSHED (2026-11-07)

Verified after the last push: every branch has `origin/budget-trees-redesign`
(a4b5c66) as an ancestor, zero conflict markers in `Sources Tests docs`, CI green
(last one finishing), and every PR is `MERGEABLE`.

| Issue | PR | Branch | Worktree | Tests | CI | State |
|---|---|---|---|---|---|---|
| #76 | #78 | followup/issue-76 | idg-pr76 | 427→431 | green | MERGEABLE |
| #65 | #74 | codex/issue-65 | idg-pr74 | 434→444 | green | MERGEABLE |
| #66 | #75 | codex/issue-66 | idg-pr75 | 427→433 | green | MERGEABLE |
| #64 | #73 | codex/issue-64 | idg-pr73 | 427→433 | green | MERGEABLE |
| #63 | #72 | codex/issue-63 | idg-pr72 | 428→433 | green | MERGEABLE |
| #62 | #71 | codex/issue-62 | idg-pr71 | 427→441 | green | MERGEABLE |
| #60 | #69 | codex/issue-60 | idg-pr69 | 429→434 | green | MERGEABLE |
| #59 | #68 | codex/issue-59 | idg-pr68 | 429 | green | MERGEABLE |
| #58 | #67 | codex/issue-58 | idg-pr67 | 427→432 | green | MERGEABLE |

The `gatekeeper:changes` labels on eight PRs are STALE — they are round-1 labels
from before these fixes. The gate has not re-reviewed because its infrastructure
is down. #78 never got a label because its first gate run failed outright.

Not tied to an open issue: PR #77 (docs policy), PR #57 (factory bootstrap,
CLEAN — the owner could merge that one independently).

### What every PR now carries

- The blocking finding fixed by extracting the decision to a pure, injectable
  seam (`CaptureFit`, `ShareTextCollector`, `SpendTimeline`, `WidgetReload`,
  `OpeningAction`, `EntryRowActions`, `WidgetSnapshotTotals`,
  `AccessoryWidgetRoute`, `CategoryEntity`/`EntryPersistence` injectables).
- A test that was SEEN failing when the helper was broken, then passing.
- Base merged in with both `docs/decisions.md` entries kept.
- `xcodegen generate` clean, `xcodebuild test` green, six-heading PR body with
  `Closes #n` and real command output in `## Proof of work`.
- Model named as `DeepSeek V4.1 Flash (opencode-go/deepseek-v4.1-flash)`.

Each worker: extract the decision to a pure, injectable seam in
`Sources/TapLog/Shared` or `Theme`, unit-test it, prove the test fails when the
helper is broken, merge base (keeping both `docs/decisions.md` entries), run the
verify command, push with a six-heading body and `Closes #n`.

### Resource note

Two concurrent builds drove load to 80 and swap to 2369 MB of 3072 MB (≥ the 2 GB
line in `~/.config/agent-shared/LEARNINGS.md`). Owner was notified. Work now runs
ONE worker at a time; swap stayed pinned at 2369 MB while load fell to 3 and free
memory rose to 62 %, so a single sequential build is within the rule's intent.

## Rules in force

- Owner's main checkout `/Users/amteshwar/FlowyProjects/ideadump` is DIRTY and 37
  commits behind. Read-only. Every task runs in its own `idg-*` worktree.
- Workers: DeepSeek V4.1 Flash (`opencode-go/deepseek-v4.1-flash`), per owner
  instruction. Repo AGENTS.md names `gpt-5.6-luna`; the gate has raised that as a
  nit before, not a blocker. PR bodies name the model actually used.
- Never edit `.github/`. Never merge. Never force-push. Never write a token
  anywhere. Max 600 source lines / 20 source files per PR (tests+docs excluded).

## Blockers

1. pr-gatekeeper token (above) — owner action required.
