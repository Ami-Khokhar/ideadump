import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { createTapLogServer, startHttpServer } from "../src/server.js";

const fixture = readFileSync(new URL("./fixtures/taplog-export.csv", import.meta.url), "utf8");

async function connect(options) {
  const server = createTapLogServer(options);
  const client = new Client({ name: "test", version: "0.0.0" });
  const [a, b] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(a), client.connect(b)]);
  return client;
}

test("lists both tools with UI and file metadata", async () => {
  const client = await connect();
  const { tools } = await client.listTools();
  const recap = tools.find((t) => t.name === "show_weekly_recap");
  const links = tools.find((t) => t.name === "prepare_log_links");
  assert.ok(recap && links);
  assert.equal(recap._meta.ui.resourceUri, "ui://taplog/recap-v1.html");
  assert.deepEqual(recap._meta["openai/fileParams"], ["file"]);
  assert.equal(recap.annotations.readOnlyHint, true);
  assert.ok(recap.inputSchema.properties.file.properties.download_url);
  assert.match(client.getInstructions(), /stores nothing/);
});

test("serves the widget as an MCP Apps resource", async () => {
  const client = await connect();
  const { contents } = await client.readResource({ uri: "ui://taplog/recap-v1.html" });
  assert.equal(contents[0].mimeType, "text/html;profile=mcp-app");
  assert.match(contents[0].text, /ui\/initialize/);
});

test("recap from an uploaded file", async () => {
  let seen;
  const client = await connect({
    readFile: async (file) => {
      seen = file;
      return fixture;
    },
  });
  const result = await client.callTool({
    name: "show_weekly_recap",
    arguments: {
      file: { download_url: "https://files.example/taplog-export.csv", file_id: "file_1" },
      time_zone: "Asia/Kolkata",
      currency: "INR",
    },
  });
  assert.equal(seen.file_id, "file_1");
  assert.ok(!result.isError);
  assert.equal(result.structuredContent.kind, "recap");
  assert.equal(result.structuredContent.recap.thisWeek.totalCents, 50550);
  assert.match(result.content[0].text, /₹505\.50/);
});

test("recap from pasted text, with an as_of date covering the whole day", async () => {
  const client = await connect();
  const result = await client.callTool({
    name: "show_weekly_recap",
    arguments: { csv_text: fixture, time_zone: "UTC", as_of: "2026-09-26" },
  });
  assert.equal(result.structuredContent.recap.thisWeek.start, "2026-09-20");
  assert.equal(result.structuredContent.recap.thisWeek.totalCents, 238900);
});

test("recap errors are readable, not crashes", async () => {
  const client = await connect();
  const none = await client.callTool({ name: "show_weekly_recap", arguments: {} });
  assert.equal(none.isError, true);
  assert.match(none.content[0].text, /Settings → Export/);

  const wrong = await client.callTool({ name: "show_weekly_recap", arguments: { csv_text: "a,b\n1,2" } });
  assert.equal(wrong.isError, true);
  assert.match(wrong.content[0].text, /not a TapLog export/);

  const zone = await client.callTool({ name: "show_weekly_recap", arguments: { csv_text: fixture, time_zone: "Nowhere/City" } });
  assert.equal(zone.isError, true);
});

test("the real file reader refuses non-HTTPS links", async () => {
  const client = await connect();
  const result = await client.callTool({
    name: "show_weekly_recap",
    arguments: { file: { download_url: "http://169.254.169.254/latest", file_id: "f" } },
  });
  assert.equal(result.isError, true);
  assert.match(result.content[0].text, /HTTPS/);
});

test("prepare_log_links returns links and keeps bad amounts out", async () => {
  const client = await connect();
  const result = await client.callTool({
    name: "prepare_log_links",
    arguments: {
      expenses: [
        { amount: 40, category: "Chai" },
        { amount: "1,200", category: "Rent" },
      ],
    },
  });
  assert.ok(!result.isError);
  assert.equal(result.structuredContent.links.length, 1);
  assert.equal(result.structuredContent.links[0].url, "taplog://log?amount=40&category=Chai");
  assert.equal(result.structuredContent.errors.length, 1);
  assert.match(result.content[0].text, /Nothing is saved until you do/);
  assert.doesNotMatch(result.content[0].text, /\blogged\b/i);
});

test("prepare_log_links with only bad amounts is an error", async () => {
  const client = await connect();
  const result = await client.callTool({
    name: "prepare_log_links",
    arguments: { expenses: [{ amount: "12.345" }] },
  });
  assert.equal(result.isError, true);
});

test("works over streamable HTTP, stateless", async () => {
  const http = await startHttpServer(0);
  try {
    const { port } = http.address();
    const health = await fetch(`http://localhost:${port}/`);
    assert.equal(await health.text(), "TapLog MCP server");

    const client = new Client({ name: "http-test", version: "0.0.0" });
    await client.connect(new StreamableHTTPClientTransport(new URL(`http://localhost:${port}/mcp`)));
    const result = await client.callTool({
      name: "prepare_log_links",
      arguments: { expenses: [{ amount: "250", category: "Lunch", note: "office canteen" }] },
    });
    assert.equal(result.structuredContent.links[0].url, "taplog://log?amount=250&category=Lunch&note=office%20canteen");
    await client.close();
  } finally {
    http.close();
  }
});
