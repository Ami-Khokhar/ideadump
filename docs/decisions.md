# Decisions

## Widget snapshots use fresh contexts from the cached shared-store container

- Context: issue #63. A widget process can be asked for a new timeline while its
  existing `ModelContext` still carries a stale view of data saved by the app.
  `StoreLocator`'s one-container cache is load-bearing because opening the same
  store again in the app process can crash Siri logging.
- Decision: each widget snapshot creates a fresh `ModelContext` from the cached
  container and reads only when that container is the shared App Group store.
  A missing shared store or a failed fetch produces an unavailable widget state,
  not a valid-looking zero. The read-to-totals mapping lives in
  `WidgetSnapshotTotals` so the failure state is covered by `TapLogTests`,
  which does not link the widget target; the shared-store rule is the pure
  `StoreLocator.isSharedStore`. A failed quick-button history read also renders
  the unavailable state instead of the hard-coded defaults. Diagnostics record
  shared-store read status and entry count, without recording a total or store
  path.
- Consequence: installations without a usable App Group can still use the app,
  while their widget says its data is unavailable instead of showing unrelated
  figures. WidgetKit refreshes remain best-effort, and the fresh-context behavior
  still needs physical-device verification across the app/widget process boundary.

## Share parsing distinguishes missing text from unreadable text

- Context: issue #65. A share with no extracted content and a nonempty share whose
  amount the parser declines both reached the same message, while Messages may
  provide its body as `attributedContentText` and attachment providers may return
  `Data` or `NSAttributedString` instead of `String`.
- Decision: prefer a nonempty attributed body as that item's text. When the body
  carries no amount, the item's text attachments still contribute after it,
  because a rich-link body can be a summary while the payment SMS sits in an
  attachment. Convert supported Foundation payloads to bounded strings, reserve a
  slot per attachment in source order so callback order cannot reorder the share,
  and drop slots whose payload was unsupported or empty. The collection policy
  lives in `ShareTextCollector` under `Sources/TapLog/Shared` so the test target
  can exercise it, and the extension only drives `NSItemProvider`. Retain whether
  the parser received meaningful text so the extension can show a distinct
  message for an empty share and an unreadable amount. Do not log shared content
  or its prefix because payment messages can include personal and financial
  details.
- Consequence: unsupported payloads and malformed UTF-8 still contribute no
  text; supported text remains subject to the existing per-piece, attachment
  count and total text limits, applied once across the ordered pieces. Verified
  at parser level only: the originally failing Messages share and a device run
  have not been confirmed, so a body that carries no amount can still fail to
  prefill.

## Capture fills its viewport when content fits and scrolls when it does not

- Context: issue #66. The capture content sat in a `ScrollView`, which proposes
  an unbounded height to its content. The amount spacers therefore stayed at
  their minimum lengths, leaving unused space after the category tiles on tall
  screens.
- Decision: lay the keypad and Log bar out as a sibling below the content and
  size a `ViewThatFits` against the height that is left — the container the
  system has already reduced by the status-bar and home-indicator insets, minus
  the 326pt `CaptureBottomBar.height`. The fit height may never be the screen
  height and may never be read from a `GeometryReader` wrapped around a
  `.safeAreaInset`. Measured on an iPhone 17 simulator, that reader reported a
  398pt frame while `safeAreaInsets.bottom` still carried the bar and the home
  indicator (360pt), so subtracting the insets again measured 0 and every screen
  scrolled. The pure `CaptureFit.visibleHeight`, `CaptureFit.contentMinHeight`
  and `CaptureFit.usesScroll` helpers hold the arithmetic and the decision, so it
  is unit-tested. The first candidate is the capture stack with a minimum height
  equal to the visible height, letting its spacers divide the leftover room; the
  fallback is a scroll view containing the same stack when its content does not
  fit. `ViewThatFits` re-measures the real stack, so an underestimated content
  minimum can only fall through to the scroll, never clip.
- Consequence: the tiles stay connected to the keypad on tall screens, while
  short screens and larger text retain access to the full category row by
  scrolling. A regression here — measuring the screen, or letting the bar's
  height drift from `CaptureBottomBar.height` — clips the tile row behind the
  opaque keypad with no scrolling available to reach it. The keypad and Log bar
  keep their dimensions and their own safe-area placement.
