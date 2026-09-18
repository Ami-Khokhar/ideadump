# TapLog Master Growth, Launch & Distribution Kit

> **Out of date (18 Sep 2026):** the App Store text below describes an older paywall and features the app does not have. Use `appstore/metadata.md` for App Store Connect.

*Generated for Amteshwar | Product: TapLog (iOS)*
*Role: Distro (Growth & Distribution Lead)*

---

## 1. App Store Optimization (ASO) & Metadata Matrix

### App Store Connect Fields
* **App Name (30 chars max):** `TapLog: Fast Expense Tracker` (29 chars)
  * *Alt:* `TapLog - Quick Expense Logger` (30 chars)
* **Subtitle (30 chars max):** `Action Button & Siri Spending` (30 chars)
  * *Alt:* `Private, 2-Sec Expense Log` (26 chars)
* **Primary Category:** Finance
* **Secondary Category:** Utilities
* **Content Rights / Privacy:** No data collected (100% On-Device SQLite).

### 100-Character Keyword Bank (Comma-separated, no spaces after commas)
`expense tracker,budget,spending,action button,siri,offline,receipt,money manager,minimal,private,log` (100 chars)

### App Store Promotional Text (170 chars max)
> Log expenses in 2 seconds flat using your iPhone Action Button or Siri. 100% offline, zero bank logins, no ads, and no monthly subscriptions. Pay once, own it forever.

### App Store Description (Formatted Markdown)
```text
Tired of opening slow finance apps that demand your bank login, clutter your screen with ads, and charge a $10/month subscription just to track where your cash went?

TapLog is built for one thing: getting an expense out of your head and into a private ledger in under 2 seconds.

WHY TAPLOG IS FASTER:
• Action Button Ready: Map TapLog to your iPhone 15 Pro / 16 Pro Action Button. Long press, tap your amount, and done.
• Zero-Config Siri: Say "Hey Siri, log 150 for coffee in TapLog" — no complex Shortcuts setup required.
• Local-First & Private: Your data stays on your iPhone in a local database. No cloud accounts, no tracking, no analytics, no bank passwords.
• Pure Haptics & Speed: Custom numeric keypad designed for one-handed thumb entry on the move.

FREE FEATURES (FOREVER):
• Unlimited daily expense logging
• Instant Action Button & Siri voice capture
• Full transaction history and running daily totals
• Basic category tagging (Food, Transport, Bills, Shopping, Groceries, Misc)

LIFETIME PRO UNLOCK (ONE-TIME PURCHASE):
• Deep Weekly & Monthly spending recaps
• Category spending breakdowns and trends
• Unlimited custom categories and custom icon tags
• Full CSV data export (ready for Excel, Numbers, Notion, or Sheets)
• Custom App Icons and OLED Dark themes

No recurring fees. No rent on your financial data. Buy once, own forever.
```

---

## 2. Screenshot Production Script (5-Screen Sequence)

Frame: iPhone 16 Pro mockup on dark background (`#090C15`) with ivory text (`#F0EFEA`).

* **Screen 1 (The Hook):**
  * *Top Banner:* "LOG IN 2 SECONDS"
  * *Graphic:* Hand pressing Action Button $\rightarrow$ TapLog keypad popping up with `₹150` entered.
  * *Subtext:* Native Action Button & Siri support out of the box.
* **Screen 2 (Zero Privacy Compromise):**
  * *Top Banner:* "100% OFFLINE & PRIVATE"
  * *Graphic:* Clean badge showing "No Bank Logins • No Account • SQLite Local".
  * *Subtext:* Your financial data never leaves your device.
* **Screen 3 (One-Handed Speed):**
  * *Top Banner:* "BUILT FOR MUSCLE MEMORY"
  * *Graphic:* The custom high-contrast keypad with clear category chips.
* **Screen 4 (Insights without Clutter):**
  * *Top Banner:* "WEEKLY & MONTHLY RECAPS"
  * *Graphic:* Category breakdown card showing clean spend distribution percentages.
