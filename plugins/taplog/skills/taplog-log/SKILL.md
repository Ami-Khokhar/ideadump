---
name: taplog-log
description: Prepare TapLog capture links for purchases the person describes in chat, such as "log 40 for chai and 250 for lunch". Use when the person wants to record expenses in TapLog from a conversation, a receipt, or a payment message.
---

TapLog saves entries only on the person's iPhone. This workflow does not save
anything. It prepares `taplog://` links that open TapLog's capture form with the
amount, category, and note filled in. The person taps **Log** in the app.

Explicit instructions from the person override this skill.

## Steps

1. Pull each purchase out of the message: amount, category, optional note
   (merchant or item). One link per purchase, at most 10 per call.
2. Amounts must be plain numbers with at most two decimals: `1200`, `12.50`.
   Remove currency symbols and thousands separators yourself ("₹1,200" → `1200`).
   If an amount is ambiguous ("1.200", "a few hundred"), ask. Do not guess.
3. Use the category as the person said it ("chai", "auto"). TapLog matches it to
   their own category list. Do not invent a category when none was given; leave
   it out.
4. Call `prepare_log_links` once with all purchases.
5. Reply in one line: tap each link on your iPhone, then tap Log.

## What not to say

- Never say an expense was "logged", "saved", or "added". It is saved only when
  the person taps Log on their phone.
- Do not offer to remember the expenses or keep a running total in chat. TapLog
  is where their record lives.
- If a payment message is shared (bank SMS, UPI alert), take only the amount and
  merchant. Do not repeat account numbers or balances.
