import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { parseTapLogCSV, parseCSVRows, parseAmountCents } from "../src/csv.js";
import { buildRecap, intentBreakdown } from "../src/recap.js";
import { recapSummaryText } from "../src/summary.js";

const fixture = readFileSync(new URL("./fixtures/taplog-export.csv", import.meta.url), "utf8");

test("parses the export, including quotes, commas and newlines inside notes", () => {
  const { entries, skipped } = parseTapLogCSV(fixture);
  assert.equal(skipped.length, 0);
  assert.equal(entries.length, 10);
  assert.equal(entries[2].note, "BigBasket, weekly");
  assert.equal(entries[3].note, '"sale" hoodie');
  assert.equal(entries[7].note, "extra\nline");
  assert.equal(entries[7].cents, 4550);
  assert.equal(entries[1].intent, null, "unmarked stays its own state");
  assert.equal(entries[4].archived, true);
});

test("rejects a file that is not a TapLog export", () => {
  assert.throws(() => parseTapLogCSV("date,amount\n2026-01-01,5\n"), /not a TapLog export/);
  assert.throws(() => parseTapLogCSV("   "), /empty/);
});

test("reports unreadable rows instead of repairing them", () => {
  const csv = [
    "Date,Amount,Category,Note,Archived,Intent",
    '2026-09-01T10:00:00Z,"1,200","Rent","",no,unmarked', // grouping mark: ambiguous
    '2026-09-01T10:00:00Z,12.345,"Chai","",no,unmarked', // three decimals
    'yesterday,40,"Chai","",no,unmarked',
    '2026-09-01T10:00:00Z,40,"Chai","",maybe,unmarked',
    '2026-09-01T10:00:00Z,40,"Chai","",no,sometimes',
    '2026-09-01T10:00:00Z,40,"Chai"',
    '2026-09-01T10:00:00Z,40,"Chai","",no,impulse',
  ].join("\n");
  const { entries, skipped } = parseTapLogCSV(csv);
  assert.equal(entries.length, 1);
  assert.deepEqual(skipped.map((s) => s.line), [2, 3, 4, 5, 6, 7]);
});

test("strips the formula-guard apostrophe a newer export adds", () => {
  const csv = 'Date,Amount,Category,Note,Archived,Intent\n2026-09-01T10:00:00Z,40,"\'@Home","\'=SUM(A1)",no,unmarked\n';
  const [entry] = parseTapLogCSV(csv).entries;
  assert.equal(entry.category, "@Home");
  assert.equal(entry.note, "=SUM(A1)");
});

test("handles CRLF line endings and a BOM", () => {
  const rows = parseCSVRows('﻿Date,Amount\r\n"a",1\r\n');
  assert.deepEqual(rows, [["Date", "Amount"], ["a", "1"]]);
});

test("amount grammar matches the app's strict machine grammar", () => {
  assert.equal(parseAmountCents("12.5"), 1250);
  assert.equal(parseAmountCents("0"), null);
  assert.equal(parseAmountCents("12.345"), null);
  assert.equal(parseAmountCents("1,200"), null);
  assert.equal(parseAmountCents("999999999.99"), 99_999_999_999);
  assert.equal(parseAmountCents("1000000000"), null);
});

test("weekly recap in India time, Sunday-first", () => {
  const { entries } = parseTapLogCSV(fixture);
  const r = buildRecap(entries, { timeZone: "Asia/Kolkata", weekStartsOn: "sunday" });

  assert.equal(r.thisWeek.start, "2026-09-27");
  assert.equal(r.thisWeek.end, "2026-10-03");
  assert.equal(r.thisWeek.totalCents, 50550);
  assert.equal(r.lastWeek.totalCents, 238900);
  assert.equal(r.change.cents, -188350);
  assert.deepEqual(
    r.thisWeek.daily.map((d) => d.cents),
    [4000, 30000, 0, 4550, 12000, 0, 0],
    "00:15 IST on the 30th belongs to Wednesday, not Tuesday"
  );
  assert.equal(r.thisWeek.daily[4].isReferenceDay, true);
  assert.deepEqual(r.thisWeek.categories.map((c) => c.category), ["Food", "Transport", "Chai"]);
  assert.equal(r.thisWeek.categories.find((c) => c.category === "Chai").lastWeekCents, 4000);
  assert.deepEqual(r.droppedCategories.map((c) => c.category), ["Groceries", "Shopping", "Lunch"]);
  assert.equal(r.export.archivedCount, 2);
  assert.equal(r.export.totalCents, 50550 + 238900, "archived entries are never totalled");
});

