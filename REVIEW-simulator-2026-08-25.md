# TapLog — hands-on simulator review (25 Aug 2026)

Driven manually in the iOS simulator (iPhone, 402×874 pt) against the current
working tree, seeded with `-seedSampleData`. Findings are ordered by severity.
Nothing here has been fixed — this is the punch list.

---

## 1. CRITICAL — the amount field only accepts one character per tap

**Symptom.** Tap the amount, type `4567` → the field shows `4` and loses focus.
Every subsequent digit needs a fresh tap on the field. The app's core promise
("Type the amount, tap Log", capture in ~5 s) does not work by typing.

**Evidence.**
- Tap the field: caret blinks, placeholder `0` shown. Send `4`,`5`,`6`,`7` with
  500 ms between keystrokes → result is `4`, and the caret is gone in a 6-frame /
  1.5 s screenshot burst, i.e. the field has resigned first responder.
- **Not a regression.** Built HEAD (`40a30ed`) in a throwaway `git worktree`,
  installed, reproduced identically. The uncommitted `AmountTextField` rework did
  not introduce it.
- **Not a harness artifact.** Launched Safari in the *same* simulator, tapped the
  address bar, sent the *identical* keystroke sequence → Safari received all four
  digits. The defect is in the app.

**Ruled out.** `AmountInputFilter` is fine: for `""` + `4` then `"4"` + `5`,
`filterEdit` returns `restoresPrevious == false` and `candidate == result.text`,
so `shouldApplyEditNatively` returns `true` and UIKit should apply the edit
natively. `maxDisplayLength` is 15, so it is not a length rejection.

**Where to look.** The field resigns first responder after the first accepted
edit. Two prime suspects, both of which fire on *every* keystroke:

- `Sources/TapLog/Capture/AmountTextField.swift:41` — `updateUIView` rewrites
  `font`, `minimumFontSize`, `textColor`, `tintColor`, `accessibilityValue` on
  every text change, then calls `syncFocus`. `syncFocus` (line 166) hops through
  `DispatchQueue.main.async`; combined with the async `textFieldDidBeginEditing` /
  `textFieldDidEndEditing` bounces (lines 76–88) there is a plausible ordering
  where a stale `isFocused == false` read triggers `resignFirstResponder()`.
- `Sources/TapLog/Theme/Theme.swift` — `AmountFont.fontSize(for:)` and
  `AmountLayout` recompute the field's `.frame(width:height:)` on every keystroke
  (56 pt → 34 pt as digits are added). A frame/identity change on the
  `UIViewRepresentable` can tear down and rebuild the `UITextField`, which drops
  first responder.

**Suggested approach.** Add a UI test that types three digits and asserts the
field text before touching the implementation. Then (a) make `updateUIView`
idempotent — only assign properties that actually changed — and (b) make the
focus sync synchronous/one-shot rather than a `DispatchQueue.main.async`
round-trip that can race the delegate callbacks.

**Why it shipped unnoticed:** the deep-link / prefill path sets the text
programmatically and works perfectly (see §6), so any testing done through
`taplog://log?amount=…` or the Shortcut looks healthy.

---

## 2. HIGH — the Recap weekly chart is shifted by a day for Sunday-first locales

**Symptom.** Today is Tuesday. The chart highlights the bar under **T**… but that
bar holds Monday's money, a bar appears under **W** (a future day), and Sunday's
₹45 is drawn under **M**. Every bar is off by one and "today" is highlighted on
the wrong day.

**Root cause.** Two of the three pieces disagree about which day starts the week:

- `Sources/TapLog/Recap/RecapMath.swift:27` — `dailyTotals` indexes from
  `calendar.dateInterval(of: .weekOfYear, for: now)!.start`, which honours the
  **locale's `firstWeekday`** (Sunday in en_US, en_IN, ja, pt_BR, …).
- `Sources/TapLog/Recap/RecapMath.swift:48` — `todayIndex` hardcodes
  **Monday-first**: `(calendar.component(.weekday, from: now) + 5) % 7`.
- `Sources/TapLog/Recap/WeeklyRecapView.swift:273` — `dayLetter` hardcodes
  **Monday-first** labels `["M","T","W","T","F","S","S"]`.

The app formats in ₹, so India is clearly in scope — and India's default
`firstWeekday` is Sunday. This is wrong for a large share of the target users.

**Fix.** Pick one convention and derive all three from it. Cheapest correct
version: keep `dateInterval(of: .weekOfYear)` as the source of truth and compute
both the index and the labels from `calendar.firstWeekday` (labels via
`calendar.veryShortWeekdaySymbols` rotated by `firstWeekday - 1`, which also
localises them for free).

**Test.** `RecapMath` is pure and already testable — add cases pinning a
`Calendar` with `firstWeekday = 1` and `firstWeekday = 2`.

---

## 3. HIGH — the four category tiles reshuffle non-deterministically

**Symptom.** The quick-tap tile row changed order four times in one session with
essentially no data change: `Food Chai Shopping Health` → `Chai Food Shopping
Bills` → `Chai Food Shopping Transport` → `Chai Food Shopping Bills`. In an app
whose whole value is a sub-5-second tap, tiles that move destroy muscle memory
and cause mis-tags.

