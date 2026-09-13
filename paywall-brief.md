# TapLog — where should the paywall go?

You are deciding the free/paid line for a shipping iOS app. You have no access to
the code and don't need it: everything the app does is below. Read the whole
inventory before you form a view — the answer depends on which moment sells the
app, and that moment is easy to miss if you skim to the feature list.

## The decision I want from you

1. **The line.** What is free, what is paid. Feature by feature, using the names
   in the inventory. Where you split something (e.g. "free up to N"), say what N
   is and why that number.
2. **The trigger moments.** Where in the app does someone meet the paywall, and
   what have they just done or just tried to do? This matters more to me than the
   feature list. A correct feature split shown at the wrong moment converts
   nobody and annoys everybody.
3. **The reasoning**, in terms of what a user has felt by the time they're asked
   to pay — not in terms of feature tiers or competitor tables.
4. **What you rejected**, and why. Especially any split that looks obvious and
   isn't.
5. **What would change your mind.** Name the one or two facts you'd want that I
   haven't given you, and say which way each would push you.

You may conclude the current line (below) is right. You may conclude I should
charge for something entirely different, charge differently, or not charge at
all. Say so plainly; I'd rather rebuild than ship a line you had to talk
yourself into.

## What the app is

A single-purpose expense logger for people who want to know where small daily
money goes. The whole bet is time-to-log: an expense should be recorded in a
couple of seconds, from wherever you are, without opening an app and navigating.
Everything else in the app exists to make that habit stick and to pay it back
with something worth looking at.

It is not a budgeting suite, not a bank aggregator, and has no bill-splitting,
receipts, multi-currency, or shared accounts. Defaults are India-friendly.

## Complete feature inventory

### Capture — the core loop

- In-app numeric keypad, large amount display, currency symbol.
- A row of four suggested category tiles plus a "More" button opening the full
  picker. Suggestions are ordered: categories you've set a budget on first, then
  the ones you log most.
- Optional free-text note per entry.
- An "Impulse?" control beside the category — mark a purchase impulse or planned,
  or leave it unanswered. Unanswered is a real, preserved state, not a default.
- One "Log" button. After logging, an undo toast appears for a few seconds.
- Above the keypad: today's total, the day of the week, a small strip of budget
  trees (see below), and a count of budgets currently over target.

### Front doors — logging without opening the app

- **Home Screen widget** (small and medium) showing today's spend; tapping it
  opens capture.
- **Lock Screen widgets** (circular and rectangular).
- **Control Centre button and Action Button** — one press opens capture.
- **Siri**, with spoken phrases including the category ("Log chai in TapLog").
- **Shortcuts actions**: Log Expense (amount, category, note), Quick Log
  (amount, category), Open Expense Capture (optionally prefilled).
- **Share Sheet extension**: share the text of a bank payment SMS or push
  notification into TapLog; it extracts the amount and merchant and creates a
  pending entry you confirm or discard in the app. Handles formats like
  "Rs 1,200 debited HDFC" or "You spent $12.50 at Starbucks".

All of these write to the same data as the app.

### Categories

- Thirteen seeded on first launch: Chai, Food, Transport, Metro, Lunch,
  Groceries, Shopping, Bills, Snacks, Health, Fun, Rent, Other.
- Fully editable — add, rename, re-emoji, reorder, delete. A user can delete all
  the defaults and run fully custom.
- Deleting a category never breaks history; those entries display as "Other".

### Budgets and the grove — the app's signature mechanic

- Give any category a spending target on a weekly or monthly cycle.
- Each budgeted category is drawn as a **tree** whose state reflects how you're
  doing against that target: seedling, sprout, growing, wilting (one bad
  period), resting (chronically over, but alive). **A tree never dies**, by
  design — the app doesn't punish.
- The trees appear as a strip on the capture screen and as a full grove on the
  Budgets screen.
- Budgets screen lists each budget with spent-versus-target, this period, and a
  comparison to last period. Each budget runs on its own cycle.
- An explainer screen describing how the tree states work.

### Recap — the payoff

Toggles between a **weekly** and a **monthly** span. Shows:

