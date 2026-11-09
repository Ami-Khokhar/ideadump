# Assistant access to TapLog data — spike research (#79)

Written 2026-11-09, 22:35 IST. Read-only research: no production code, no decision
committed to `docs/decisions.md` yet.

## Verdict

Do **Shape A** now (export pack: a compact Markdown summary plus a prompt pack).
Spend the real effort on the **Apple path** (App Intents + Foundation Models), not on
a server. Shape B got much cheaper than this issue assumed, but it is still gated
behind an OpenAI Platform organisation, so it is not a consumer feature. Shape C
stays out of scope: it is months of work and a privacy surface the App Store listing
currently promises does not exist.

## What the issue assumed, and what has changed

The issue was filed 2026-11-08 on the premise "ChatGPT's connectors are remote-only,
so a local server is unreachable". Both halves have moved.

| Fact | Evidence (read 2026-11-09 22:20–22:35 IST) |
|---|---|
| ChatGPT and Codex now share one **Plugins** directory. A custom MCP server is added at `chatgpt.com/plugins` by `Server URL` (or by tunnel), with auth `OAuth`, `None`, or both | `developers.openai.com/plugins/quickstart.md`, `/api/docs/guides/custom-mcp-server.md` |
| **Secure MCP Tunnel** connects a private (stdio or HTTP) MCP server on the user's own machine to ChatGPT with no inbound port and no public endpoint. Needs a Platform organisation, a `tunnel_id` and a runtime API key. Explicitly "does not support public plugin submission or distribution" | `/api/docs/guides/secure-mcp-tunnels.md` |
| Public distribution of an MCP-backed plugin needs a stable public HTTPS endpoint, verified developer or business identity, a ZIP, automated checks and review | `/plugins/deploy/submission.md` |
| Local stdio MCP plugins exist for desktop, but "Local MCP submissions are limited to approved partners… allowlisted" | `/plugins/deploy/desktop-only.md` |
| Adding a custom MCP server is a **web** action ("Access: use ChatGPT on the web") and stays subject to workspace policy and Lockdown | `/api/docs/guides/custom-mcp-server.md` |
| MCP spec version in force: `2026-07-28` | `modelcontextprotocol.io` |
| Apple's **App Intents** exist to make "content and actions discoverable by Apple Intelligence, and support Siri, Spotlight, Shortcuts, and widgets" | `developer.apple.com/documentation/appintents` |
| Apple's **Foundation Models** framework gives an app "models that specialize in language understanding, structured output, and tool calling", including the on-device and Private Cloud Compute models | `developer.apple.com/documentation/foundationmodels` |

## What TapLog already has

- One device, no account, no sync, no server. That is the pitch in
  `appstore/privacy-policy.html` and the metadata.
- Free CSV export by policy: `ProGate.canExportCSV` returns `true` on purpose, and
  `WeeklyRecapView` already shares a `CSVFile` through `ShareLink`. The export path is
  a file, not a network call, and `TemporaryExport` already owns its lifetime.
- A real Siri/Shortcuts surface: `LogExpenseIntent`, `QuickLogIntent`,
  `OpenCaptureIntent`, `CategoryEntity`, `TapLogShortcutsProvider`.
- Entry fields: date, amount, category, note, archived flag, intent. Categories carry
  a budget target and cadence, so "how am I doing against my food budget" is
  answerable from the same data.

## The three shapes, re-costed

| Shape | What the user does | What we build | Gate | Cost |
|---|---|---|---|---|
| **A. Export pack** | Shares a summary into ChatGPT, Claude, Gemini, or asks Siri with it | A Markdown summariser next to the CSV exporter, plus 6 documented prompts | none | ~1 PR, 1–2 days |
| **B. Self-hosted MCP bridge** | Runs `tunnel-client` plus an MCP server on a Mac, adds a custom MCP server in ChatGPT on the web | An MCP server over an exported file, read-only tools | their own Platform org, `tunnel_id`, API key; distribution to others needs a public HTTPS endpoint | 1–2 weeks, and only for people who already run a Platform org |
| **C. Hosted connector** | Signs in, links TapLog, ChatGPT queries it | Accounts, sync, hosting, OAuth, plugin submission, privacy surface | OpenAI review, App Store 5.1.2(i) consent | months, ongoing cost, new breach surface |
| **D. Apple path** (not in the issue) | Asks Siri, or uses an app feature that runs on-device | `AssistantEntity`/`AssistantIntent` over expenses and budgets, and a Foundation Models query path behind an availability check | iOS 26 for Foundation Models, iOS 18 for the newer Siri surfaces; TapLog targets iOS 17 | 1–2 PRs, no server, no new privacy promise |

D is the shape the issue's question 5 points at, and the numbers favour it: it needs
no account, no endpoint and no change to the privacy policy, and it is the only one
of the four that works with the phone alone in a lift.

## Answers to the spike's five questions

1. **Is this a real request?** Unknown, and the repo holds no evidence either way.
   Nothing measured in `reports/` or `research_notes/` speaks to it. The cheapest
   test is instrumented Shape A: count how many people share the assistant summary
   against how many open the recap. Below 1 % of exports over two weeks, drop it.
2. **Does Shape A alone satisfy it?** For read-only questions, mostly yes. A summary
   of totals by category, top merchants, month-on-month movement and budget position
   answers the questions people actually ask of spending data, and it costs no
   privacy surface. It does not answer arbitrary questions over individual rows,
   which is exactly what a model-side tool would add.
3. **Does Shape B survive OpenAI's connector requirements?** Yes, and better than
   assumed: a local stdio server plus Secure MCP Tunnel needs no public endpoint and
   no certificate. It still needs a Platform organisation, a tunnel, a runtime API
   key and a per-user setup on a computer. Distribution is the wall, not the protocol.
4. **What would Shape C's privacy labels and consent say?** The app would have to
   collect "Financial Info" and "Identifiers" as linked-to-you data, publish a
   processor and a retention period, add an in-app consent naming the recipient under
   App Store 5.1.2(i), and rewrite the "your records never leave your device" line on
   the product page. That is the whole differentiator sold in `appstore/metadata.md`.
5. **Is the same capability better spent on Siri / Apple Intelligence?** Yes for this
   product's audience: an iPhone-only app with no account. App Intents already expose
   logging; exposing read entities and a totals query is a smaller build than Shape B
   and reaches every user with no setup.

## Recommended next steps, cheapest first

1. **Shape A, one PR.** A `MarkdownSummary` exporter beside `CSVExporter` (same
   `CategoryLookup`, same archived/pending rules), one share entry point on the recap
   screen, six prompts in `docs/` to paste with it, a local counter so the next
   decision has evidence. No network, no privacy change.
2. **Spike D behind a flag.** Expense and budget entities plus a totals intent, so
   Shortcuts and Siri can answer "food spend this month". Verify on a device with an
   iOS 26 simulator for the Foundation Models path.
3. **Record the decision** in `docs/decisions.md`: A as the shipped shape, D as the
   next step, B documented as "possible for technical users, no distribution", C
   explicitly deferred with the conditions that would reopen it.

Shape B becomes worth revisiting if TapLog ever gains a Mac companion that owns the
data; today the store is on the phone and the tunnel would have to be fed by an
export anyway.

## Not verified

- No user signal, in either direction, on demand for asking an assistant about
  expenses. Everything above about priority is inference from the product's own
  constraints, not from users.
- The plugin pages were read as rendered documentation, not exercised: I did not add a
  custom MCP server, run `tunnel-client`, or submit anything.
- Apple's Foundation Models availability was read from the framework's documentation
  page, not tested against TapLog's iOS 17 deployment target or on a device.
