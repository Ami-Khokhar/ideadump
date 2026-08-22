# TapLog — Retention System Design

> A full retention design mapped to the 7 proven mechanics — built for a zen expense tracker, not a game.

---

## Guiding Principle

TapLog is a **tool**, not a game. Every retention mechanic must pass the **5% test**: if the "game" layer takes more than 5% of the user's interaction time, it fails. The reward for tracking expenses is *financial awareness* — not points, badges, or virtual currencies.

**Non-negotiable:** The zen stone, the 5-second capture, and the clean UI come first. Retention mechanics live in the background — visible but never demanding.

---

## Current State vs. Opportunity

| Mechanic | TapLog Today | Opportunity |
|---|---|---|
| I. Winnable Arenas | ❌ None | Personal "beat your average" weekly challenge |
| II. Cognitive Load Caps | ✅ Excellent (5s capture) | Keep it — never add inventory/RPG layers |
| III. Flexible Consistency | ❌ No streaks | Weekly log streak with freeze + customizable target |
| IV. Variable Rewards | ❌ None | Weekly Insight reveal after ring completion |
| V. Gestalt Closure | 🟡 Ripples only | Weekly spending ring on home screen |
| VI. Competence Metrics | ❌ None | Real financial awareness metrics, not badges |
| VII. Micro Social | ❌ None | 1-tap share monthly summary card |

---

## The 7 Mechanics

### I. Winnable Arenas

Global leaderboards don't work for expense tracking — nobody cares about being #482,912. The winning arena is **you vs. your own average**.

- **Weekly Personal Challenge:** "Stay under $X this week" — auto-calculated from your 4-week rolling average + 10% buffer
- **Why it's winnable:** It's your own data, your own baseline. You're competing with last-you.
- **Transient:** Resets every Monday. No permanent rankings, no shame in losing.
- **Visual:** A subtle bar on the home screen: "This week: $187 / $220 target" with a sage fill that stops at the target line.

**Design rule:** The target is always achievable — calculated from YOUR history, not an arbitrary number.

### II. Cognitive Load Caps

The existing 5-second capture is the foundation. Retention mechanics must be **zero additional friction**.

- ✅ 5-Second Capture: Amount → Category → Log. No setup, no onboarding tax.
- ✅ No Game Currency: No coins, gems, XP, or virtual money.
- 🛡️ 5% Budget: Any new feature must take ≤5% of interaction time.

**Never add:** Virtual pets, inventory management, daily quests, energy systems, or "check in to earn coins."

### III. Flexible Consistency

Rigid daily streaks are anxiety engines. Expense tracking doesn't happen every day — a **weekly rhythm** with flexibility is the right model.

- **Target:** User-customizable (default: 5 days/week). Options: 3, 4, 5, 6, 7.
- **Streak:** Consecutive weeks where you hit your target. Displayed as "🔥 12-week streak"
- **Streak Freeze:** Earned every 10 logs (not purchased). Max stored: 3.
- **Grace Period:** Miss a week → next week starts at "1" (not "0") with a welcome-back nudge.
- **No shame:** Missed streaks are never displayed. Counter only shows current positive streak.

**Why 5/week (not 7):** People don't spend money every day. A 7-day target guarantees failure. 5/week means weekends off, travel days off — and the streak still feels earned.

### IV. Three-Phase Variable Rewards

The reward for expense tracking is **insight**, not points.

1. **Anticipation:** The weekly ring fills as you log. At 80%, a subtle glow appears — "almost there."
2. **Reveal:** Ring completes → a "Weekly Insight" card appears. Variable outcomes.
3. **Celebration:** Haptic + ripple burst + the insight card with a share button.

**Variable Insight Types:**
- Common (60%): Category Spotlight, Week Comparison
- Uncommon (30%): Pattern Discovery
- Rare (10%): Milestone

### V. Gestalt Closure

The human brain hates incomplete circles. A 90% filled ring creates an intuitive itch to finish.

- **Weekly Spending Ring:** Circular progress on home screen (like Apple Watch Activity Rings)
- **Placement:** Below the status line, above the zen stone. Small (60pt), always visible.
- **Color:** Sage green when progressing, gold when a freeze is active, paper grey when reset.
- **80% threshold:** Subtle glow animation — "almost there" visual tension.
- **Completion:** Ring pulses once, then fades to a static checkmark for the rest of the week.

