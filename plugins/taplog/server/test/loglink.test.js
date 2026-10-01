import { test } from "node:test";
import assert from "node:assert/strict";
import { buildLogLink, normaliseAmount } from "../src/loglink.js";

test("builds a capture link the app's CapturePrefill reads", () => {
  const r = buildLogLink({ amount: 40, category: "Chai", note: "Chaayos" });
  assert.equal(r.ok, true);
  assert.equal(r.url, "taplog://log?amount=40&category=Chai&note=Chaayos");
});

test("spaces travel as %20, never +, because URLComponents keeps + literal", () => {
  const r = buildLogLink({ amount: "12.50", category: "Eating out", note: "masala chai & samosa" });
  assert.equal(r.url, "taplog://log?amount=12.50&category=Eating%20out&note=masala%20chai%20%26%20samosa");
  assert.ok(!r.url.includes("+"));
});

test("omits empty optional fields", () => {
  assert.equal(buildLogLink({ amount: "99", category: "  ", note: "" }).url, "taplog://log?amount=99");
});

test("rejects amounts the app would silently drop", () => {
  for (const bad of ["1,200", "12.345", "0", "-5", "₹40", "abc", 1e21, Number.NaN, "1000000000"]) {
    const r = buildLogLink({ amount: bad });
    assert.equal(r.ok, false, `expected ${bad} to be rejected`);
  }
  assert.equal(normaliseAmount(12.5), "12.5");
  assert.equal(normaliseAmount(" 1200 "), "1200");
});

test("caps note and category length and collapses whitespace", () => {
  const r = buildLogLink({ amount: 5, category: "x".repeat(80), note: "a\n\nb   c" });
  assert.equal(r.category.length, 40);
  assert.equal(r.note, "a b c");
});
