# TapLog physical-device QA sheet

Short sheet for one TestFlight build. Simulator evidence does not count for any line here.
Written 12 October 2026 IST.

## Record this first

| Field | Value |
|---|---|
| Build (version/build) | |
| Revision hash | |
| Device + iOS version | |
| Date and time started (IST) | |
| Tester | |
| Sandbox Apple Account used | yes / no |

Tick **Pass**, **Fail** or **N/A** and put the defect in the Notes column. Any Fail blocks
the checklist line until it is fixed and re-run.

## Before starting

- Install the TestFlight build (not an Xcode run) so the StoreKit environment is Apple's.
- Sign in to a Sandbox Apple Account in Settings → App Store → Sandbox Account.
- Delete any previous install if the line says "fresh install".
- Have bank-style text in the clipboard for the share-sheet line, and a category-free text
  (an OTP message) for its negative case.

## 1. Core capture and persistence

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 1.1 | Fresh install, first launch | Welcome screen; "Skip for now" works; no compulsory setup | | |
| 1.2 | First log: amount → category → Log | One entry appears, undo toast shows | | |
| 1.3 | Force-quit immediately after logging, relaunch | Entry is still in History | | |
| 1.4 | Log from the keypad 5 times quickly | Five distinct entries, no duplicates | | |
| 1.5 | Delete all entries, then force-quit and relaunch | History stays empty | | |

## 2. Siri

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 2.1 | "Hey Siri, log an expense in TapLog" | Siri asks amount, category, then optional note; saves headless | | |
| 2.2 | "Hey Siri, log chai in TapLog" (a real category) | Category prefilled, amount asked | | |
| 2.3 | "Hey Siri, open capture in TapLog" | App opens on the focused keypad, no splash | | |
| 2.4 | Cancel the Siri dialog | Nothing is saved; no error screen | | |
| 2.5 | Repeat 2.1 twice in a row | Two entries, one per invocation | | |
| 2.6 | Lock the phone, then run 2.1 | Saves while locked (or refuses with a spoken message, never a crash) | | |

## 3. Action Button (iPhone 15 Pro and later)

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 3.1 | Settings → Action Button → Shortcut → TapLog → "Log Expense" | Shortcut assigned without extra setup | | |
| 3.2 | Hold the Action Button, speak an amount | Headless save; app never opens | | |
| 3.3 | Reassign to "Open Expense Capture", hold again | App opens on the keypad | | |
| 3.4 | Time one capture from button hold to saved entry | Record seconds and whether the app was cold | | |

The review notes describe both shortcuts, matching what the app registers
(`TapLogShortcutsProvider`).

## 4. Widgets

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 4.1 | Add small, medium and large Home widgets | All render; total matches History | | |
| 4.2 | Tap a suggestion on the widget | One durable save, no app launch | | |
| 4.3 | Tap the same suggestion twice quickly | Two entries, never a lost or doubled one | | |
| 4.4 | Open the app within 10 minutes | Undo toast for the widget save; undo removes it | | |
| 4.5 | Add circular and rectangular Lock Screen widgets | They render; tapping opens the right screen | | |
| 4.6 | Lock the device and tap a widget | Route works after unlock; no blank screen | | |
| 4.7 | Control Center (iOS 18+) | "Log expense" control is available and runs | | |
| 4.8 | Delete a category used by a widget suggestion, then refresh | Widget updates; no crash | | |

## 5. Share sheet

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 5.1 | Share "You spent $12.50 at Starbucks" from Notes | "Saved $12.50 … confirm it in the app", pending entry in History | | |
| 5.2 | Confirm that pending entry in History | Becomes a real entry; totals include it once | | |
| 5.3 | Share an OTP-only message ("Your OTP is 482910") | Refuses to invent an amount | | |
| 5.4 | Share text with no number at all | Same refusal message | | |
| 5.5 | Share a long bank message (> 4,000 characters) | No hang or crash; parses or declines cleanly | | |
| 5.6 | After 5.1, check the app's total | Share writes land in the same store the app reads (no split store) | | |

## 6. Persistence and storage

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 6.1 | Log from the share sheet while the app is in the foreground | App's History updates | | |
| 6.2 | Widget save while the app is open | App's History updates | | |
| 6.3 | Upgrade from the previous build (prior schema) | Existing entries survive, unmarked where they always were | | |
| 6.4 | Upgrade from a build without the App Group (fallback store) | History appears once, not duplicated | | |
| 6.5 | Fill the device near capacity, then log | A clear save failure, never a silent loss | | |
| 6.6 | Delete All, then reinstall the earlier fallback-era build | Deleted entries do not come back (see the checklist caveat if they do) | | |

## 7. Export

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 7.1 | Recap → Export CSV with no Pro entitlement | Export is available free | | |
| 7.2 | Open the file in Numbers and in Excel | Rows and columns intact, dates and notes readable | | |
| 7.3 | Check the file for archived rows and pending rows | Archived included; pending absent | | |
| 7.4 | Check the Currency column | One code on every row; matches Settings | | |
| 7.5 | Log a note starting with `=`, `+`, `-` or `@`, export, open | Cell is text, not a formula | | |
| 7.6 | Export twice quickly from two entry points | Two distinct files, each matching its own data | | |

## 8. Purchase and restore (Sandbox only)

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 8.1 | Open the paywall (Recap → Month, or Budgets → + with 3 budgets) | Real price from Apple's storefront, not "—" | | |
| 8.2 | Complete the purchase | Pro unlocks; paywall dismisses itself | | |
| 8.3 | Cancel a purchase | No message blaming the user; Pro stays locked | | |
| 8.4 | Purchase with a Sandbox account set to Ask to Buy | "Waiting for approval" notice; unlock after approval | | |
| 8.5 | Turn on Airplane Mode, open the paywall | Honest unavailable message with Try again; no dead button | | |
| 8.6 | Delete the app, reinstall from TestFlight, Settings → Restore purchase | Pro returns | | |
| 8.7 | Restore with a sandbox account that owns nothing | "No previous purchase found on this Apple Account." | | |
| 8.8 | Force-quit after purchase, relaunch offline | Pro stays unlocked | | |
| 8.9 | Tap Unlock twice as fast as possible | One purchase sheet at most; never two charges | | |
| 8.10 | Free tier after all of the above | Capture, export and the weekly recap still work; 4th budget still gated | | |

## 9. Notifications

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 9.1 | Open Recap, close it, deny the permission prompt | No notification later; nothing else breaks | | |
| 9.2 | With permission granted, wait for the weekly slot (or move the clock) | One notification at the user's week start, 09:00, no amount in the text | | |
| 9.3 | Tap the notification | Recap opens | | |
| 9.4 | Delete all entries, then wait | No "your week is ready" notification | | |

## 10. Accessibility and appearance (spot check on device)

| # | Check | Expected | Result | Notes |
|---|---|---|---|---|
| 10.1 | VoiceOver: keypad, tiles, Log, History row, budget row | Every control has a name and a state; order is sensible | | |
| 10.2 | Accessibility XXXL text | No clipped or truncated amount; Log label inside its pill | | |
| 10.3 | Increase Contrast + Dark Mode | Text and tree states stay legible | | |
| 10.4 | Reduce Motion on | No opening animation; capture usable immediately | | |

## Defect log

| # | Severity | Where (line above) | What happened | Build | Status |
|---|---|---|---|---|---|
| | | | | | |

Critical/high defects are fixed and the affected lines re-run before the checklist line is
marked complete.