- Verification: `CaptureFitTests` pins the fit decision, the bar subtraction and
  the content minimum; the full test suite passed, and the screen was checked in
  a portrait iPhone 17 simulator (`scroll=false`, visible 398pt, tiles ending at
  the bar's top edge). Not verified: a physical device, the 4.7" scrolling path
  and accessibility Dynamic Type sizes — no such hardware or size was available
  in this environment.

## The spend widget rolls over at midnight and refreshes on likely opportunities

- Context: issue #62. The spend widget had one snapshot and requested a refresh
  every 15 minutes. That request exceeds a reasonable WidgetKit budget and does
  not guarantee a fixed cadence; the single snapshot also kept yesterday's total
  under the "Today" label after midnight. Currency changes and app foregrounding
  did not request a reload.
- Decision: each timeline contains the current day's snapshot and a zero-total,
  zero-count entry at the next calendar midnight. It requests another timeline
  after 30 minutes, or at midnight when that comes first. The app requests a
  widget reload when the currency changes and when it enters the foreground,
  but the foreground request is gated: `WidgetReload` records the log counter and
  currency the widget was last asked to render, and an activation asks again only
  when one of them has moved since. A plain foregrounding therefore spends no
  budget. Existing log, undo, edit and delete reloads remain in place.
- Consequence: WidgetKit can defer or drop both scheduled and explicit reloads,
  so neither the rolling cadence nor a log's appearance has a one-second or exact
  midnight guarantee. A log reload rebuilds the pending midnight entry. If that
  reload is deferred, an older zero-total reset can briefly hide logs recorded
  later that day after midnight. The app cannot read a new total at the boundary
  unless WidgetKit grants a timeline refresh. The activation gate compares two
  cheap values rather than the rendered total, so an edit that changes an amount
  without changing the log counter is caught by its own reload path, not by this
  one; if that reload was dropped, the activation gate will not notice.

## Lock Screen spend widgets use widget-level deep links and accessory backgrounds

- Context: issue #61. The circular Lock Screen widget attached its URL to an
  image, and the rectangular widget used `Link`; accessory widgets need a URL
  on the widget's content, and a Link-based rectangular label could render
  clipped or fail to route. The generic Home Screen fallback also allowed an
  unsupported family to inherit a layout that does not fit the Lock Screen.
- Decision: put `taplog://log` on each accessory content root, render the
  rectangular prompt as one compact icon-and-text row, and give both offered
  Lock Screen families `AccessoryWidgetBackground` through
  `containerBackground(for: .widget)`. Keep `.accessoryInline` out of
  `supportedFamilies`, but render it as one linked line if WidgetKit requests
  it; unsupported families render no Home Screen content.
- Consequence: both offered Lock Screen widgets route through the app's existing
  capture deep link and use the system's accessory background treatment. Adding
  another family later requires an explicit layout rather than silently
  reusing the small Home Screen view.

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
- Decision: consider at most `ShareParser.maxAttachments` attachments and cut
  each piece to `maxFieldLength` and the joined text to `maxTextLength` through
  `ShareParser.cutAtTokenBoundary`: a cut that lands on whitespace keeps the
  prefix unchanged, and a cut inside a token keeps that token's head and drops
  only its trailing digits, commas and dots. The parser input is capped the same
  way. A currency-anchored amount (`₹`, `$`, `Rs`, `INR`) always wins; when the
  text also looks like a one-time-code message, the symbol-less fallback is not
  used at all, so the amount is declined rather than guessed.
- Consequence: some symbol-less OTP-plus-payment messages no longer prefill an
  amount. The share sheet says it could not find one and the user enters it in
  the app. A token that straddles a cap keeps its head and loses its tail, so an
  amount in the lost tail is declined rather than read in fragments. Refusing is
  recoverable; silently filing the code — or a fragment of the amount — as
  spending is not.

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
  unused, so the manifests cannot drift ahead of the code either. XcodeGen must
  also keep copying one into each target: the same suite fails when the generated
  project stops doing so, and a new shipped target means adding it to the test's
  list.

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
