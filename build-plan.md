# TapLog — Build Plan (Agent-Assisted)

Target: a working prototype of TapLog on a real iPhone, ~1 week of focused full-time
effort with one AI coding agent (Claude Code or Codex) doing the code generation, and
a human running the Xcode build/test loop.

## Status — all milestones built + zen UI (Aug 18, 2026)

### Zen UI redesign (approved & shipped)
- **Capture-first home** — the Log tab is the default; hero amount field, category
  chips, pill Log button, Recent strip. History is one tab away (no more "+" button).
- **Warm-neutral theme** — `Theme.swift` design system: paper `#F7F5F2` / near-black
  `#121110`, sage accent `#6B8F71`, hairline dividers, rounded monospaced numerals.
- **3 tabs** — Log (default) / History / Recap; undo toast moved to app root so it
  works from any tab; onboarding state machine moved to ContentView.
- **4-beat onboarding** — Welcome → first log on the home screen → "your categories"
  (in-use guard) → front doors. Deep links still skip the welcome.
- **Verified** — pixel-sampled the simulator screenshots: exact theme hexes in both
  modes, sage pill enables only with a valid amount (deep-link prefill), history rows
  and recap bars render; 11 unit tests pass.

## Status — all milestones built (Aug 16, 2026)

- ✅ **M0 Scaffold** — XcodeGen project, SwiftData in the App Group container, 3 targets.
- ✅ **M1 Core loop** — capture form (≤3 taps), entry list, swipe actions, 5-second undo
  toast.
- ✅ **M2 Deep link + AppIntents** — `taplog://log?amount=&note=&category=` route +
  "Log Expense" Siri/Shortcuts intent.
- ✅ **M3 Widget** — today's spend/count on the home screen, tap-to-log, App Group
  shared store.
- ✅ **M4 Share sheet** — parses bank-SMS text into a pending entry, confirm/discard
  in-app.
- ✅ **M5 Recap + CSV** — weekly recap vs. prior week, CSV export via ShareLink, both
  behind a non-functional Pro lock.
- ✅ **M6 (agent portion)** — debug seed/clear menu, haptics on save. Device signing,
  Action Button, and TestFlight remain human tasks (see M6 below).
- ✅ **Custom categories** (post-M6, user-requested) — no fixed list: categories are
  user-managed SwiftData records with add + swipe-delete, defaults (Food, Transport,
  Rent, …) seeded only on first launch, and dynamic name/emoji resolution everywhere
  (list, recap, CSV, intents, deep link).

**Verified on the iOS 26.5 simulator (iPhone 17 Pro):** `xcodebuild` builds all three
scheme targets clean; app installs, launches, seeds 12 sample entries into
`group.com.example.taplog/TapLog.store`, and both extensions are embedded in the
`.app` bundle. Screenshots: `docs/taplog-launch.png`, `docs/taplog-list.png`.

**Verified in the simulator:** the existing store migrated (new `ZSPENDCATEGORY` table)
and seeded 9 default categories with entries untouched; the capture form renders the
user's categories.

**Toolchain notes from the actual build:** the machine's Xcode 26.x SDK removed
`ModelContainer.newBackgroundContext()` and renamed some Transferable APIs, and
WidgetKit's `TimelineProvider` declares an associated type named `Entry` that shadows
the SwiftData model inside provider structs — the widget fetches via a free `@MainActor`
function instead. Keep this in mind for any future widget code.

**Prototype scope (in order of priority):**

1. Capture an expense in ≤5 seconds (form + Action Button + widget + Siri + share sheet)
2. See and fix entries (list, swipe-to-edit/archive, undo toast)
3. Weekly recap (spend by category, vs. prior week)
4. CSV export

**Out of prototype scope:** accounts, cloud sync, bank notification automation (bonus
path, built last), App Store submission, onboarding polish, localization, iCloud sync.

---

## Operating rules (read first — applies to every milestone)

