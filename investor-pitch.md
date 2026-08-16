# TapLog (working title)

**The fastest way to know where your money goes.**

TapLog is a local-first iPhone app that logs a purchase in under five seconds — from the
iPhone's Action Button, a widget, Siri, or automatically from a bank payment notification —
and turns that raw log into a weekly story of your spending. No account, no cloud, no
bank-credential sharing. Your data never leaves your phone.

---

## The problem

**Every finance app fails at the same moment: the moment of capture.**

People don't abandon budgeting apps because they're bad at budgets. They abandon them
because logging a purchase is work. Open the app, navigate to the right screen, type an
amount, hunt through a category list, save. Three taps and thirty seconds per transaction —
so people log diligently for two weeks, fall behind, feel guilty, and quit. The average
tracking app loses its users in the first month. The "daily log" habit never forms.

**The aggregation era is dying, and users are looking for a new home.**

For a decade the market assumed the future was automatic: connect your bank, let the app
categorize everything for you. That future has collided with reality. Mint — once the
category's default app, with an estimated 3.6 million active users — was shut down by Intuit
in early 2024, displacing millions. Bank-data aggregators face mounting regulatory and
consumer pressure. And a growing cohort of users simply refuses to hand a third party the
keys to their entire financial history: they want their spending data on their own device,
not in a vendor's cloud.

The incumbents that survived the Mint exodus — YNAB, Monarch, Copilot — all took the same
path: $10–15/month, an account, and full bank aggregation. None of them are fast to capture
from, none of them are local-first, and all of them cost more than a streaming service.

---

## The product

### Capture in ≤5 seconds, from anywhere

The insight is simple: **the capture moment is the product.** Everything else — charts,
budgets, insights — only matters if the data actually gets in. TapLog is designed around
speed of entry:

- **iPhone Action Button** — press and log. The hardware affordance built for exactly this.
- **Home / lock screen widgets** — one tap opens a pre-focused capture form.
- **Siri / voice** — "Log twelve on coffee."
- **Share sheet** — share a bank SMS or receipt straight into a pre-filled form.
- **Automatic capture from payment notifications** — a Shortcuts automation watches your
  bank's payment alerts and asks one tap: *"Did you just spend $12 at Starbucks?"* This
  turns logging from proactive work into reactive confirmation — the lowest-friction capture
  that exists.

Every entry point lands on the same form. One deep link, infinite front doors.

### Local-first. Privacy is the feature, not the fine print

All data lives on-device (SwiftData). No account, no signup, no bank credentials, no cloud
sync, nothing to sell. "Your spending data never leaves your phone" is the headline — and
it's true. A one-tap CSV/JSON export covers backup. iCloud sync is the later opt-in for
multi-device, mirroring the local store rather than replacing it.

### A correction loop that keeps the data honest

Logging is worthless if errors can't be fixed. TapLog makes correction as fast as capture:

- **Undo toast** — "Logged $12 · coffee — Undo," live for five seconds after every capture.
- **Swipe-to-edit / swipe-to-archive** on recent entries, with one-tap recategorization.
- **Weekly review mode** — the same data as the dashboard, framed as "clean up your week."
  Sixty seconds on Sunday keeps the dataset trustworthy.

### The habit loop: a weekly recap

Every week, TapLog tells you what you spent, by category, versus the week before. That recap
is the reason people keep capturing: the data rewards them weekly, and the logging habit
compounds.

### Power users keep their spreadsheet

For the spreadsheet crowd — including the founder — TapLog offers an optional one-tap export
to their own Google Sheet. The founder's own daily flow (Action Button → Shortcuts →
AppScript → Sheet) is preserved as a feature, not an architecture everyone depends on.

---

## Why now

- **The iPhone 16 Action Button** puts a physical "log a purchase" trigger in millions of
  pockets for the first time.
- **iOS 17+ interactive widgets and mature Shortcuts automations** make every entry point
  above possible without a backend.
- **The post-Mint vacuum** left millions of displaced users searching for a simpler, cheaper,
  more private alternative to $100+/year aggregators.
- **Privacy is a purchase driver.** Post-ATT consumers increasingly pay a premium to keep
  their data off vendor clouds — and spending history is the most sensitive data on a phone.

---

## Market

Estimates vary by definition, but the direction is consistent:

