# Run TapLog on your iPhone — step by step

*26 Sep 2026 · updated for the current build (StoreKit paywall, App Group store, grove budgets). README's quick version is a summary of this.*

**Time needed:** 10–15 minutes. **Cost:** free — a paid developer account is *not* required to run TapLog on your own iPhone.

---

## What you need

| Thing | Where |
|---|---|
| A Mac with Xcode (any recent version; repo is tested on Xcode 26.x) | Mac App Store |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | `brew install xcodegen` |
| Your iPhone + a Lightning/USB-C cable | — |
| A free Apple ID (the one on your iPhone is fine) | — |

> The deployment target is **iOS 17.0**, so the phone needs iOS 17 or later — that's iPhone XS/XR/SE 2nd-gen or newer.

---

## Part A — One-time Mac setup (5 min)

1. **Get the code.**
   ```sh
   cd ~/Projects && git clone <this repo> && cd TapLog
   ```
2. **Generate the Xcode project.** The project is *always* generated from `project.yml` — never open/edit the `.xcodeproj` directly.
   ```sh
   xcodegen generate
   ```
3. **Sign in to Xcode with your Apple ID.** Xcode → Settings → Accounts → `+` → sign in. This is what lets you install free apps onto your own phone.
4. **Find your Team ID.** Xcode → Settings → Accounts → select your Apple ID → the **Team ID** is shown under the personal team (starts with a letter+9 chars, e.g. `AB12CD34EF`). Copy it.

---

## Part B — Make the identifiers yours (2 min)

Bundle IDs must be unique **per signing Apple ID**. The repo ships `dev.amteshwar.taplog`; if you're not Amteshwar, change all of them (3 lines) in `project.yml`:

```yaml
# In targets.TapLog.settings.base
PRODUCT_BUNDLE_IDENTIFIER: dev.yourname.taplog

# In targets.TapLogWidget.settings.base
PRODUCT_BUNDLE_IDENTIFIER: dev.yourname.taplog.widget

# In targets.TapLogShare.settings.base
PRODUCT_BUNDLE_IDENTIFIER: dev.yourname.taplog.share
```

Also change the URL name if you like (`CFBundleURLName` in `targets.TapLog.info.properties`), and the two App Group IDs (`group.dev.yourname.taplog`) — the group *must* match the bundle prefix for automatic provisioning.

Then set your team so it survives regeneration (top `settings.base` block):

```yaml
settings:
  base:
    DEVELOPMENT_TEAM: YOUR_TEAM_ID_HERE
```

Regenerate: `xcodegen generate`.

### Free Apple ID? Remove App Groups (important)

App Groups entitlements need a **paid** developer account. With a free account you have two options:

- **Recommended:** delete the three `entitlements:` blocks (app, `TapLogWidget`, `TapLogShare`) from `project.yml`, then `xcodegen generate`. The app automatically falls back to on-device storage (`StoreLocator` handles this, and Settings will show one honest warning that widget/share can't see data).
- **Or** keep them and Xcode will offer "Personally provision" — accept it; results vary by Xcode version.

With a **paid** account ($99/yr): keep everything, and also register the App Group in [developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → App Groups](https://developer.apple.com/account/resources/identifiers/list/applicationGroup) (`group.dev.yourname.taplog`). Everything works: widget + share sheet included.

---

## Part C — Install on the iPhone (3 min)

1. Plug the iPhone into the Mac, **unlock it**, tap **Trust** when prompted.
2. In Xcode: select the **TapLog** scheme, destination = your iPhone.
3. Press **⌘R**.
4. First run fails? That's expected. On the phone: **Settings → General → VPN & Device Management → your Apple ID → Trust** "[Your Name]". Also: **Settings → Privacy & Security → Developer Mode → ON** (iOS 16+; phone reboots).
5. **⌘R** again. The app launches.

> **Free account caveat:** apps signed with a personal team expire after **7 days** — when TapLog stops opening, just ⌘R from Xcode again. Paid accounts get 1 year.

---

## Part D — Test all the front doors (the fun part)

TapLog's whole pitch is "log from anywhere." Verify each door on the phone:

### 1. In-app capture (core loop — should be ≤5 s)
Open TapLog → type an amount on the big keypad → tap a category tile → **Log**. Undo toast appears; try Undo.

### 2. Siri (two routes)
- **Headless logging:** say *"Hey Siri, log an expense in TapLog"*. Siri asks amount → category → note (say "skip"). Nothing opens; entry appears in History.
- **Keypad route:** say *"Hey Siri, open capture in TapLog"* — app opens straight onto the focused keypad.
- Try the category phrase: *"Hey Siri, log chai in TapLog."*

### 3. Action Button (iPhone 15 Pro and later)
**Settings → Action Button → Shortcut → Log Expense** (headless) or **Open Expense Capture** (opens keypad). Press and hold the Action Button from anywhere — even lock screen.

### 4. Home Screen widget
Long-press home screen → **+** → search **TapLog** → add the **medium** widget. It shows today's total plus up to 3 **learned** quick-log buttons (they come from your real history after a few logs). Tap a button → logs instantly, no app. Re-open TapLog within 10 minutes → you'll get an undo toast for the widget log.

### 5. Lock Screen widget
Long-press Lock Screen → **Customize** → tap the Lock Screen canvas → **Add Widgets** → TapLog → pick circular or rectangular.

### 6. Control Center (iOS 18+)
Open Control Center → **+** → **Add a Control** → TapLog → "Log expense".

### 7. Share sheet (bank-SMS capture)
Copy some fake bank text, e.g.:
```
You spent $12.50 at Starbucks
```
Open Notes → paste → select text → **Share → TapLog**. The extension parses amount+merchant and saves a *pending* entry. Open TapLog → History → confirm it. (Try sharing an OTP message too — it should refuse to invent an expense.)

### 8. Deep link (power users)
In Safari on the phone, type:
```
taplog://log?amount=12.50&note=coffee
```
Capture opens pre-filled. (Xcode users can also: `xcrun simctl openurl booted "taplog://log?amount=12.5"` in the simulator.)

### 9. Back Tap (bonus)
Settings → Accessibility → Touch → Back Tap → Double Tap → **TapLog / Open Expense Capture**.

---

## Part E — Paywall & purchase test (optional)

1. Log at least 3 expenses.
2. **Budgets (leaf icon)** → plant a 4th budget → the paywall appears (3 trees are free).
3. **Recap (chart icon)** → tap **Month** → paywall again (weekly recap is free forever).
4. Sandbox note: on a personal-team build without App Store Connect products, the price shows "—" and purchase fails gracefully. That's expected — real purchases need the App Store Connect product (see the pre-launch checklist). The scheme's local StoreKit config (`Configs/TapLog.storekit`) lets you test the *flow* in the simulator.

---

## Part F — Demo data & settings

- **Seed demo data:** home → **⋯ → Settings → Seed sample data** (12 entries, 4 budgets, realistic tree states). Great for screenshots.
- **Currency:** Settings → Currency (17 options; stored in the App Group so the widget matches).
- **Appearance:** System / Light / Dark.
- **Weekly log target:** Settings → Consistency (3–7 days; drives the streak).
- **Delete all:** Settings → Danger Zone (also resets streaks + cancels the Sunday notification).

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Unable to install" / signing error | Set `DEVELOPMENT_TEAM` in `project.yml`, re-run `xcodegen generate`, ⌘R. Check bundle IDs are unique to *your* account. |
| App stops opening after ~7 days | Personal team expired. Rebuild from Xcode (⌘R). |
| Widget shows ₹0 while app has data | App Group not active on your build (free-account path). Expected — remove entitlements for a clean look, or use a paid account. Settings will show the warning. |
| Siri says "something went wrong" | Old build; the store is now opened once per process. Rebuild. |
| Share sheet does nothing | Share plain **text** (not a link). The extension only reads text. |
| Deep link does nothing | Must be `taplog://` scheme — type it fully in Safari's address bar. |
| Action Button does nothing | It's iPhone 15 Pro+ only; and it must be assigned to the TapLog shortcut (Settings → Action Button). |

---

## Where to go next

- Ship it: `appstore/` folder + the **App Store pre-launch checklist** (companion artifact).
- Tell people about it: **marketing & revenue plan** (companion artifact).
- Understand the code: `docs/taplog-repo-explainer.html` (companion visual artifact).

*Generated with Codebuff 🤖*