### VI. Competence Metrics

Not "you opened the app 5 times" — that's participation theater. Real competence is **financial awareness**.

- **Spending Trend:** "You spent $1,247 this month — 8% less than last month."
- **Tracking Streak:** "12-week streak" — earned by consistent behavior.
- **Pattern Recognition:** "You've identified 3 recurring expenses this month."
- **Volume Milestones:** "100th log" — celebrates real usage, not time-based attendance.

**The key difference:** A badge says "you clicked a button." A competence metric says "you became more financially aware."

### VII. Micro Social Validation

No friend lists, no feeds, no competitive rankings. Just **one-tap sharing of genuine financial insight**.

- **Monthly Summary Card:** Beautiful zen-styled card with total spent, top category, streak count, comparison to last month.
- **1-tap share:** iMessage, Instagram Stories, WhatsApp. No "Post to Facebook" dialogs.
- **Privacy:** Shows YOUR data only. No friend comparisons unless both opt in.

**The social signal:** "I track my expenses" is a status signal. The card validates financial discipline, not gaming achievement.

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-2)

The minimum viable retention layer. Zero new UI — just data collection and a single home screen element.

- [ ] Weekly log count tracking (days with ≥1 log per week)
- [ ] Weekly spending ring on home screen (60pt, below status line)
- [ ] Customizable weekly target (Settings → 3/4/5/6/7 days)
- [ ] Basic streak counter (consecutive weeks hitting target)
- [ ] Streak freeze: earned every 10 logs, max stored 3

### Phase 2: Rewards (Weeks 3-4)

The weekly insight reveal. Variable rewards that make ring completion feel like an event.

- [ ] Weekly Insight card (appears when ring completes)
- [ ] 4 insight types: Category Spotlight, Week Comparison, Pattern Discovery, Milestone
- [ ] Variable weighting: 60% common, 30% uncommon, 10% rare
- [ ] Haptic + ripple burst on ring completion
- [ ] "Almost there" glow at 80% ring fill

### Phase 3: Competence (Weeks 5-6)

Real financial awareness metrics. The "you became better at this" layer.

- [ ] Monthly spending trend (vs. previous month)
- [ ] Category breakdown with trend arrows (↑↓)
- [ ] "Recurring expense" detection (same category + similar amount, 3+ weeks)
- [ ] Milestone notifications: 50th log, 100th log, first $1,000 tracked
- [ ] Competence score (internal, drives insight quality — not displayed as points)

### Phase 4: Social (Weeks 7-8)

One-tap sharing of genuine financial insight. The kudos engine.

- [ ] Monthly summary card (zen-styled, data-rich)
- [ ] 1-tap share to iMessage / Instagram Stories / WhatsApp
- [ ] "Beat your average" personal challenge (weekly bar on home screen)
- [ ] Optional: share your streak count (social proof of discipline)
- [ ] No friend lists, no feeds, no competitive rankings — ever

---

## Guardrails — What We'll Never Do

| Never | Why |
|---|---|
| Virtual Currency | No coins, gems, XP, or "TapLog dollars." The currency is real money. |
| Pay-to-Progress | No streak freezes for purchase. Earned by usage, never by payment. |
| Punitive Streaks | No "you lost your 50-day streak!" shame. Grace periods and freezes only. |
| Social Pressure | No friend leaderboards, no "Sarah tracked more than you." Solo journey. |
| Notification Spam | Max 1 retention notification per week: "Your weekly insight is ready." |
| Engagement Theater | No "You opened the app 3 days in a row!" participation stickers. |

---

## Data Model Additions

### RetentionState (new SwiftData model)

```swift
@Model
final class RetentionState {
    var weeklyTarget: Int           // 3-7, default 5
    var currentStreak: Int          // consecutive weeks hitting target
    var longestStreak: Int          // all-time best
    var streakFreezes: Int          // 0-3, earned every 10 logs
    var totalLogs: Int              // lifetime log count
    var lastWeekCompleted: Date?    // when the streak was last extended
}
```

### Weekly Log Tracking

Tracked via `@AppStorage` keys (lightweight, no new model needed):
- `weeklyLogDays`: [Bool] — 7 booleans for Mon-Sun, reset each Monday
- `weekStartDate`: Date — when the current week started (for Monday detection)

---

*Design document v1.0 — Built on the Gamification & Retention Playbook mechanics*
