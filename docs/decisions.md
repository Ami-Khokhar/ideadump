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

## A delete-all retires the fallback history a migration preserved

- Context: issue #3. The split-store migration copies the Application Support
  fallback's history into the App Group store and deliberately preserves the
  source, so a failed copy can be retried. Delete-all only clears the active
  store. If the active store later fails to open, the candidate ordering rule
  promotes the fallback — which still holds the entries the user deleted, and
  the history comes back.
- Decision: immediately after a delete-all commits successfully, the app
  retires the fallback's records — deletes every entry and category in the
  Application Support store and removes its history marker. The retirement
  only runs when the app is not itself running on the fallback, and any
  failure (unopenable store, failed save) preserves every record and logs.
- Consequence: a user who deletes all history cannot have it resurrected by a
  store they can no longer see. The cost is that a retirement that races with
  an unfinished migration could drop the fallback's copy — which is why the
  call happens only after the active store's delete committed, and why a
  failed retirement keeps the source intact rather than deleting partially.
