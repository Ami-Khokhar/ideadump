---
name: taplog-recap
description: Turn a TapLog CSV export (taplog-export.csv) into a weekly spending recap — this week versus last week, where the money went, and how much was impulse. Use when the person shares a TapLog export or asks about spending they logged in TapLog.
---

TapLog is a local-first iPhone expense logger. The person's spending data lives on
their phone. It reaches this conversation only when they export it and share the
file. Treat the file as theirs: read it for this answer, do not repeat it back in
bulk, and do not suggest uploading it anywhere else.

Explicit instructions from the person override this skill.

## Steps

1. If no export is attached, tell the person how to get one: TapLog → ⋯ →
   Settings → Export CSV, then share `taplog-export.csv` here. Stop until they do.
2. Call `show_weekly_recap` once with the file as `file`.
   - `time_zone`: the person's IANA zone if you know it (India → `Asia/Kolkata`).
     If you do not know it, use `UTC` and say so in one short line, because a
     purchase after midnight can land on a different day.
   - `week_starts_on`: `sunday` for India and the US, `monday` for most of Europe.
   - `currency`: only if the person said it or it is obvious from context. The
     export has no currency column. Never guess one.
   - `as_of`: only when the person asks about a specific week.
3. The widget shows the numbers. In text, give at most four short sentences:
   the week's total and the change, the one or two categories that explain most of
   it, and the impulse read if there is one.
4. Answer follow-up questions from the same tool result. Call the tool again only
   for a different week, time zone, or file.

## What not to say

- No verdicts. Spending is a fact about a purchase, not a judgement of the person.
  Say "₹899 of it was marked impulse", not "you overspent" or "be careful".
- Impulse share covers **marked** entries only. Always say how much was unmarked.
  Never treat unmarked spend as impulse or as planned.
- A change in impulse share is in percentage **points**. 40% → 50% is "10 points
  higher", never "25% more impulsive".
- Archived entries are history and are left out of every total. Do not add them back.
- If rows were skipped, say how many. Do not guess what they contained.
- Do not compare with budgets: budgets are not in the export.
