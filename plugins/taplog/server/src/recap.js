// The weekly recap, computed the way the app's RecapMath.swift computes it:
//
// - Archived entries are history, not spend: they are counted but never totalled.
// - "This week" stops at the reference moment; a future-dated entry is not spent yet.
// - Impulse share is taken over *marked* spend only. Unmarked spend makes no
//   claim either way, so it is reported as coverage, never folded into a side.
// - Share changes are percentage *points*, never a percentage of a percentage.

const WEEKDAYS = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
const SHORT_WEEKDAY = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };

export function assertTimeZone(timeZone) {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone });
  } catch {
    throw new Error(`Unknown time zone "${timeZone}". Use an IANA name such as "Asia/Kolkata".`);
  }
}

/** The calendar day of `date` in `timeZone`, as a day number plus weekday. */
function localDay(date, timeZone) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-US", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      weekday: "short",
    })
      .formatToParts(date)
      .map((p) => [p.type, p.value])
  );
  const dayNumber = Date.UTC(Number(parts.year), Number(parts.month) - 1, Number(parts.day)) / 86_400_000;
  return { dayNumber, weekday: SHORT_WEEKDAY[parts.weekday] };
}

function isoDate(dayNumber) {
  return new Date(dayNumber * 86_400_000).toISOString().slice(0, 10);
}

function sumCents(entries) {
  return entries.reduce((total, e) => total + e.cents, 0);
}

function byCategory(entries) {
  const totals = new Map();
  for (const e of entries) totals.set(e.category, (totals.get(e.category) ?? 0) + e.cents);
  return [...totals]
    .map(([category, cents]) => ({ category, cents }))
    .sort((a, b) => b.cents - a.cents || a.category.localeCompare(b.category));
}

export function intentBreakdown(entries) {
  const result = { impulseCents: 0, plannedCents: 0, unmarkedCents: 0, markedCount: 0, entryCount: 0 };
  for (const e of entries) {
    result.entryCount += 1;
    if (e.intent === "impulse") {
      result.impulseCents += e.cents;
      result.markedCount += 1;
    } else if (e.intent === "planned") {
      result.plannedCents += e.cents;
      result.markedCount += 1;
    } else {
      result.unmarkedCents += e.cents;
    }
  }
  const marked = result.impulseCents + result.plannedCents;
  const total = marked + result.unmarkedCents;
  // Null, not zero: "0% impulse" and "you haven't said" are different statements.
  result.impulseShare = result.markedCount > 0 && marked > 0 ? result.impulseCents / marked : null;
  result.coverage = total > 0 ? marked / total : null;
  return result;
}

/**
 * Builds the recap for the week that contains `asOf`, plus the week before.
 *
 * @param {Array} entries      Output of parseTapLogCSV.
 * @param {object} options
 * @param {string} options.timeZone       IANA zone used to decide which day an entry fell on.
 * @param {string} options.weekStartsOn   "sunday" | "monday" | ... (the app follows the phone's locale).
 * @param {Date}   [options.asOf]         Reference moment. Defaults to the newest entry, so an
 *                                        export opened days later still recaps its own last week.
 */
export function buildRecap(entries, { timeZone = "UTC", weekStartsOn = "sunday", asOf } = {}) {
  assertTimeZone(timeZone);
  const firstWeekday = WEEKDAYS.indexOf(String(weekStartsOn).toLowerCase());
  if (firstWeekday < 0) throw new Error(`weekStartsOn must be a weekday name, got "${weekStartsOn}".`);

  const counted = entries.filter((e) => !e.archived);
  const archivedCount = entries.length - counted.length;

  if (counted.length === 0) {
    return {
      empty: true,
      entryCount: 0,
      archivedCount,
      timeZone,
      weekStartsOn: WEEKDAYS[firstWeekday],
    };
  }

  const newest = counted.reduce((a, e) => (e.date > a ? e.date : a), counted[0].date);
  const oldest = counted.reduce((a, e) => (e.date < a ? e.date : a), counted[0].date);
  const reference = asOf ?? newest;
  const ref = localDay(reference, timeZone);
  const weekStart = ref.dayNumber - ((ref.weekday - firstWeekday + 7) % 7);
  const lastWeekStart = weekStart - 7;

  const located = counted.map((e) => ({ ...e, day: localDay(e.date, timeZone).dayNumber }));
  const thisWeek = located.filter((e) => e.day >= weekStart && e.day < weekStart + 7 && e.date <= reference);
  const lastWeek = located.filter((e) => e.day >= lastWeekStart && e.day < weekStart);

  const daily = Array.from({ length: 7 }, (_, i) => ({
    date: isoDate(weekStart + i),
    weekday: WEEKDAYS[(firstWeekday + i) % 7].slice(0, 3),
    cents: 0,
    isReferenceDay: weekStart + i === ref.dayNumber,
  }));
  for (const e of thisWeek) daily[e.day - weekStart].cents += e.cents;

  const thisTotal = sumCents(thisWeek);
  const lastTotal = sumCents(lastWeek);
  const thisIntent = intentBreakdown(thisWeek);
  const lastIntent = intentBreakdown(lastWeek);

  const lastByCategory = new Map(byCategory(lastWeek).map((c) => [c.category, c.cents]));
  const categories = byCategory(thisWeek).map((c) => ({
    ...c,
    lastWeekCents: lastByCategory.get(c.category) ?? 0,
    share: thisTotal > 0 ? c.cents / thisTotal : 0,
  }));
  // Categories that went quiet this week are worth one line in a recap too.
  const droppedCategories = [...lastByCategory]
    .filter(([category]) => !categories.some((c) => c.category === category))
    .map(([category, lastWeekCents]) => ({ category, lastWeekCents }))
    .sort((a, b) => b.lastWeekCents - a.lastWeekCents);

  return {
    empty: false,
    timeZone,
    weekStartsOn: WEEKDAYS[firstWeekday],
    asOf: reference.toISOString(),
    export: {
      entryCount: counted.length,
      archivedCount,
      firstDate: isoDate(localDay(oldest, timeZone).dayNumber),
      lastDate: isoDate(localDay(newest, timeZone).dayNumber),
      totalCents: sumCents(counted),
      categories: byCategory(counted),
    },
    thisWeek: {
      start: isoDate(weekStart),
      end: isoDate(weekStart + 6),
      totalCents: thisTotal,
      entryCount: thisWeek.length,
      daily,
      categories,
      intent: thisIntent,
    },
    lastWeek: {
      start: isoDate(lastWeekStart),
      end: isoDate(lastWeekStart + 6),
      totalCents: lastTotal,
      entryCount: lastWeek.length,
      intent: lastIntent,
    },
    change: {
      cents: thisTotal - lastTotal,
      // Null when last week had nothing: growth from zero has no percentage.
      ratio: lastTotal > 0 ? (thisTotal - lastTotal) / lastTotal : null,
      impulseSharePoints:
        thisIntent.impulseShare !== null && lastIntent.impulseShare !== null
          ? Math.round((thisIntent.impulseShare - lastIntent.impulseShare) * 1000) / 10
          : null,
    },
    droppedCategories,
  };
}