* **Screen 5 (Anti-Subscription):**
  * *Top Banner:* "PAY ONCE. OWN FOREVER."
  * *Graphic:* The Pro badge comparing ₹499 Lifetime vs ₹499/mo subscriptions.

---

## 3. Subreddit Action Packets (Copy-Paste Ready)

### Packet A: `r/shortcuts`
* **Title:** I built an expense logger that ships native App Shortcuts & Siri phrases out of the box (no manual shortcut building needed)
* **Flair:** `Share` / `Discussion`
* **Body:**
```text
Hey everyone,

Like many of you, I tried setting up custom iOS Shortcuts with Data Jar / Apple Notes to quickly log daily expenses via the Action Button. The problem was always edge cases: keyboard lag on lock screen, error handling when Siri misheard numbers, and maintaining the shortcut across iOS updates.

I ended up building TapLog—a lightweight, local-first iOS app that exposes prebuilt App Shortcuts and Siri phrases natively via `AppShortcutsProvider`.

How it works:
1. Map your Action Button directly to `TapLog -> Open Expense Capture`.
2. It launches instantly into a focused numeric keypad with zero setup.
3. You can also say "Hey Siri, log 120 in TapLog" directly without assembling anything in the Shortcuts app.

Everything runs on local SQLite—no cloud syncing, no accounts, and no network requests.

The core capture and Siri/Shortcuts integration are 100% free. If anyone wants to test the Action Button latency or has suggestions for more App Intents parameters, I’d love your feedback!

[App Store / TestFlight Link]
```

### Packet B: `r/iosapps` & `r/apple`
* **Title:** Tired of $5/month subscription budgeting apps, so I made a 2-second, local-only expense logger (TapLog)
* **Flair:** `Self-Promotion` / `App Release`
* **Body:**
```text
Hey r/iosapps,

Most expense trackers today suffer from two huge problems:
1. They take 15 seconds to open, sync, and log a simple coffee.
2. They charge $5–$10/month and want access to your bank credentials.

I built TapLog because I wanted something that felt like an Apple native utility:
• 2-second capture: Opens directly via Action Button, Siri, or Lock Screen.
• 100% Private: Stored locally in SQLite on your device. Zero telemetry, zero bank logins.
• No subscriptions: Core logging is free. Pro (recaps, CSV export, custom categories) is a single one-time lifetime unlock of ₹299 ($4.99 launch special).

Would love for you to try it out and let me know how the capture speed feels on your device!

[App Store Link]
```

### Packet C: `r/privacy` & `r/selfhosted`
* **Title:** TapLog: A local-first, zero-telemetry iOS expense tracker (No cloud, no accounts, full CSV export)
* **Flair:** `Tool` / `Software`
* **Body:**
```text
For anyone looking for a completely offline way to track daily spending on iOS without handing bank credentials to third-party aggregators (Plaid/Yodlee) or storing balances on SaaS servers:

I built TapLog. It is a local-only expense logger with zero network dependencies.
• Database: Local SQLite on-device
• Permissions: Requires 0 network permissions
• Export: Full one-tap CSV export so you can pipe data straight to your local spreadsheets or self-hosted ledger
• Fast capture: Supports iOS Action Button and offline Siri intents

Core logging is free forever. CSV export and extended recaps are unlocked via a one-time purchase.

[App Store Link]
```

---

## 4. Show HN & Product Hunt Playbooks

### Show HN
* **Submission Title:** `Show HN: TapLog – A 2-second, local-first iOS expense logger with Action Button integration`
* **URL:** App Store Link / Landing Page
* **First Comment (Maker Story):**
```text
Hi HN,

I built TapLog because manual expense tracking usually fails at the moment of capture. If logging a coffee takes more than 3 seconds—waiting for an app to boot, authenticate, and navigate through tabs—I simply stop doing it after 4 days.

TapLog focuses purely on reducing capture latency to under 2 seconds:
- Deep integration with iOS 16/17/18 App Intents (`AppShortcutsProvider`) so the Action Button immediately opens the numeric keypad.
- Local SQLite storage with zero network dependencies or cloud telemetry.
- No bank scraping.
- Monetized via a one-time lifetime unlock rather than a subscription.

Tech stack: Swift, SwiftUI, SwiftData/SQLite, AppIntents.

I’d love your feedback on the interaction design, App Intents execution speed, and local data portability.
```