**Root cause.** `Sources/TapLog/Shared/TimeBucket.swift:112-124`. The candidate
list comes from `globalCounts.keys` — an **unordered** `Dictionary` — and the
comparator only breaks ties on `score`, then on `globalCounts[key]`. When
`bucketCounts` is empty the score *is* derived purely from `globalCounts`, so the
second tie-break is always equal too. With ties unresolved, `sorted` (which is not
guaranteed stable) returns whatever order the hash table yielded. The same flaw
exists in `globalTopCategories` at line 153.

**Confirmed against the seed data.** Counts are chai 3, food 3, shopping 2,
transport 1, fun 1, bills 1, health 1. Every seeded entry lands in bucket 0
(00:00, plus one at 02:00); at 21:50 the current bucket is 7, so `bucketCounts` is
empty and scores collapse to `gc/12*3`: **chai and food tie at 0.75** and
**transport/fun/bills/health all tie at 0.25** for the 4th slot. That is exactly
the observed churn — slots 1–2 swapping and slot 4 rotating among four categories.

**Fix.** Add a deterministic final tie-break to both sorts — e.g. `SpendCategory`
display order, then `key` — so equal-scoring categories always render in the same
positions.

---

## 4. HIGH — the capture screen clips the tiles and note field under the Log button

**Symptom.** On first load the category tile labels (Chai / Food / Shopping /
… / Other) and the "Note (optional)" field sit *underneath* the Log button, while
roughly 700 pt of empty space sits in the middle of the screen. You have to
scroll a screen that looks like it has nothing to scroll.

**Root cause.** `Sources/TapLog/Capture/LogHomeView.swift:164-181`. The
`GeometryReader` (line 165) is *outside* the `.safeAreaInset(edge: .bottom)`
(line 178), so `geometry.size.height` is the full screen height. That value is
then applied as `.frame(minHeight: geometry.size.height, alignment: .top)`
(line 176) to content inside a `ScrollView` whose visible region is *shorter* by
the Log button's height. The content is forced taller than the viewport by exactly
the inset, pushing the bottom rows out of view.

**Fix.** Move the `GeometryReader` inside the inset (or read the height from the
scroll content's own proxy) so `minHeight` reflects the reduced viewport. Worth
also revisiting the large mid-screen `Spacer`s once the height is correct.

---

## 5. MEDIUM — the undo toast covers the Log button for 5 seconds

**Symptom.** After logging, the toast lands exactly on the Log button and blocks
it for the full 5-second window. Logging two purchases back to back means either
waiting for the toast or tapping through a button that isn't there — and the tap
target that *is* there, on the right, is **Undo**.

**Root cause.** `Sources/TapLog/ContentView.swift:219` places the toast with
`.overlay(alignment: .bottom)` and `UndoToast` uses `.padding(.bottom, 8)`
(`Sources/TapLog/List/UndoToast.swift:31`) — the identical edge and padding as
`logButton` in `LogHomeView`'s `.safeAreaInset(edge: .bottom)`. Guaranteed
overlap. Duration is 5 s (`Sources/TapLog/Undo/UndoStack.swift:34`).

**Fix.** Float the toast above the Log button rather than over it (add the button
height to the toast's bottom padding), or shorten the window, or dismiss the toast
on the next interaction.

---

## 6. LOW — `TileGrid.swift` is dead code

`grep -rn "TileGrid" Sources/ Tests/` finds zero references outside the file
itself; `LogHomeView` defines its own private `tileRow` / `tileButton` / `otherTile`.
It was nonetheless edited in the current uncommitted working tree, so effort is
going into code that never renders. Delete it or wire it up.

---

## 7. LOW — a deep link with an unknown category silently keeps the old selection

`taplog://log?amount=12.50&note=coffee&category=Coffee` prefilled the amount and
note correctly but, since no `Coffee` category exists, left the previously
selected `Chai` tile active with no indication anything was ignored. A Shortcut
built around a category name that was later renamed would silently mis-tag every
entry. Consider falling back to the fallback category, or surfacing that the
requested category was not found.

---

## Verified working (no action needed)

- **Deep-link / prefill** — `taplog://log?amount=…&note=…` fills the amount, note
  and Log button state correctly and logs cleanly. (This is why §1 is invisible in
  intent-driven testing.)
- **Log → total → undo** — logged ₹99.00, header went ₹12.50 → ₹111.50, tapped
  Undo, header returned to ₹12.50. Correct. (An earlier apparent undo failure was
  my own tap arriving after the 5 s window, not a bug.)
- **Debug seed button** — the 🔨 in History is correctly wrapped in
  `#if DEBUG` (`Sources/TapLog/List/EntryListView.swift:136-140` for the toolbar
  item, `:187` for `debugMenu`) and will not ship.
- **Timestamps** — History's "9:48 PM" matches the host clock; the simulator status
  bar just hides the AM/PM suffix.

## Cosmetic note

History renders as a stock SwiftUI `List` (white rows, system separators) against
the home screen's custom warm-cream minimal aesthetic. It reads like a different
app. Low priority, but it is the first screen a user opens after logging.

## Not yet exercised

Settings, "Faster ways to log", the "Other" category picker / `CategoryManageView`,
swipe-to-delete in History, the widget, and the share extension.
