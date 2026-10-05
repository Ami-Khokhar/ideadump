# Decisions

## CSV export marks formula-leading text with an apostrophe

- Context: issue #2. A note or category name can arrive from another app's share
  sheet or a foreign `taplog://` link. A cell whose text opens with `=`, `+`, `-`
  or `@` is evaluated as a formula by Excel, Numbers, Sheets and LibreOffice,
  even when the CSV field is quoted.
- Decision: prefix such a field with a single apostrophe. The apostrophe goes
  inside the field's quotes, after any leading whitespace or C0/DEL control
  characters. The character is not stripped and the field is still RFC 4180
  quoted.
- Consequence: a consumer that is not a spreadsheet sees a literal leading
  apostrophe on formula-leading notes and category names. Any importer or
  support script that reads `taplog-export.csv` must account for it. Amounts
  are written unquoted and unchanged.