1. **One agent per milestone.** Never run two agents on the same Xcode project
   simultaneously. `.pbxproj` conflicts and overlapping file edits will eat all gains.
2. **XcodeGen, always.** The project is generated from `project.yml`. After adding any
   file or target, regenerate with `xcodegen generate` and commit the regenerated
   `.xcodeproj` so it never goes stale. Never hand-edit `.pbxproj`.
3. **Regenerate before building.** Build loop: `xcodegen generate` → build → fix →
   repeat. This is the one command agents must run before every build.
4. **Stable APIs only.** The spec below uses iOS 17-era APIs (SwiftUI, SwiftData,
   AppIntents, WidgetKit) that are well represented in agent training data. If an agent
   reaches for something newer, push it back to the stable version. Pin the project to
   Swift 5 language mode (not Swift 6 strict concurrency) to avoid concurrency errors in
   generated code.
5. **One feature per milestone, verified before moving on.** A milestone is done only
   when it builds cleanly *and* passes its acceptance criteria on the simulator (and on
   a device where noted).
6. **Commit after every green milestone.** The working tree should always be buildable.
7. **Keep the capture form identical everywhere.** Every entry point lands on the same
   deep link / AppIntent. One capture form, infinite front doors.
8. **Never block a milestone on the bank-notification automation.** It depends on the
   user's device Shortcuts and varies by bank. Prototype the confirmation-tap flow with
   manual entries; treat notification capture as a stretch goal.

---

## Environment setup (before milestone 0)

- Xcode: pin a stable version (e.g. Xcode 16.x). Do not chase the newest beta SDK.
- Install XcodeGen: `brew install xcodegen`
- Create the repo: `git init` in the project folder.
- Register an App Group `group.com.example.taplog` in the Apple Developer portal
  (free account is fine for device testing) and a bundle ID `com.example.taplog`.
  Replace `com.example` with the real reverse-domain in `project.yml`.
- Simulator for daily iteration; a physical iPhone for Action Button + widget testing.

---

## Milestone 0 — Scaffold (half day)

**Goal:** a compiling, empty TapLog app with SwiftData wired up, generated by XcodeGen.

**Agent context to provide:** this build plan, plus the pitch's product section.

**Files to create:**

- `project.yml` — targets: `TapLog` (iOS app, min iOS 17.0, Swift 5 mode), plus
  placeholder entries for `TapLogWidget` (widget extension) and `TapLogShare` (share
  extension) to be enabled in later milestones. Set `GENERATE_INFOPLIST_FILE: YES` with
  `INFOPLIST_KEY_` settings where possible.
- `TapLog/TapLogApp.swift` — `@main` app struct; creates a `ModelContainer` whose store
  lives in the **App Group container** (`FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.taplog")`), so the widget and share
  extension can read the same data later. Do this now to avoid a data-migration problem
  in Milestone 3.
- `TapLog/Models/Entry.swift` — SwiftData `@Model`:

  ```swift
  @Model final class Entry {
      var amount: Decimal
      var category: String        // key into a fixed category list for the prototype
      var note: String?
      var date: Date
      var isArchived: Bool
      var createdAt: Date
  }
  ```

- `TapLog/Models/CategoryList.swift` — a fixed, ordered list of categories with emoji +
  display name (Coffee, Food, Transport, Shopping, Bills, Fun, Health, Other). Custom
  categories are v2; do not build them yet.
- `TapLog/ContentView.swift` — placeholder root view.

**Acceptance criteria:**

- `xcodegen generate` produces `TapLog.xcodeproj` with no warnings.
- App builds and launches in the simulator: `xcodebuild -project TapLog.xcodeproj
  -scheme TapLog -destination 'platform=iOS Simulator,name=iPhone 16' build`.
- Launching the app creates an empty SwiftData store inside the App Group container
  (verify with a print of the store URL in the console).
- `git init` done; clean first commit.

**Agent prompt (template):**

