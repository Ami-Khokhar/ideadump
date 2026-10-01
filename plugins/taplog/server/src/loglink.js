// Builds taplog://log links that open the app's capture form pre-filled
// (CapturePrefill.swift). A link never saves anything by itself: the person
// still taps Log on their phone, so the entry is created on the device only.

import { parseAmountCents } from "./csv.js";

const MAX_NOTE = 200;
const MAX_CATEGORY = 40;

/**
 * Normalises an amount to the strict grammar CapturePrefill.machineAmount
 * accepts: digits, at most one dot, at most two decimals, no grouping marks.
 * The app silently pre-fills nothing for anything else, so reject it here,
 * where the model can still ask the person what they meant.
 */
export function normaliseAmount(raw) {
  let text;
  if (typeof raw === "number") {
    if (!Number.isFinite(raw)) return null;
    // 12.5 → "12.5"; 12.345 is rejected below rather than rounded.
    text = String(raw);
    if (/e/i.test(text)) return null;
  } else {
    text = String(raw ?? "").trim();
  }
  return parseAmountCents(text) === null ? null : text;
}

/**
 * @returns {{ ok: true, url: string, amount: string, category: string|null, note: string|null }
 *          | { ok: false, error: string }}
 */
export function buildLogLink({ amount, category, note }) {
  const amountText = normaliseAmount(amount);
  if (amountText === null) {
    return {
      ok: false,
      error: `"${amount}" is not an amount TapLog accepts. Use digits with at most two decimals and no thousands separators, e.g. 1200 or 12.50.`,
    };
  }
  const cleanCategory = typeof category === "string" ? category.trim().slice(0, MAX_CATEGORY) : "";
  const cleanNote = typeof note === "string" ? note.trim().replace(/\s+/g, " ").slice(0, MAX_NOTE) : "";

  // encodeURIComponent, not URLSearchParams: Foundation's URLComponents does
  // not read "+" as a space, so "masala chai" must travel as "masala%20chai".
  const params = [`amount=${amountText}`];
  if (cleanCategory) params.push(`category=${encodeURIComponent(cleanCategory)}`);
  if (cleanNote) params.push(`note=${encodeURIComponent(cleanNote)}`);

  return {
    ok: true,
    url: `taplog://log?${params.join("&")}`,
    amount: amountText,
    category: cleanCategory || null,
    note: cleanNote || null,
  };
}