| Segment | Est. size (2025) | Source |
|---|---|---|
| Personal finance mobile apps | ~$31B | Market Research Future |
| Expense tracker apps | ~$10B | Future Market Insights |
| Personal finance software | ~$1.4B (software-only) | Fortune Business Insights |

All segments project double-digit CAGR through the early 2030s. The wedge is the #1
abandoned behavior in the category — expense capture — as the on-ramp into budgeting,
insights, and later household finance.

---

## Competition

| App | Price | Capture speed | Local-first | Bank aggregation |
|---|---|---|---|---|
| YNAB | $14.99/mo | Slow (open app, navigate) | No | Optional |
| Monarch | $14.99/mo / $99.99/yr | Slow | No | Yes (required) |
| Copilot | $13/mo / $95/yr | Slow | No | Yes (required) |
| Rocket Money | ~$6–12/mo | Slow | No | Yes |
| **TapLog** | **~$2–4/mo Pro** | **≤5 seconds, anywhere** | **Yes** | **Never** |

Nobody owns fast, private, manual capture. The incumbents bet on aggregation; TapLog bets on
the person, their phone, and five seconds.

---

## Business model

- **Free tier:** capture from all entry points, local storage, entry list, undo.
- **Pro subscription (~$2–4/mo or ~$20–30/yr):** weekly recaps, custom categories, export,
  iCloud multi-device sync, household sharing (v3).
- **No ads. No data sales.** The privacy promise is the brand, so the brand can never violate
  it.

At a $2.99/mo effective price, TapLog undercuts every incumbent by 2–5x while keeping
healthy gross margins (App Store, no server costs, no data-pipeline costs).

---

## Defensibility

Honest answer: defensibility is earned, not granted. TapLog builds it three ways:

1. **The habit moat.** The switching cost isn't the data export — it's the two-week-old
   logging habit. Competitors can copy a form; they can't copy the daily ritual users have
   already built.
2. **The privacy brand.** In a category where every incumbent takes your bank credentials,
   "your data never leaves your phone" is a position they structurally cannot copy.
3. **Community distribution.** Shortcuts communities, Apple-focused press, and the privacy
   audience are reachable at near-zero CAC, and they evangelize.

---

## Roadmap

- **v1 (90 days):** iOS, local-first, Action Button + widgets + Siri + share sheet capture,
  undo/review correction loop, CSV export. **Validation: 30-day retention and weekly recap
  engagement.**
- **v2 (6 months):** weekly recaps, custom categories, optional Google Sheet export for power
  users, iCloud sync.
- **v3 (12 months):** household sharing, Android (different entry points — no Action Button
  there), read-only web dashboard from optional export.

---

## Team

Solo founder, dogfooding daily. The core flow — Action Button → 3-field form → Shortcuts →
AppScript → spreadsheet — has been live and in daily use on the founder's own phone. The
product exists as a working habit before it exists as a company.

---

## The ask

**Pre-seed: $250K** for a 12-month runway:

- v1 shipped to the App Store in 90 days
- 10,000 downloads and a 5% free→Pro conversion rate in year one (≈$18K ARR, establishing
  unit economics)
- Retention target: 40%+ of weekly-active users still logging at day 30 — the metric that
  proves the capture-first thesis

The ask is small because the architecture is cheap: no servers, no data pipeline, no
aggregation contracts. The bet is pure product and distribution.

---

## Risks

- **Single-platform (iOS-first).** Android has no Action Button, so the entry-point strategy
  must differ there. Mitigation: the deep-link capture architecture is platform-agnostic;
  Android ships with widgets + notification capture.
- **Incumbents could copy capture-first.** They can copy the form; the habit and the privacy
  brand are the moat.
- **App Store discovery is hard.** Mitigation: community-led growth (Shortcuts subreddits,
  Apple press, privacy audience) rather than paid acquisition in v1.
- **Notification-based capture is fragile.** Bank notification formats vary. Mitigation:
  confirmation step, graceful fallback to manual capture, and it's a bonus path, not the
  core.

---

*Sources: Bloomberg (Mint active users, 2021); CNBC (Mint shutdown, Jan 2024); Market
Research Future, Future Market Insights, Fortune Business Insights (market sizing, 2025);
competitor pricing as published on official sites, 2025–2026. Market sizing estimates vary
widely by methodology and are directional, not precise.*