> Set up a fresh iOS app project for TapLog using XcodeGen. Create project.yml with an
> app target named TapLog, iOS 17.0 deployment target, Swift 5 language mode, and an
> Info.plist generated from build settings. Add a SwiftData model Entry with
> amount/category/note/date/isArchived/createdAt, with the ModelContainer store placed
> in the App Group container group.com.example.taplog. Add a fixed category list.
> Then run `xcodegen generate` and build for the iPhone simulator to confirm it
> compiles and launches.

---

## Milestone 1 — Core loop: capture, list, undo (day 1)

**Goal:** the product's beating heart — log an expense in under five seconds, see it
instantly, undo it. Everything else hangs off this.

**Files to create:**

- `TapLog/Capture/CaptureForm.swift` — the single capture form: amount (numeric
  keypad, pre-focused), category picker (defaulted to the last-used category), optional
  note. **Three taps max to log**: amount → category → Save. Save must not require
  scrolling or extra taps (category defaults sensibly).
- `TapLog/Capture/CaptureFlow.swift` — a `NavigationStack`-based sheet (or full-screen
  cover) that presents the form and inserts the `Entry` into the `ModelContext`.
- `TapLog/List/EntryListView.swift` — the home screen: today's and recent entries via
  `@Query` sorted by date desc. Swipe-to-archive (with an archived section off to the
  side or a filter), swipe-to-delete, tap-to-edit (reopens the form pre-filled).
- `TapLog/List/UndoToast.swift` — after every insert/edit/archive, a toast —
  "Logged $12 · coffee — Undo" — live for 5 seconds; Undo rolls back the last operation.
- `TapLog/Capture/LastUsedCategory.swift` — persist the last-used category in
  `@AppStorage` so the next capture defaults to it.

**Acceptance criteria:**

- From a fresh launch, logging $12.50 under Coffee and hitting Save shows the entry in
  the list immediately (no refresh gesture).
- The undo toast appears for 5 seconds; tapping Undo removes the entry and shows the
  form/list state consistent with the rollback.
- Editing an entry updates it in place; archiving moves it out of the main list.
- The form is reachable and dismissable, and Save works from the first tap after the
  amount is typed (keyboard stays out of the way of the Save button).
- Builds clean; commit.

**Agent prompt (template):**

> Build the core capture loop for TapLog on top of the scaffold. Create a capture form
> with amount (pre-focused numeric field), a category picker defaulting to the last-used
> category, and an optional note; saving inserts an Entry via SwiftData. Build the home
> screen entry list sorted newest-first with swipe-to-edit, swipe-to-archive, and
> swipe-to-delete. Add a 5-second undo toast after every mutation with a working Undo
> that rolls back the operation. Use @AppStorage for the last-used category. Make sure
> logging an expense takes at most three taps. Run `xcodegen generate` and build for the
> iPhone simulator to verify.

---

## Milestone 2 — Deep link + AppIntents: Action Button, Siri, Shortcuts (day 1–2)

**Goal:** capture from anywhere. This is the differentiation; everything in the pitch
hangs off "≤5 seconds, from anywhere."

**Files to create:**

- `TapLog/DeepLink/LogURL.swift` — URL scheme `taplog://` with a `log` route:
  `taplog://log?amount=12.50&note=coffee&category=Coffee`. Handle it in the app via
  `.onOpenURL` (or `UIApplicationDelegate` `openURL` if needed), pre-filling the form
  and opening it automatically.
- `TapLog/AppIntents/LogExpenseIntent.swift` — an `AppIntent` named "Log Expense" with
  parameters: amount (required, `Double`), note (optional, `String`), category
  (optional). It inserts an `Entry` and returns a success result describing what was
  logged. This is what Siri ("Log twelve on coffee") and Shortcuts call.
- Info.plist entries (via `project.yml` build settings): `CFBundleURLTypes` for the
  `taplog` scheme.

**Acceptance criteria:**

