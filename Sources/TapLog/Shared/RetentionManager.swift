import Foundation
import SwiftData

/// Tracks weekly log consistency, streaks, and streak freezes.
///
/// Uses `UserDefaults` for lightweight persistence (no new SwiftData model needed).
/// The weekly log mask resets automatically when a new week is detected, using
/// the user's own first weekday rather than a hardcoded Monday.
///
/// ## Freeze semantics
/// A freeze and a target completion are tracked as separate resolutions:
/// - `weekFrozen`: set when `useStreakFreeze()` is called during the current week.
/// - `weekResolved`: set when the weekly target is met via `extendStreak()`.
///
/// Both independently prevent the streak from breaking during `refreshWeekIfNeeded`.
/// Crucially, using a freeze does **not** prevent a later target completion from
/// extending the streak — if the user first freezes and then meets the target in
/// the same week, the streak is extended.
@Observable
final class RetentionManager {
    private let defaults: UserDefaults
    /// The calendar every week boundary is measured in. Injected so tests can pin
    /// `firstWeekday` — a streak that only works on the tester's locale is a
    /// streak that breaks for half the users.
    private let calendar: Calendar

    /// All state lives in the given defaults — the App Group suite by default, so a
    /// log recorded from the widget or Siri counts toward the same streaks as one
    /// recorded in the app.
    init(defaults: UserDefaults = StoreLocator.sharedDefaults, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    // MARK: - Legacy migration

    /// One-time move of retention state from `UserDefaults.standard` — where it
    /// lived before captures were shared via the App Group suite — into `target`.
    ///
    /// Production calls this at the process entry points that read or write
    /// retention state (app launch, capture bookkeeping). Existing keys in the
    /// target always win, so a user who already logged from the widget never has
    /// their newer progress clobbered by older app-side values.
    static func migrateLegacyStateIfNeeded(
        target: UserDefaults,
        legacy: UserDefaults = .standard
    ) {
        guard !target.bool(forKey: Keys.legacyMigrated) else { return }
        target.set(true, forKey: Keys.legacyMigrated)

        for key in Keys.allStorageKeys + ["logsLogged"] {
            if let value = legacy.object(forKey: key), target.object(forKey: key) == nil {
                target.set(value, forKey: key)
            }
        }
    }

    // MARK: - Weekly Target

    /// How many days per week the user aims to log (3–7, default 5).
    var weeklyTarget: Int {
        get {
            let raw = defaults.integer(forKey: Keys.weeklyTarget)
            return raw == 0 ? 5 : max(3, min(7, raw))
        }
        set { defaults.set(max(3, min(7, newValue)), forKey: Keys.weeklyTarget) }
    }

    // MARK: - Streak

    /// Consecutive weeks the user has hit their target.
    var currentStreak: Int {
        get { defaults.integer(forKey: Keys.currentStreak) }
        set {
            defaults.set(newValue, forKey: Keys.currentStreak)
            if newValue > longestStreak { longestStreak = newValue }
        }
    }

    /// All-time best streak.
    var longestStreak: Int {
        get { defaults.integer(forKey: Keys.longestStreak) }
        set { defaults.set(newValue, forKey: Keys.longestStreak) }
    }

    // MARK: - Streak Freezes

    /// Number of stored streak freezes (0–3). Earned every 10 logs.
    var streakFreezes: Int {
        get { min(3, defaults.integer(forKey: Keys.streakFreezes)) }
        set { defaults.set(min(3, max(0, newValue)), forKey: Keys.streakFreezes) }
    }

    /// Total lifetime log count (used to award freezes).
    var totalLogs: Int {
        get { defaults.integer(forKey: Keys.totalLogs) }
        set {
            defaults.set(newValue, forKey: Keys.totalLogs)
            // Award a freeze every 10 logs, up to max 3.
            let newFreezes = newValue / 10
            if newFreezes > streakFreezes {
                streakFreezes = min(3, newFreezes)
            }
        }
    }

    // MARK: - Weekly Log Mask

    /// The first day of the current tracking week, in the user's own calendar.
    private var weekStartDate: Date {
        get {
            if let stored = defaults.object(forKey: Keys.weekStartDate) as? Date {
                return stored
            }
            let start = Self.weekStart(containing: Date(), calendar: calendar)
            defaults.set(start, forKey: Keys.weekStartDate)
            return start
        }
        set { defaults.set(newValue, forKey: Keys.weekStartDate) }
    }

    /// 7-element array indexed from `weekStartDate`: 0 = the week's first day …
    /// 6 = its last. `true` = logged that day.
    private var weeklyMask: [Bool] {
        get { (defaults.array(forKey: Keys.weeklyMask) as? [Bool]) ?? Array(repeating: false, count: 7) }
        set { defaults.set(newValue, forKey: Keys.weeklyMask) }
    }

    /// Whether the current week was saved by consuming a streak freeze.
    /// Separate from `weekResolved` so that a freeze does not block a later
    /// target completion from extending the streak.
    private var weekFrozen: Bool {
        get { defaults.bool(forKey: Keys.weekFrozen) }
        set { defaults.set(newValue, forKey: Keys.weekFrozen) }
    }

    // MARK: - Computed

    /// Number of days this week the user has logged (≥1 entry each).
    var daysLoggedThisWeek: Int {
        refreshWeekIfNeeded()
        return weeklyMask.filter(\.self).count
    }

    /// Whether the user has hit their target this week.
    var targetMet: Bool {
        daysLoggedThisWeek >= weeklyTarget
    }

    // MARK: - Actions

    /// Call once after every successful log. Updates the weekly mask and checks
    /// whether a streak should be extended or a freeze consumed.
    func recordLogDay() {
        refreshWeekIfNeeded()
        if let index = Self.maskIndex(for: Date(), weekStart: weekStartDate, calendar: calendar) {
            var mask = weeklyMask
            mask[index] = true
            weeklyMask = mask
        }

        totalLogs += 1

        // If target just got hit this log, check if last week's streak needs resolving.
        // A freeze can coexist with a target completion — they are independent.
        if targetMet && !defaults.bool(forKey: Keys.weekResolved) {
            extendStreak()
        }
    }

    /// Consume one streak freeze to save the current week. Returns `true` if successful.
    ///
    /// A freeze can only be used once per week, and only when the target has not
    /// already been met (to avoid wasting a freeze on a resolved week). Using a
    /// freeze does **not** prevent `recordLogDay` from later extending the streak
    /// if the target is subsequently met.
    func useStreakFreeze() -> Bool {
        guard streakFreezes > 0, !weekFrozen, !targetMet else { return false }
        streakFreezes -= 1
        weekFrozen = true
        return true
    }

    /// Inverse of `recordLogDay` for undo. Lowers lifetime totals and — when
    /// `removedDay` is given and falls inside the currently tracked week — clears
    /// that exact day's weekly bit. The caller passes the undone entry's date and
    /// omits it (nil) when another active entry still covers that day.
    ///
    /// Days from earlier, already-resolved weeks are left untouched: their
    /// outcome is baked into streak history. Streaks, resolutions, and freezes
    /// already earned are never taken away: undo removes an expense, not an
    /// achievement.
    func undoRecordLogDay(removingActiveDayFor removedDay: Date?) {
        refreshWeekIfNeeded()
        totalLogs = max(0, totalLogs - 1)

        guard let removedDay,
              let index = Self.maskIndex(for: removedDay, weekStart: weekStartDate, calendar: calendar)
        else { return }

        var mask = weeklyMask
        mask[index] = false
        weeklyMask = mask
    }

    /// Fresh start for "Delete all entries": clears every tracked value except
    /// the user's chosen weekly target (that's a preference, not progress).
    func resetAll() {
        currentStreak = 0
        longestStreak = 0
        streakFreezes = 0
        totalLogs = 0
        weekStartDate = Self.weekStart(containing: Date(), calendar: calendar)
        weeklyMask = Array(repeating: false, count: 7)
        defaults.set(false, forKey: Keys.weekResolved)
        defaults.set(false, forKey: Keys.weekFrozen)
    }

    /// The user's display-friendly streak description, or nil if streak is 0.
    var streakDescription: String? {
        guard currentStreak > 0 else { return nil }
        return "\(currentStreak)-week streak"
    }

    // MARK: - Private

    private enum Keys {
        static let weeklyTarget = "retention.weeklyTarget"
        static let currentStreak = "retention.currentStreak"
        static let longestStreak = "retention.longestStreak"
        static let streakFreezes = "retention.streakFreezes"
        static let totalLogs = "retention.totalLogs"
        static let weekStartDate = "retention.weekStartDate"
        static let weeklyMask = "retention.weeklyMask"
        static let weekResolved = "retention.weekResolved"
        static let weekFrozen = "retention.weekFrozen"
        static let legacyMigrated = "retention.legacyMigrated"
        static let weekAlignmentMigrated = "retention.weekAlignmentMigrated"

        /// Every key this manager owns — used by the legacy-state migration.
        static var allStorageKeys: [String] {
            [weeklyTarget, currentStreak, longestStreak, streakFreezes,
             totalLogs, weekStartDate, weeklyMask, weekResolved, weekFrozen]
        }
    }

    /// The first day of the week containing `date`, per `calendar.firstWeekday`.
    ///
    /// This used to be a hardcoded Monday, which put the streak on a different
    /// week to the recap for every user whose calendar starts on Sunday — a
    /// Sunday log counted toward one week in the recap and the next week in the
    /// streak.
    static func weekStart(containing date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// Where `date` sits in a mask that starts at `weekStart`, or nil when it
    /// falls outside that week. Nil rather than a clamped index: clamping would
    /// silently mark the wrong day.
    static func maskIndex(for date: Date, weekStart: Date, calendar: Calendar = .current) -> Int? {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: weekStart),
            to: calendar.startOfDay(for: date)
        ).day
        guard let days, (0...6).contains(days) else { return nil }
        return days
    }