### Product Hunt
* **Tagline:** `The 2-second, local-first expense tracker for iPhone`
* **Pricing Type:** `Free + One-time purchase`
* **Topics:** `iOS`, `Productivity`, `Privacy`, `Personal Finance`

---

## 5. Short-Form Video Storyboards (Reels / Shorts / TikTok)

### Video 1: "The Only Action Button Shortcut You Need" (12 Seconds)
* **Hook (0-2s):** Close-up shot of finger pressing the iPhone 16 Pro Action Button. Text on screen: *"The only Action Button shortcut I use every single day."*
* **Action (2-6s):** Screen instantly illuminates showing TapLog's high-contrast keypad. Thumb types `1 5 0`, taps `Coffee` chip.
* **Payoff (6-9s):** App displays smooth green checkmark haptic, phone drops back into pocket. Total elapsed time: 2.3 seconds.
* **Callout (9-12s):** Screen overlay: *"No accounts. No subscriptions. 100% offline. Link in bio."*

### Video 2: "Stop Paying Monthly Rents to Track Spending" (15 Seconds)
* **Visual:** Split screen. Left side: Cluttered app with loading spinner and "Connect Bank Account" pop-up. Right side: TapLog Action Button tap $\rightarrow$ logged.
* **Audio/Text:** *"Why are we paying $8/month just to write down where our money went? Try TapLog: 100% local, one-time lifetime ownership."*

---

## 6. Cold Creator Outreach Templates (X / Instagram DM / Email)

**Target:** Tech YouTubers, minimalist desk setup creators, iOS utility reviewers (5k–50k followers).

**Subject:** Quick iOS utility for your Action Button (Promo code inside)
```text
Hey [Name],

Loved your recent breakdown of your iPhone setup.

I noticed you're a fan of minimalist, high-utility apps, so I wanted to share something I built: TapLog.

It's a local-first, zero-subscription expense tracker designed specifically around the iPhone Action Button and Siri. You can log any expense in under 2 seconds without bank logins or cloud accounts.

I’d love to send you a lifetime promo code to test it out on your setup. Here is a 10-second demo: [Link]

Let me know if you’d like a code!

Best,
Amteshwar
```

---

## 7. 30-Day Launch & Revenue Execution Calendar

| Phase | Days | Focus | Action Items |
| :--- | :--- | :--- | :--- |
| **Setup** | Days 1–3 | Asset Finalization | Record the 10-second Action Button demo clip; finalize StoreKit 2 configuration. |
| **ASO & Submissions** | Days 4–5 | Store Listing | Upload ASO metadata, screenshots, and submit binary to App Store review. |
| **Soft Launch** | Days 6–10 | High-Intent Seeding | Post Packet A to `r/shortcuts` and Packet B to `r/iosapps`. Engage in comments for 2 hours. |
| **Expansion** | Days 11–18 | Public Directory & HN | Launch on Show HN and Product Hunt; post Packet C to `r/privacy`. |
| **Short-Form Loop** | Days 19–25 | Video Outreach | Post 3 Reel/Short demo variations; send 15 creator DMs with lifetime codes. |
| **Decision Gate** | Day 30 | Scorecard Evaluation | Evaluate conversions: Target is 15+ paid sales (Pass). |

---

## 8. Validation Gate & Scorecard (Day 30)

* **PASS (Keep, Maintain & Compound):**
  * 150+ total installs
  * **15+ Lifetime Pro Sales** (₹4,500+ / ~$150+ net)
  * >20% Day-7 active logging retention
* **FAIL (Park & Pivot):**
  * <50 installs despite community posts
  * 0–2 Lifetime Pro Sales
  * High friction feedback regarding manual tracking interest