- In the simulator, `xcrun simctl openurl booted "taplog://log?amount=12.50&note=coffee"`
  opens the app with the form pre-filled and ready to save.
- In Shortcuts on a simulator/device, the "Log Expense" action appears under the app's
  actions; running it with amount 12 and note "coffee" creates an entry visible in the
  list.
- In Siri (device), "Log twelve on coffee" creates the entry.
- On a real iPhone, the Action Button is configured (Settings → Action Button →
  Shortcut) to call "Log Expense" and creates an entry from the lock screen.
- Builds clean; commit.

**Agent prompt (template):**

> Add external capture entry points to TapLog. Register a `taplog` URL scheme with a
> `taplog://log?amount=&note=&category=` route that pre-fills and opens the capture form
> via onOpenURL. Add an AppIntent "Log Expense" with amount (required double), note
> (optional), and category (optional) parameters that inserts an Entry and returns a
> success result. Verify with `xcrun simctl openurl` and by building to the simulator.
> Run `xcodegen generate` first.

---

## Milestone 3 — Widget (day 3)

**Goal:** one-tap capture from the home / lock screen — the second front door.

**Files to create:**

- `TapLogWidget/TapLogWidgetBundle.swift` — `WidgetBundle` with the main widget.
- `TapLogWidget/SpendWidget.swift` — a `StaticConfiguration` (or `AppIntentConfiguration`
  if agent can verify it) reading today's spend and count from the **shared SwiftData
  store in the App Group** via the same `ModelContainer` setup. Widget shows "Today:
  $42.50 · 5 logs". Tapping it opens `taplog://log` (widget URL / AppIntent openApp).
- `project.yml` — enable the `TapLogWidget` target with `NSExtension` point
  `com.apple.widgetkit-extension`, App Group entitlement on both targets.
- Shared container helper: `TapLog/Shared/StoreLocator.swift` — one function returning
  the ModelContainer configured with the App Group store URL, used by app, widget, and
  later the share extension.

**Acceptance criteria:**

- Widget appears in the widget gallery; shows today's spend and count that update when
  entries change (add a widget-reload call in the app after saves, plus `timeline` /
  refresh on relevant triggers).
- Tapping the widget opens the app's capture form.
- Data read from the widget matches the app list (proves App Group sharing).
- Builds clean for both targets; commit.

**Agent prompt (template):**

> Add a home-screen widget to TapLog. Create a WidgetKit extension target named
> TapLogWidget via project.yml. The widget shows today's total spend and entry count
> read from the existing App Group SwiftData store (factor the ModelContainer creation
> into a shared helper used by both app and widget). Tapping the widget opens the app's
> capture form. After entries change, tell the widget to reload. Enable the App Group
> entitlement on both targets. Verify the widget renders on the simulator and shows data
> matching the app.

---

## Milestone 4 — Share sheet (day 3–4)

**Goal:** share a bank SMS or receipt text straight into a pre-filled form — the third
front door and the foundation for notification capture.

**Files to create:**

- `TapLogShare/ShareViewController.swift` (share extension, `com.apple.share-services`
  point) — receives text, extracts a plausible amount (`$12`, `12.50`) and merchant
  from the text with a small regex heuristics file, and writes a **pending entry** to
  the shared store (`isArchived: false`, `pending: true` flag or a `pendingEntries`
  collection) so the user confirms it in the app.
- `TapLog/List/PendingReviewView.swift` — a badge on the home list: "2 pending from
  share sheet — review" with one-tap confirm/archive per pending entry.
- `project.yml` — enable the `TapLogShare` target with the App Group entitlement.

**Acceptance criteria:**

- Sharing a text like "CHASE: You spent $12.50 at Starbucks" via the share sheet lands
  a pending entry visible in the app with a review badge.
- Confirming the pending entry turns it into a normal entry; discarding removes it.
- Parser handles `$12.50`, `12.50`, "spent 12", and fails gracefully (falls back to
  empty amount the user fills in).
- Builds clean; commit.

