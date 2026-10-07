# Decisions

## CSV export marks formula-leading text with an apostrophe

- Context: issue #2. A note or category name can arrive from another app's share
  sheet or a foreign `taplog://` link. A cell whose text opens with `=`, `+`, `-`
  or `@` is evaluated as a formula by Excel, Numbers, Sheets and LibreOffice,
  even when the CSV field is quoted.
- Decision: prefix such a field with a single apostrophe, written as the first
  character inside the field's quotes. The guard looks past any leading
  whitespace or C0/DEL control characters when deciding whether to add it, so
  ` =cmd` exports as the field `"' =cmd"` — apostrophe first, the original text
  after it. The character is not stripped and the field is still RFC 4180
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
  retires the fallback's history — deletes every entry, resets each category's
  usage count, and removes the history marker. Categories themselves stay,
  because a budget target, an emoji and a sort order are configuration rather
  than history, and the fallback is used whenever the ordering rule ranks it
  first: when there is no App Group store to open, when the pinned location is
  the fallback and its store file is still there, or when the fallback is the
  location that already holds history.
  The retirement only runs when the app is not itself running on the
  fallback, and any failure (unopenable store, failed save) preserves every
  record and logs.
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

## Share-sheet input is bounded, and an ambiguous amount is declined

- Context: issue #5. Shared text comes from another app and can be arbitrarily
  large or split across many attachments, and a one-time code beside a payment
  leaves two bare numbers the parser cannot tell apart. The old flow
  concatenated every attachment without a limit and took the first bare number,
  so an OTP could be filed as the payment.
- Decision: consider at most `ShareParser.maxAttachments` attachments, cut each
  piece to `maxFieldLength` and the joined text to `maxTextLength` at the last
  whitespace before the limit rather than at a raw offset, and cap the parser
  input the same way. A currency-anchored amount (`₹`, `$`, `Rs`, `INR`) always
  wins; when the text also looks like a one-time-code message, the symbol-less
  fallback is not used at all, so the amount is declined rather than guessed.
- Consequence: some symbol-less OTP-plus-payment messages no longer prefill an
  amount. The share sheet says it could not find one and the user enters it in
  the app. A share whose amount straddles the cap also yields no amount, because
  a partial number is never parsed. Refusing is recoverable; silently filing the
  code — or a fragment of the amount — as spending is not.

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

## Every shipped target bundles the same privacy manifest

- Context: issue #7. The required-reason API code in `Sources/TapLog/Shared`
  compiles into the widget and the share extension, but only the app target
  packaged a `PrivacyInfo.xcprivacy`, so an extension could ship without one.
- Decision: each target's source directory carries a `PrivacyInfo.xcprivacy` and
  XcodeGen packages it into that target's resources. All three declare
  `NSPrivacyAccessedAPICategoryUserDefaults` for `1C8F.1` (the App Group suite)
  and `CA92.1` (the process's own defaults), and nothing else: no code compiled
  into them uses file timestamps, disk space, system boot time or active
  keyboards.
- Consequence: a new required-reason API added to shared code must be declared in
  all three manifests. `PrivacyManifestTests` fails when a declared category is
  unused, so the manifests cannot drift ahead of the code either.

## The paywall retries a failed product load, and StoreKit stays the authority

- Context: issue #8. `ProStore.loadProduct()` ran once per paywall. If the App
  Store lookup failed, the price rendered as "—" on a disabled button with no
  way to ask again, and no test covered the loading or failure path.
- Decision: product loading has an explicit state (`idle`, `loading`, `loaded`,
  `unavailable`) and the paywall shows a labelled "Try again" control when it is
  `unavailable`. StoreKit remains the only entitlement authority: `isPro` is read
  from `Transaction.currentEntitlements` (expected product, no revocation) and is
  never persisted. The StoreKit boundary sits behind `ProStoreBackend`, so the
  loading, purchase and restore paths are tested with a scripted store. A load
  that already succeeded is left alone, so the price is fetched once per app run
  and a later failure cannot remove a price that was already shown.
- Consequence: retry only re-asks the App Store for the price; it never unlocks
  anything. Restoring and the whole free app stay available with no product
  loaded, and an unverified transaction still unlocks nothing.

## The privacy screen states current behavior and links no policy page

- Context: issue #9. Nowhere in the app explained what TapLog does with the
  user's records, exports and purchases, and no production policy URL has been
  approved for hosting.
- Decision: Settings gains a labelled Privacy destination whose content states
  what the app does today — records on the device, user-controlled export and
  backup, Apple handling payment and Siri requests, and what "Delete all entries"
  can and cannot reach. No URL, contact address or assurance is added, and the
  public policy link stays explicitly pending an owner-approved page.
- Consequence: adding the hosted policy page later is a one-line change in
  `PrivacyView`. `PrivacyViewTests` fails if a placeholder URL, an invented
  contact or a blanket assurance is introduced.

## A hosted policy page is more than a one-line change

- Context: follow-up issue #32. The entry above promised that adding the hosted
  privacy-policy page would be a one-line change in `PrivacyView`. It is not: the
  screen's copy is now data, and two content tests pin the pending state.
- Decision: supersede that consequence. Adding the page means replacing the
  "A public privacy policy" section in `PrivacyView.sections`, dropping or
  inverting the two tests that pin the pending state, and keeping the
  no-invented-contact and no-assurance assertions.
- Consequence: `PrivacyViewTests` still fails if a placeholder URL, an invented
  contact or a blanket assurance is introduced, so the replacement cannot quietly
  weaken the screen.
