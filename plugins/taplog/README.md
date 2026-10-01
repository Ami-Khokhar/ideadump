# TapLog plugin for ChatGPT and Codex (v0.1)

A plugin in OpenAI's universal plugin format (skills + MCP server + MCP Apps UI),
built to keep TapLog's promise: **spending data lives on the phone.**

| Piece | What it does | Data it touches |
|---|---|---|
| `show_weekly_recap` tool + recap widget | Reads a TapLog CSV export the person shares, returns this week vs last, per-day bars, category split, and the impulse/planned read | The export, once, in memory. Nothing stored or logged |
| `prepare_log_links` tool + link cards | Turns "40 for chai, 250 lunch" into `taplog://log?...` links that open the capture form pre-filled | Only what the person typed. Nothing is saved until they tap **Log** on the phone |
| `skills/taplog-recap` | Workflow + voice rules: facts not verdicts, impulse share over marked spend only, points not percent-of-percent, archived never totalled | — |
| `skills/taplog-log` | Workflow for capture links: strict amounts, never claim "logged" | — |

The recap math mirrors `Sources/TapLog/Recap/RecapMath.swift` (future entries excluded,
unmarked kept apart, archived excluded) and the link builder mirrors
`CapturePrefill.machineAmount` (digits, ≤2 decimals, no grouping marks, ≤ 999,999,999.99).

## Layout

```
plugins/taplog/
├── plugin.json            portable Agent Plugins manifest + extensions.com.openai
├── mcp.json               remote MCP server (URL is a placeholder until deployed)
├── skills/
│   ├── taplog-recap/      SKILL.md + agents/openai.yaml (MCP dependency)
│   └── taplog-log/
└── server/                stateless Node MCP server (no build step)
    ├── src/server.js      tools, widget resource, HTTP transport (/mcp)
    ├── src/csv.js         RFC 4180 reader for the export format
    ├── src/recap.js       weekly recap math
    ├── src/loglink.js     taplog:// link builder
    ├── src/summary.js     model-readable recap text
    ├── public/recap-widget.html   MCP Apps widget (recap + link cards, light/dark)
    └── test/              node:test suite, 29 tests
```

The repo marketplace at `.agents/plugins/marketplace.json` exposes the plugin to the
ChatGPT desktop app / Codex for local testing.

## Run and test

```sh
cd plugins/taplog/server
npm install
npm test                 # 29 tests: parser, recap math, links, MCP over memory + HTTP
npm start                # http://localhost:8787/mcp
npx @modelcontextprotocol/inspector@latest   # Streamable HTTP → http://localhost:8787/mcp
```

## Try it in ChatGPT (developer mode)

1. `npm start`, then `ngrok http 8787` (or deploy; any Node 20+ host works).
2. ChatGPT → Settings → Security and login → **Developer mode** on.
3. chatgpt.com/plugins → **+** → paste `https://<tunnel>/mcp`.
4. New chat → **+** → More → TapLog. Upload `server/test/fixtures/taplog-export.csv`
   and ask "how did my week go? I'm in India".
5. For the full package (skills + server): replace the placeholder URL in `mcp.json`
   and both `agents/openai.yaml` files, then install from the local marketplace.

## Before public submission

- Deploy the server to a stable HTTPS URL and replace `taplog-mcp.example.com`.
- Add `privacyPolicyURL`, `websiteURL`, `logo`, `composerIcon` and screenshots to
  `plugin.json` (the App Store privacy policy can be reused once it is hosted).
- Check on a real iPhone that ChatGPT opens `taplog://` links (from the chat text
  and from the widget's `ui/open-link`). If it refuses custom schemes, add a
  universal link (`https://…/log?…`) to the app and switch the links to it.
