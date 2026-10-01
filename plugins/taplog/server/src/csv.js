// Reads the CSV that TapLog's Settings → Export writes (CSVExporter.swift):
//
//   Date,Amount,Category,Note,Archived,Intent
//   2026-09-30T08:12:00Z,40,"Chai","",no,unmarked
//
// Nothing here guesses. A row that does not match the export's grammar is
// reported back as a skipped line, never repaired into a number nobody logged.

export const EXPECTED_HEADER = ["Date", "Amount", "Category", "Note", "Archived", "Intent"];

/** Upper bound the app itself enforces (Money.maxAmount). */
const MAX_CENTS = 99_999_999_999n;

/** RFC 4180: quoted fields, doubled quotes, commas and newlines inside quotes. */
export function parseCSVRows(text) {
  const rows = [];
  let row = [];
  let field = "";
  let inQuotes = false;
  let i = 0;
  // A BOM at the start is an editor artifact, not part of the "Date" header.
  if (text.charCodeAt(0) === 0xfeff) i = 1;

  for (; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field += c;
      }
    } else if (c === '"') {
      inQuotes = true;
    } else if (c === ",") {
      row.push(field);
      field = "";
    } else if (c === "\n" || c === "\r") {
      if (c === "\r" && text[i + 1] === "\n") i++;
      row.push(field);
      rows.push(row);
      row = [];
      field = "";
    } else {
      field += c;
    }
  }
  if (field !== "" || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows;
}

/**
 * Strict amount grammar, the same one the app applies to machine-supplied
 * amounts (CapturePrefill.machineAmount): digits, at most one dot, at most two
 * decimals, above zero, within the app's limit. Returns integer cents or null.
 */
export function parseAmountCents(raw) {
  const text = String(raw ?? "").trim();
  const match = /^(\d+)(?:\.(\d{1,2}))?$/.exec(text);
  if (!match) return null;
  const cents = BigInt(match[1]) * 100n + BigInt((match[2] ?? "").padEnd(2, "0"));
  if (cents <= 0n || cents > MAX_CENTS) return null;
  return Number(cents);
}

/**
 * A newer export build prefixes an apostrophe to a text cell that opens with
 * = + - or @, so spreadsheets read it as text rather than a formula. That
 * apostrophe is an export artifact, not something the user typed.
 */
function unguardText(value) {
  return /^'[=+\-@]/.test(value) ? value.slice(1) : value;
}

/**
 * Parses a TapLog export into entries. Returns `{ entries, skipped }`, where
 * `skipped` lists `{ line, reason }` for every row that could not be read.
 * Throws only when the file is not a TapLog export at all.
 */
export function parseTapLogCSV(text) {
  if (typeof text !== "string" || text.trim() === "") {
    throw new Error("The file is empty.");
  }
  const rows = parseCSVRows(text);
  const header = rows[0].map((h) => h.trim());
  const isTapLog = EXPECTED_HEADER.every((name, idx) => header[idx] === name);
  if (!isTapLog) {
    throw new Error(
      `This is not a TapLog export. Expected the header "${EXPECTED_HEADER.join(",")}", found "${rows[0].join(",")}".`
    );
  }

  const entries = [];
  const skipped = [];
  for (let r = 1; r < rows.length; r++) {
    const cells = rows[r];
    const line = r + 1;
    if (cells.length === 1 && cells[0].trim() === "") continue; // trailing newline
    if (cells.length !== EXPECTED_HEADER.length) {
      skipped.push({ line, reason: `expected 6 columns, found ${cells.length}` });
      continue;
    }
    const [dateRaw, amountRaw, categoryRaw, noteRaw, archivedRaw, intentRaw] = cells;

    const date = new Date(dateRaw.trim());
    if (Number.isNaN(date.getTime())) {
      skipped.push({ line, reason: `unreadable date "${dateRaw}"` });
      continue;
    }
    const cents = parseAmountCents(amountRaw);
    if (cents === null) {
      skipped.push({ line, reason: `unreadable amount "${amountRaw}"` });
      continue;
    }
    const archived = archivedRaw.trim().toLowerCase();
    if (archived !== "yes" && archived !== "no") {
      skipped.push({ line, reason: `unreadable archived flag "${archivedRaw}"` });
      continue;
    }
    // "unmarked" is a real answer, kept apart from both impulse and planned.
    const intentText = intentRaw.trim().toLowerCase();
    if (!["impulse", "planned", "unmarked", ""].includes(intentText)) {
      skipped.push({ line, reason: `unreadable intent "${intentRaw}"` });
      continue;
    }

    const category = unguardText(categoryRaw).trim() || "Other";
    const note = unguardText(noteRaw).trim();
    entries.push({
      date,
      cents,
      category,
      note: note === "" ? null : note,
      archived: archived === "yes",
      intent: intentText === "impulse" || intentText === "planned" ? intentText : null,
    });
  }
  return { entries, skipped };
}
