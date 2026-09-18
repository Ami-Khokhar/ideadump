# TapLog — App Store Connect text

Paste each field into App Store Connect. Lengths are checked against Apple's limits by the script that produced this file.

## App name  (23/30)

```text
TapLog: Expense Tracker
```

## Subtitle  (26/30)

```text
Fast, private spending log
```

## Keywords  (98/100)

```text
budget,money,siri,action button,widget,offline,diary,daily,cash,chai,habit,streak,grove,no account
```

## Promotional text  (158/170)

```text
Log what you spend with one tap, a widget, or Siri. Budgets grow into a grove of trees. No account, no ads, no subscription. Your records stay on your iPhone.
```

## Description  (1481/4000)

```text
TapLog is the fastest way to write down what you just spent, and a small grove of trees that shows how your budgets are doing.

LOG IT BEFORE YOU FORGET
• TapLog opens on a keypad. Type the amount, tap a category, done.
• Say "Log chai in TapLog" and Siri asks how much. No setup needed.
• Put TapLog on the Action Button or the Lock Screen, or add it to Control Center (iOS 18).
• Log your usual spends from the Home Screen widget without opening the app.
• Send text from another app with the share sheet, and confirm it later.
• Logged the wrong thing? Undo is one tap away.

BUDGETS THAT GROW
Give a category a weekly or monthly target and it grows a tree. Stay inside the target and the tree fills out. Go over and it thins. It never dies, and one bad week never wipes out your history.

A WEEK YOU CAN READ
Each week TapLog puts together a short recap of where your money went, and reminds you when it is ready. Set how many days a week you want to log, and keep your streak going.

PRIVATE BY DESIGN
• No account, no bank login, no ads, no tracking.
• Everything stays on your iPhone. TapLog has no server and sends your data nowhere.
• Export everything to CSV at any time, free.

FREE
• Unlimited logging from the keypad, Siri, widgets, and shortcuts
• Up to three budget trees
• The weekly recap
• CSV export

TAPLOG PRO: ONE PAYMENT, NO SUBSCRIPTION
• A budget tree for every category
• The monthly recap, alongside the weekly one

Everything you already use stays free.
```

## IAP display name  (10/30)

```text
TapLog Pro
```

## IAP description  (39/45)

```text
Every budget tree and the monthly recap
```
## App Review notes

```text
TapLog needs no account and no login. All data stays on the device; the app makes no network requests.

To see the in-app purchase (TapLog Pro, non-consumable):
1. Open the app and go through the short welcome.
2. Tap the bar-chart button at the top right to open Recap.
3. Tap "Month". The paywall opens.

A second way: tap the leaf button to open Budgets, and create a fourth budget. Three are free.

Siri and Action Button: the app registers App Shortcuts ("Log chai in TapLog", "Open capture in TapLog"). The Action Button runs the "Open Expense Capture" shortcut, which opens the keypad.
```

## Other App Store Connect answers

| Field | Answer |
|---|---|
| Primary category | Finance |
| Secondary category | Productivity |
| Price | Free (with one in-app purchase) |
| App Privacy | **Data Not Collected.** No analytics, no tracking, no server. Matches `PrivacyInfo.xcprivacy`. |
| Age rating | 4+ (answer "None" to every content question; no web access, no user-generated content shared with others) |
| Export compliance | Already answered in the build: `ITSAppUsesNonExemptEncryption = NO` |
| Content rights | No third-party content |
| Sign-in required for review | No |
| Copyright | 2026 Amteshwar Singh Khokhar |
| Support URL | *Needed.* Host `appstore/support.html` and paste its address. |
| Privacy Policy URL | *Needed.* Host `appstore/privacy-policy.html` and paste its address. |

## In-app purchase to create

| Field | Value |
|---|---|
| Type | Non-Consumable |
| Product ID | `dev.amteshwar.taplog.pro.lifetime` (must match exactly — the app asks for this ID) |
| Reference name | TapLog Pro (lifetime) |
| Price | $4.99 (the local test file uses this price) |
| Display name / description | See the two IAP fields above |
| Review screenshot | Screenshot of the paywall (Recap → Month) |

Submit the in-app purchase **with** the first app version: on the version page, add it under "In-App Purchases and Subscriptions" before you press Submit for Review.

## Screenshots

`appstore/screenshots/` holds three 1320 × 2868 PNGs for the 6.9-inch iPhone slot. App Store Connect scales them down for smaller iPhones. Upload them in number order.