    /// One-time realignment of a window stored by the old Monday-only code.
    ///
    /// The stored start was always a Monday and the mask was indexed from it, so
    /// the whole window simply shifts forward by the gap between the real week
    /// start and that Monday. A day that shifts past index 6 belongs to the
    /// *next* locale week and is dropped rather than wrapped: wrapping would
    /// credit a day the user has not lived yet, and dropping can only ever cost
    /// progress, never invent it.
    private func migrateWeekAlignmentIfNeeded() {
        guard !defaults.bool(forKey: Keys.weekAlignmentMigrated) else { return }
        defaults.set(true, forKey: Keys.weekAlignmentMigrated)

        guard let storedStart = defaults.object(forKey: Keys.weekStartDate) as? Date else { return }
        let alignedStart = Self.weekStart(containing: storedStart, calendar: calendar)
        guard let shift = calendar.dateComponents([.day], from: alignedStart, to: storedStart).day,
              shift != 0
        else { return }

        var realigned = Array(repeating: false, count: 7)
        for (index, logged) in weeklyMask.enumerated() where logged {
            let moved = index + shift
            if moved < realigned.count { realigned[moved] = true }
        }
        weeklyMask = realigned
        weekStartDate = alignedStart
    }

    /// If we've crossed into a new week, resolve last week's streak and reset.
    ///
    /// Snapshot the prior window before replacing it so its result cannot be
    /// accidentally written into the new week's resolution flag.
    private func refreshWeekIfNeeded() {
        migrateWeekAlignmentIfNeeded()
        let thisWeekStart = Self.weekStart(containing: Date(), calendar: calendar)
        guard thisWeekStart > weekStartDate else { return }

        // Snapshot last week before wiping it — once the mask resets, the old
        // week's data is gone.
        let lastWeekDaysLogged = weeklyMask.filter(\.self).count
        let lastWeekTarget = weeklyTarget
        let lastWeekWasUnresolved = !defaults.bool(forKey: Keys.weekResolved)
        let lastWeekWasFrozen = defaults.bool(forKey: Keys.weekFrozen)

        // Resolve the previous week before opening the new one.
        // - Target met: increment the streak exactly once.
        // - Target missed but frozen: keep streak unchanged (no increment, no reset).
        // - Target missed and not frozen: reset streak to 0.
        if lastWeekWasUnresolved {
            if lastWeekDaysLogged >= lastWeekTarget {
                currentStreak += 1
            } else if !lastWeekWasFrozen {
                currentStreak = 0
            }
            // else: frozen but target missed → streak unchanged (preserved).
        }

        // Advance into the new week with a fresh, unresolved window.
        weekStartDate = thisWeekStart
        weeklyMask = Array(repeating: false, count: 7)
        defaults.set(false, forKey: Keys.weekResolved)
        defaults.set(false, forKey: Keys.weekFrozen)
    }

    /// Called when the current week's target is first met — extends the streak.
    private func extendStreak() {
        currentStreak += 1
        defaults.set(true, forKey: Keys.weekResolved)
    }
}
