// The model-readable half of a recap result. Plain facts in the app's voice:
// no verdicts, and every share says what it was taken over.

export function formatMoney(cents, currency) {
  const value = cents / 100;
  if (currency) {
    try {
      return new Intl.NumberFormat("en-IN", { style: "currency", currency }).format(value);
    } catch {
      // Unknown code: fall through to a plain number.
    }
  }
  return new Intl.NumberFormat("en-IN", { minimumFractionDigits: 0, maximumFractionDigits: 2 }).format(value);
}

function percent(ratio) {
  return `${Math.round(ratio * 100)}%`;
}

export function recapSummaryText({ recap, currency, skippedCount }) {
  const money = (cents) => formatMoney(cents, currency);
  const lines = [];

  if (recap.empty) {
    lines.push(
      recap.archivedCount > 0
        ? `The export holds ${recap.archivedCount} archived entries and nothing counted.`
        : "The export holds no entries yet."
    );
  } else {
    const { thisWeek, lastWeek, change } = recap;
    lines.push(`Week of ${thisWeek.start} to ${thisWeek.end} (${recap.timeZone}, weeks start ${recap.weekStartsOn}).`);
    lines.push(`Spent ${money(thisWeek.totalCents)} across ${thisWeek.entryCount} entries.`);
    if (lastWeek.entryCount === 0) {
      lines.push("Nothing was logged the week before, so there is no comparison.");
    } else {
      const direction = change.cents > 0 ? "more" : change.cents < 0 ? "less" : "the same";
      const ratio = change.ratio === null || change.cents === 0 ? "" : ` (${percent(Math.abs(change.ratio))})`;
      lines.push(
        change.cents === 0
          ? `Same as the week before (${money(lastWeek.totalCents)}).`
          : `${money(Math.abs(change.cents))} ${direction} than the week before${ratio}, which was ${money(lastWeek.totalCents)}.`
      );
    }
    if (thisWeek.categories.length) {
      lines.push(
        "By category: " +
          thisWeek.categories
            .slice(0, 6)
            .map((c) => `${c.category} ${money(c.cents)} (${percent(c.share)})`)
            .join(", ") +
          "."
      );
    }
    const intent = thisWeek.intent;
    if (intent.impulseShare === null) {
      lines.push("No entries this week are marked impulse or planned, so there is no impulse read.");
    } else {
      lines.push(
        `Impulse: ${percent(intent.impulseShare)} of marked spend (${money(intent.impulseCents)} of ${money(
          intent.impulseCents + intent.plannedCents
        )}). ${intent.markedCount} of ${intent.entryCount} entries are marked; ${money(intent.unmarkedCents)} is unmarked.`
      );
      if (change.impulseSharePoints !== null && change.impulseSharePoints !== 0) {
        lines.push(
          `That is ${Math.abs(change.impulseSharePoints)} points ${change.impulseSharePoints > 0 ? "higher" : "lower"} than the week before.`
        );
      }
    }
    if (recap.export.archivedCount > 0) {
      lines.push(`${recap.export.archivedCount} archived entries are left out of every total.`);
    }
  }
  if (skippedCount > 0) lines.push(`${skippedCount} rows could not be read and are left out.`);
  if (!currency) lines.push("The export has no currency column; amounts are shown as plain numbers.");
  return lines.join("\n");
}
