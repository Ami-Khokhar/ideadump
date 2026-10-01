// TapLog MCP server for ChatGPT and Codex.
//
// Stateless by design, because TapLog's promise is that spending data lives on
// the phone. This server keeps nothing: no database, no files, no logs of what
// it was sent. A recap is computed from the export the person chose to share,
// returned, and dropped. Log links hand the entry back to the phone, where the
// person taps Log themselves.

import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { z } from "zod";
import { parseTapLogCSV } from "./csv.js";
import { buildRecap } from "./recap.js";
import { buildLogLink } from "./loglink.js";
import { recapSummaryText } from "./summary.js";

const WIDGET_URI = "ui://taplog/recap-v1.html";
const WIDGET_MIME = "text/html;profile=mcp-app";
const MAX_FILE_BYTES = 5 * 1024 * 1024;
const FETCH_TIMEOUT_MS = 10_000;

const widgetHtml = readFileSync(fileURLToPath(new URL("../public/recap-widget.html", import.meta.url)), "utf8");

const INSTRUCTIONS = `TapLog is a local-first iPhone expense logger. The person's data lives on their phone; this server stores nothing.
Use show_weekly_recap when the person shares a TapLog CSV export (Settings → Export in the app) and wants to know where their money went.
Use prepare_log_links when the person tells you about purchases they want to record in TapLog. The links open TapLog's capture form pre-filled; nothing is saved until the person taps Log on their phone. Never say an expense was logged or saved.
Describe spending as facts, not verdicts. Impulse share covers only entries the person marked; say how much was unmarked instead of guessing.`;

const fileSchema = z.object({
  download_url: z.string(),
  file_id: z.string(),
  mime_type: z.string().optional(),
  file_name: z.string().optional(),
});

async function readSharedFile(file) {
  let url;
  try {
    url = new URL(file.download_url);
  } catch {
    throw new Error("The file link is not a valid URL.");
  }
  if (url.protocol !== "https:") throw new Error("The file link must use HTTPS.");

  const response = await fetch(url, { signal: AbortSignal.timeout(FETCH_TIMEOUT_MS), redirect: "follow" });
  if (!response.ok) throw new Error(`Could not download the file (HTTP ${response.status}).`);
  const declared = Number(response.headers.get("content-length") ?? 0);
  if (declared > MAX_FILE_BYTES) throw new Error("The file is larger than 5 MB, which is not a TapLog export.");
  const buffer = await response.arrayBuffer();
  if (buffer.byteLength > MAX_FILE_BYTES) throw new Error("The file is larger than 5 MB, which is not a TapLog export.");
  return new TextDecoder("utf-8").decode(buffer);
}

function errorResult(message) {
  return { isError: true, content: [{ type: "text", text: message }] };
}