test("the time zone decides the day of a late-night purchase", () => {
  const { entries } = parseTapLogCSV(fixture);
  const r = buildRecap(entries, { timeZone: "UTC", weekStartsOn: "sunday" });
  assert.deepEqual(r.thisWeek.daily.map((d) => d.cents), [4000, 30000, 4550, 12000, 0, 0, 0]);
});

test("Monday-first weeks move Sunday's chai into last week", () => {
  const { entries } = parseTapLogCSV(fixture);
  const r = buildRecap(entries, { timeZone: "Asia/Kolkata", weekStartsOn: "monday" });
  assert.equal(r.thisWeek.start, "2026-09-28");
  assert.equal(r.thisWeek.totalCents, 46550);
  assert.equal(r.lastWeek.totalCents, 238900);
  assert.equal(r.thisWeek.daily[0].weekday, "mon");
});

test("entries after the reference moment are not spent yet", () => {
  const { entries } = parseTapLogCSV(fixture);
  const r = buildRecap(entries, {
    timeZone: "Asia/Kolkata",
    asOf: new Date("2026-09-28T12:00:00Z"),
  });
  assert.equal(r.thisWeek.totalCents, 34000);
  assert.equal(r.thisWeek.entryCount, 2);
});

test("impulse share is over marked spend only, and never invented", () => {
  const { entries } = parseTapLogCSV(fixture);
  const r = buildRecap(entries, { timeZone: "Asia/Kolkata" });
  const i = r.thisWeek.intent;
  assert.equal(i.impulseCents, 30000);
  assert.equal(i.plannedCents, 16000);
  assert.equal(i.unmarkedCents, 4550);
  assert.equal(i.impulseShare, 30000 / 46000);
  assert.equal(i.markedCount, 3);
  assert.equal(i.entryCount, 4);
  assert.equal(r.change.impulseSharePoints, 23.2, "points, not a percentage of a percentage");

  const unmarkedOnly = intentBreakdown([{ cents: 500, intent: null }]);
  assert.equal(unmarkedOnly.impulseShare, null, "no marks means no read, not 0%");
  assert.equal(unmarkedOnly.coverage, 0);
  assert.equal(intentBreakdown([]).coverage, null);
});

test("no comparison when last week is empty", () => {
  const csv = 'Date,Amount,Category,Note,Archived,Intent\n2026-09-30T10:00:00Z,40,"Chai","",no,unmarked\n';
  const r = buildRecap(parseTapLogCSV(csv).entries, { timeZone: "UTC" });
  assert.equal(r.change.ratio, null);
  const text = recapSummaryText({ recap: r, currency: null, skippedCount: 0 });
  assert.match(text, /no comparison/);
  assert.match(text, /no impulse read/);
});

test("an export with only archived entries is empty, not zero spend", () => {
  const csv = 'Date,Amount,Category,Note,Archived,Intent\n2026-09-30T10:00:00Z,40,"Chai","",yes,unmarked\n';
  const r = buildRecap(parseTapLogCSV(csv).entries);
  assert.equal(r.empty, true);
  assert.equal(r.archivedCount, 1);
});

test("rejects unknown time zones and week starts", () => {
  assert.throws(() => buildRecap([], { timeZone: "Mars/Olympus" }), /Unknown time zone/);
  assert.throws(() => buildRecap([], { weekStartsOn: "someday" }), /weekday/);
});

test("summary text speaks in facts and names what shares cover", () => {
  const { entries } = parseTapLogCSV(fixture);
  const recap = buildRecap(entries, { timeZone: "Asia/Kolkata" });
  const text = recapSummaryText({ recap, currency: "INR", skippedCount: 0 });
  assert.match(text, /₹505\.50/);
  assert.match(text, /less than the week before \(79%\)/);
  assert.match(text, /65% of marked spend/);
  assert.match(text, /3 of 4 entries are marked/);
  assert.match(text, /23\.2 points higher/);
  assert.match(text, /2 archived entries are left out/);
});
