# Export prompts

Six questions to ask an assistant about a TapLog export. They are written for the
CSV that `CSVExporter` produces, so they work with any assistant that can read an
attached file.

## Before you paste

- Export from TapLog and attach the `.csv`. Nothing is uploaded by TapLog; the
  assistant sees only the file you hand it.
- Columns are `Date,Amount,Category,Note,Archived,Intent`. There is no currency
  column: the amounts are in the app's current currency.
- Pending share-sheet captures are not exported. Archived entries are, marked
  `yes`. A `Note` or `Category` that begins with `=`, `+`, `-` or `@` (ignoring
  leading spaces and control characters) has an apostrophe added in front so a
  spreadsheet reads it as text; the apostrophe is not part of what was typed.
- Every prompt below asks for the row count it used. An answer without a count is
  not checkable, and a number you cannot check is worse than no answer.
- These six prompts have not yet been run against a real export on a device; they
  are written against the export's column contract and the tests that pin it.

## 1. Where did my money go last month?

Columns read: `Date`, `Amount`, `Category`. Archived rows are included.

```
Attached is my expense export (Date, Amount, Category, Note, Archived, Intent).
Using only rows whose Date falls inside last calendar month, give me the total per
Category, largest first, with each category's share of the month's total. State the
number of rows used and the exact date range covered. If a row's date is outside the
range, say how many you excluded. Do not estimate or fill gaps.
```

Answers: the monthly split and the base it came from.

Must not: add categories that have no rows, convert currency, or reason from the
notes about rows it did not use.

## 2. Which category changed most between two months?

Columns read: `Date`, `Amount`, `Category`. Archived rows are included.

```
Compare the two most recent complete calendar months in the attached export.
For each Category, report the total and the row count in each month, then the
difference in amount. Rank by absolute difference. State both date ranges and the
row count used. If either month has fewer than five rows, say so before ranking.
```

Answers: what moved, and whether the move rests on enough rows to mean anything.

Must not: describe a percentage change without the underlying amounts and counts.

## 3. What are my ten biggest expenses this year?

Columns read: `Date`, `Amount`, `Category`, `Note`. Archived rows are included.

```
From the attached export, list the ten largest Amount values in the current
calendar year, each with its Date, Category, and Note. State the total spent, the
number of rows used, and the date range covered. If two rows tie at the tenth
place, list both and say so.
```

Answers: the outliers, which are usually the ones people forget.

Must not: invent a merchant from a note, or merge two rows into one expense.

## 4. Is anything here a duplicate?

Columns read: `Date`, `Amount` to find the groups; every column of a matching row
is echoed back. Archived rows are included.

```
Find rows in the attached export that share both the same Date and the same Amount.
List each group with all its columns and say how many rows are in it. Do not decide
which one is the mistake and do not delete or merge anything. If there are more than
twenty groups, list the twenty largest and give the total group count.
```

Answers: accidental double logs.

Must not: call two rows duplicates on amount alone across different dates; the
date and amount must both match.

## 5. How did spending per day look over the last 14 days?

Columns read: `Date`, `Amount`. Archived rows are included.

```
Using the attached export, show a daily total for each of the last 14 calendar days,
including days with no rows as zero. State the first and last date covered and the
number of rows used. Mark any day whose total is more than twice the median daily
total.
```

Answers: the shape of a fortnight, including the quiet days.

Must not: drop empty days, or extend the range past the last row in the file.

## 6. Which notes mention the same shop, spelled differently?

Columns read: `Note`, plus `Amount` for the totals. Archived rows are included.

```
Search the Note column of the attached export for repeated place or merchant names,
including spelling variants and case differences. Do a plain text search, not a
pattern. For each candidate, list the spellings, the row count for each, and the
total amount. If a note is empty, ignore it. State the total number of rows scanned.
```

Answers: whether one shop is recorded under several names.

Must not: treat a category name as a merchant, or report a variant it cannot quote
from a row.

## What to do with the answers

- If the split in prompt 1 or the ranking in prompt 2 surprises you, check the
  categories on those rows in the app before believing the total.
- A duplicate group from prompt 4 is a candidate, not a fact. TapLog keeps both
  rows until you edit or delete one in the app.
- Nothing here writes to TapLog. `docs/decisions.md` records why: the export is
  read-only, the assistant gets a copy, and the phone stays the source of truth.