export function createTapLogServer({ readFile = readSharedFile } = {}) {
  const server = new McpServer({ name: "taplog", version: "0.1.0" }, { instructions: INSTRUCTIONS });

  server.registerResource(
    "taplog-recap-widget",
    WIDGET_URI,
    { title: "TapLog recap", mimeType: WIDGET_MIME },
    async () => ({
      contents: [
        {
          uri: WIDGET_URI,
          mimeType: WIDGET_MIME,
          text: widgetHtml,
          _meta: {
            ui: {
              prefersBorder: true,
              // The widget needs no network: everything arrives in the tool result.
              csp: { connectDomains: [], resourceDomains: [] },
            },
            "openai/widgetDescription":
              "Shows a TapLog weekly recap or a set of pre-filled TapLog capture links. The model does not need to repeat the numbers it shows.",
          },
        },
      ],
    })
  );

  server.registerTool(
    "show_weekly_recap",
    {
      title: "Show TapLog weekly recap",
      description:
        "Use this when the person shares a TapLog CSV export and asks where their money went, how this week compares with last week, or how much was impulse spending. Reads the export once, returns the recap, and stores nothing. Pass the uploaded file as `file`, or the CSV text as `csv_text` when no file is available.",
      inputSchema: {
        file: fileSchema.optional().describe("The TapLog export the person uploaded (taplog-export.csv)."),
        csv_text: z.string().max(MAX_FILE_BYTES).optional().describe("The export's text, only when no file is available."),
        time_zone: z
          .string()
          .default("UTC")
          .describe("The person's IANA time zone, e.g. Asia/Kolkata. Decides which day a late-night purchase fell on."),
        week_starts_on: z
          .enum(["sunday", "monday", "saturday"])
          .default("sunday")
          .describe("First day of the week on the person's phone. Sunday for India and the US, Monday for most of Europe."),
        as_of: z
          .string()
          .optional()
          .describe("ISO date to recap the week of. Omit to use the newest entry in the export."),
        currency: z
          .string()
          .regex(/^[A-Z]{3}$/)
          .optional()
          .describe("ISO 4217 code for display, e.g. INR. The export has no currency column, so omit it when unknown."),
      },
      annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },
      _meta: {
        ui: { resourceUri: WIDGET_URI },
        "openai/fileParams": ["file"],
        "openai/toolInvocation/invoking": "Reading your TapLog export",
        "openai/toolInvocation/invoked": "Recap ready",
      },
    },
    async ({ file, csv_text, time_zone, week_starts_on, as_of, currency }) => {
      let text;
      try {
        if (file) text = await readFile(file);
        else if (csv_text) text = csv_text;
        else return errorResult("No export was provided. Ask the person to share taplog-export.csv from TapLog → Settings → Export.");
      } catch (error) {
        return errorResult(error.message);
      }

      let asOf;
      if (as_of) {
        // A bare date means the end of that day, so the whole day is in the recap.
        asOf = new Date(/^\d{4}-\d{2}-\d{2}$/.test(as_of) ? `${as_of}T23:59:59.999Z` : as_of);
        if (Number.isNaN(asOf.getTime())) return errorResult(`"${as_of}" is not a date.`);
      }

      try {
        const { entries, skipped } = parseTapLogCSV(text);
        const recap = buildRecap(entries, { timeZone: time_zone, weekStartsOn: week_starts_on, asOf });
        const structuredContent = {
          kind: "recap",
          currency: currency ?? null,
          skippedRows: skipped.slice(0, 20),
          skippedCount: skipped.length,
          recap,
        };
        return {
          structuredContent,
          content: [{ type: "text", text: recapSummaryText(structuredContent) }],
        };
      } catch (error) {
        return errorResult(error.message);
      }
    }
  );

  server.registerTool(
    "prepare_log_links",
    {
      title: "Prepare TapLog log links",
      description:
        "Use this when the person describes purchases they want to record in TapLog, e.g. \"log 40 for chai and 250 lunch\". Returns taplog:// links that open the capture form pre-filled on their iPhone. Nothing is saved until they tap Log in the app, so never say the expense was logged. Amounts must be plain numbers with at most two decimals.",
      inputSchema: {
        expenses: z
          .array(
            z.object({
              amount: z.union([z.string(), z.number()]).describe("Plain amount, e.g. 40 or 12.50. No currency symbol or thousands separator."),
              category: z.string().optional().describe("Category name as the person said it, e.g. Chai. TapLog matches it to their own list."),
              note: z.string().optional().describe("Short optional note, e.g. the merchant."),
            })
          )
          .min(1)
          .max(10),
      },
      annotations: { readOnlyHint: true, destructiveHint: false, openWorldHint: false, idempotentHint: true },
      _meta: {
        ui: { resourceUri: WIDGET_URI },
        "openai/toolInvocation/invoking": "Preparing TapLog links",
        "openai/toolInvocation/invoked": "Links ready — tap to log",
      },
    },
    async ({ expenses }) => {
      const results = expenses.map((expense) => buildLogLink(expense));
      const failed = results.filter((r) => !r.ok);
      const links = results.filter((r) => r.ok);
      const lines = links.map(
        (l) => `- [${l.amount}${l.category ? ` · ${l.category}` : ""}${l.note ? ` · ${l.note}` : ""}](${l.url})`
      );
      const text = [
        links.length
          ? `Tap a link on your iPhone to open TapLog with the entry filled in, then tap Log. Nothing is saved until you do.\n${lines.join("\n")}`
          : "No links could be prepared.",
        ...failed.map((f) => `Not prepared: ${f.error}`),
      ].join("\n");
      return {
        structuredContent: { kind: "links", links, errors: failed.map((f) => f.error) },
        content: [{ type: "text", text }],
        ...(links.length === 0 ? { isError: true } : {}),
      };
    }
  );

  return server;
}

const MCP_PATH = "/mcp";

export function startHttpServer(port = Number(process.env.PORT ?? 8787)) {
  const httpServer = createServer(async (req, res) => {
    const url = new URL(req.url ?? "/", `http://${req.headers.host ?? "localhost"}`);

    if (req.method === "OPTIONS" && url.pathname === MCP_PATH) {
      res.writeHead(204, {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, GET, DELETE, OPTIONS",
        "Access-Control-Allow-Headers": "content-type, mcp-session-id, mcp-protocol-version",
        "Access-Control-Expose-Headers": "Mcp-Session-Id",
      });
      res.end();
      return;
    }
    if (req.method === "GET" && url.pathname === "/") {
      res.writeHead(200, { "content-type": "text/plain" }).end("TapLog MCP server");
      return;
    }
    if (url.pathname === MCP_PATH && ["POST", "GET", "DELETE"].includes(req.method)) {
      res.setHeader("Access-Control-Allow-Origin", "*");
      res.setHeader("Access-Control-Expose-Headers", "Mcp-Session-Id");
      const server = createTapLogServer();
      const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined, enableJsonResponse: true });
      res.on("close", () => {
        transport.close();
        server.close();
      });
      try {
        await server.connect(transport);
        await transport.handleRequest(req, res);
      } catch {
        // Deliberately no request body in the log: it can hold spending data.
        console.error("MCP request failed");
        if (!res.headersSent) res.writeHead(500).end("Internal server error");
      }
      return;
    }
    res.writeHead(404).end("Not Found");
  });
  return new Promise((resolve) => httpServer.listen(port, () => resolve(httpServer)));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const httpServer = await startHttpServer();
  console.log(`TapLog MCP server listening on http://localhost:${httpServer.address().port}${MCP_PATH}`);
}