**Agent prompt (template):**

> Add a share extension to TapLog so users can share a bank payment SMS into the app.
> Create a TapLogShare target in project.yml. The extension parses an amount and
> merchant out of the shared text with simple heuristics, writes a pending entry into
> the shared App Group store, and the app shows a "pending review" badge on the entry
> list where the user confirms or discards. Handle malformed input gracefully. Verify
> by building both targets to the simulator.

---

## Milestone 5 — Weekly recap + CSV export (day 4–5)

**Goal:** the habit payoff — the data rewards the user weekly; plus an escape hatch.

**Files to create:**

- `TapLog/Recap/WeeklyRecapView.swift` — sums non-archived entries per category for the
  current week vs. the previous week; simple bar/summary list (Swift Charts is fine, or
  plain SwiftUI rows for the prototype). Framed as "clean up your week": the same data
  as the dashboard.
- `TapLog/Export/CSVExport.swift` — one-tap CSV export of all non-archived entries via
  `ShareLink` / `UIActivityViewController`.
- Paywall stubs: Pro-only features (recap, export) show a "Pro" lock with a static
  "coming soon" purchase sheet — **do not wire real purchases** in the prototype.

**Acceptance criteria:**

- Recap shows this week vs. last week by category with correct totals for a handful of
  seeded entries.
- CSV export produces a shareable file with headers and correct rows; it opens in
  Numbers.
- Pro-locked features render the lock state and nothing crashes when tapped.
- Builds clean; commit.

**Agent prompt (template):**

> Add the weekly recap and CSV export to TapLog. Build a weekly recap view summing
> non-archived entries per category for the current week and comparing against the
> previous week. Add a one-tap CSV export of all non-archived entries presented through
> ShareLink. Gate recap and export behind a non-functional "Pro" lock screen. Verify on
> the simulator with seeded entries.

---

## Milestone 6 — Device testing + polish (day 5–7)

**Goal:** the prototype is demonstrable on a real iPhone with every front door working.

**To do (human-heavy, agents can't do these):**

- Code-signing for the app, widget, and share targets on a physical device.
- Test every entry point on hardware: Action Button, lock-screen widget, Siri,
  share sheet, deep link from Shortcuts.
- Install on a second phone and confirm local-first behavior (data never leaves the
  device — check no network calls in the console).
- Time the core loop: **capture in ≤5 seconds** from each front door; fix anything
  slower.
- Final QA pass of Milestone 1–5 acceptance criteria on device.
- TestFlight distribution (requires a paid Apple Developer account) for beta feedback.

**Agent prompt (template):**

> Do a prototype-hardening pass: add a debug "seed sample data" button, fix any SwiftUI
> layout issues on small screens, and add simple haptics on successful capture. Keep
> everything stable-API.

---

## After the prototype

- **30-day retention test** with a small beta group (10–20 people) via TestFlight —
  the metric that validates the thesis is day-30 logging retention.
- Then, in order: real purchase flow (StoreKit 2), custom categories, Google Sheet
  export, iCloud sync, bank-notification automation (Shortcuts template users install),
  and only then App Store submission. The pitch's 90-day v1 clock starts at prototype
  sign-off, not at kickoff.

---

## Risk table

| Risk | Mitigation |
|---|---|
| Agent reaches for bleeding-edge SDK APIs | Pin Xcode 16.x, iOS 17 target, Swift 5 mode; reject new APIs in review |
| `.pbxproj` merge conflicts | XcodeGen; one agent per milestone; commit regenerated project |
| Widget/extension can't read app data | App Group store configured in Milestone 0, before extensions exist |
| Build errors eat agent time | Regenerate with `xcodegen generate` before every build; keep a human in the build loop |
| Share-sheet parsing is fragile | Confirmation step in-app; graceful fallback to manual entry |
| Bank notification formats vary | Deferred to post-prototype; confirmation-tap flow is the real product |
| Two agents editing the same tree | One agent per milestone, strictly |
