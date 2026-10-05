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

## A delete-all clears the app-controlled copies of the history

- Context: issue #4. Deleting every entry clears the store, but the app holds
  other copies of the same history: a widget receipt still pending in the
  shared defaults, undo actions whose inverse operations would reinsert
  deleted rows, and the temporary `taplog-export.csv` a share hands to the
  system. Any of them can surface erased data after a successful delete-all.
- Decision: immediately after a delete-all commits successfully, both
  delete-all paths clear the widget receipt, empty the undo stack, and sweep
  the temporary export file. The export sweep is skipped while a transfer is
  active: `CSVFile` writes the file when a share starts and marks the transfer
  active, and the recap screen removes the file when it disappears — after a
  completed or a cancelled share — so an in-flight transfer is never deleted
  underneath.
- Consequence: a failed delete-all leaves every copy intact and recoverable,
  because the cleanup only runs after the store's save succeeds. External
  recipients of a shared export and user backups are outside deletion scope.

## A deep link prefills only from a known URL shape, with capped fields

- Context: issue #6. `taplog://log?...` arrives from a widget, a Control Center
  control, a Shortcut or another app. The amount was already validated as a
  strict machine number, but the note and category were unbounded, and a port,
  userinfo, path or fragment was accepted without meaning anything.
- Decision: the only supported shape is `taplog://log` (empty or `/` path, no
  port, no userinfo, no fragment) with the keys `amount`, `note` and
  `category`. An unknown key is ignored; a repeated key uses its first value;
  `note` is capped at 200 characters and `category` at 60. Any other component
  yields no prefill.
- Consequence: a link that a person hand-writes with extra components will stop
  pre-filling. A deep link still only pre-fills the capture form; it never
  saves an expense, so a bad link costs a manual tap, not a wrong record.