- Total for the period, versus the previous period, with direction and percentage.
- Daily bars across the period.
- Breakdown by category, with each category's share as a percentage.
- A budgets section (each budget on its own cycle, independent of the span toggle).
- **Impulse vs. planned**: the share of marked spending that was impulse, with an
  explicit note when much of the period is unmarked, so a partial answer is never
  presented as a complete one.
- Total number of expenses logged.
- **CSV export** of entries.

### History

- All entries grouped by date; tap to edit amount, category, note, date, intent.
- Archive and unarchive; a toggle between active and archived views.
- Delete individual entries.
- Pending entries from the Share Sheet are confirmed or discarded here.

### Habit mechanics

- A **consistency target**: how many days per week you aim to log at all.
- A weekly ring and a **streak** measured in weeks that hit the target.
- **Streak freezes**, earned one per ten logs, which absorb a missed week.
- **One notification, ever**: a weekly nudge when the recap period closes,
  reading "Your week is ready." — no amounts. Permission is requested only after
  the user has seen a recap or finished their first week, never at launch.

### Onboarding

Welcome, choose your categories, an optional one-tap-skippable screen offering
to put a weekly target on your most-used category (with a live preview of the
tree), and a screen for setting up the front doors.

### Settings

Currency, appearance (system/light/dark), consistency target, a "faster ways to
log" guide, Pro and Restore Purchase, delete-all-data.

### Data, privacy, cost

- **Everything is local to the device.** No account, no sign-up, no server, no
  analytics, no tracking.
- **No iCloud sync and no multi-device support.** Worth dwelling on: the single
  most common paid tier in this app category does not exist here, and building it
  is real work.
- Data is shared with the widget and Share Sheet through an app group.
- CSV export is the only way data leaves the device, and the user initiates it.

**There is no marginal cost per user.** Nothing here is expensive to run, so no
gate can be justified as recovering server cost. Any line you draw is a pure
willingness-to-pay judgement.

## Business context

- Solo developer, a few hours a week. Maintenance cost of a tier is a real
  consideration; two divergent code paths forever is a genuine cost.
- The pricing model is already decided: **a single one-time purchase, unlocked
  for good. No subscription.** Treat that as fixed. If you think it's wrong, say
  so in one paragraph at the end, but give me your answer within it.
- Consequence worth thinking about: with no recurring revenue, the paywall has
  exactly one chance per user, and there is no "they'll upgrade later" — so the
  trigger moment carries all the weight.

### Facts I have to give you — FILL THESE IN BEFORE SENDING

- Price point: ____
- Target market / geography: ____
- Current install base and whether anyone has paid yet: ____
- Whether I'd be willing to build iCloud sync as a paid feature: ____

If any are blank, state the assumption you're using and flag how much it moves
your answer. Do not invent them.

## What is currently built

Shipping today, so you know what you'd be overturning:

- **Free**: all capture, every front door, unlimited entries, unlimited history,
  categories, habit mechanics and notification, CSV export, **one budget tree**,
  and the **weekly** recap.
- **Paid**: a target for every category (unlimited grove) and the **monthly**
  recap span.
- **Two triggers**: trying to create a second budget, and tapping the month
  toggle on the recap.
- Deleting a budget returns the free slot; existing budgets are never taken away
  from someone who doesn't pay.

This line was drawn to satisfy a constraint of "don't gate anything already
shipped," which is a constraint about upgrade fairness, not about what converts.
It has never been tested against a user.

## Tensions I already see — engage with these, don't just restate them

- The grove is the app's signature and the reason anyone would remember it. The
  current line makes the memorable thing the thing you can barely use for free.
  Is that the right lever, or is it strangling the demo?
- Small-money patterns arguably need a month to become visible at all. If the
  monthly recap is where the insight actually lives, gating it may gate the exact
  moment that would have sold the app.
- Capture is entirely free, including every front door and unlimited history.
  That is either precisely right — the habit must form before anything can be
  sold — or it gives away the whole product.
- One tree is enough to understand the mechanic but not enough to feel it. Is the
  free allowance a number problem rather than a feature problem?

## Format

Lead with the line and the trigger moments, in under 200 words, so I can act on
it without reading further. Then the reasoning, the rejected alternatives, and
what would change your mind. Be decisive; I want a recommendation, not options.
