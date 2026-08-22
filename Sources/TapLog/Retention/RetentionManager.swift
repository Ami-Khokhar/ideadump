import Foundation
import SwiftData

/// Tracks weekly log consistency, streaks, and streak freezes.
///
/// Uses `UserDefaults` for lightweight persistence (no new SwiftData model needed).
/// The weekly log mask resets automatically when a new Monday is detected.
@Observable
final class RetentionManager {
    private let defaults = UserDefaults.standard

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

    /// The Monday of the current tracking week.
    private var weekStartDate: Date {
        get {
            if let stored = defaults.object(forKey: Keys.weekStartDate) as? Date {
                return stored
            }
            let monday = Self.currentMonday()
            defaults.set(monday, forKey: Keys.weekStartDate)
            return monday
        }
        set { defaults.set(newValue, forKey: Keys.weekStartDate) }
    }

    /// 7-element array: index 0 = Monday … 6 = Sunday. `true` = logged that day.
    private var weeklyMask: [Bool] {
        get { (defaults.array(forKey: Keys.weeklyMask) as? [Bool]) ?? Array(repeating: false, count: 7) }
        set { defaults.set(newValue, forKey: Keys.weeklyMask) }
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

    /// Progress toward the weekly target (0.0 … 1.0+).
    var weeklyProgress: Double {
        Double(daysLoggedThisWeek) / Double(weeklyTarget)
    }

    /// Fraction of the ring that should be filled (capped at 1.0 for visual).
    var ringFraction: Double {
        min(1.0, weeklyProgress)
    }

    // MARK: - Actions

    /// Call once after every successful log. Updates the weekly mask and checks
    /// whether a streak should be extended or a freeze consumed.
    func recordLogDay() {
        refreshWeekIfNeeded()
        let today = Calendar.current.component(.weekday, from: Date())
        // weekday: 1=Sun … 7=Sat → mask index: Mon=0 … Sun=6
        let index = (today + 5) % 7
        var mask = weeklyMask
        mask[index] = true
        weeklyMask = mask

        totalLogs += 1

        // If target just got hit this log, check if last week's streak needs resolving.
        if targetMet && !defaults.bool(forKey: Keys.weekResolved) {
            extendStreak()
        }
    }

    /// Consume one streak freeze to save the current week. Returns `true` if successful.
    func useStreakFreeze() -> Bool {
        guard streakFreezes > 0, !targetMet else { return false }
        streakFreezes -= 1
        markWeekResolved(saved: true)
        return true
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
    }

    private static func currentMonday() -> Date {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        // Days since Monday: Mon=2 → 0, Tue=3 → 1, … Sun=1 → 6
        let daysSinceMonday = (weekday + 5) % 7
        return cal.startOfDay(for: cal.date(byAdding: .day, value: -daysSinceMonday, to: now)!)
    }

    /// If we've crossed into a new week, resolve last week's streak and reset.
    private func refreshWeekIfNeeded() {
        let thisMonday = Self.currentMonday()
        guard thisMonday > weekStartDate else { return }

        // New week — resolve the old one if not already done.
        if !defaults.bool(forKey: Keys.weekResolved) {
            resolveLastWeek()
        }

        // Reset for the new week.
        weekStartDate = thisMonday
        weeklyMask = Array(repeating: false, count: 7)
        defaults.set(false, forKey: Keys.weekResolved)
    }

    /// Called when the current week's target is first met — extends streak if
    /// the previous week was also completed.
    private func extendStreak() {
        currentStreak += 1
        markWeekResolved(saved: false)
    }

    /// Called when a week ends without meeting the target.
    private func resolveLastWeek() {
        if targetMet {
            extendStreak()
        } else {
            // Streak broken — offer a freeze opportunity.
            // (The UI handles the freeze prompt; here we just reset.)
            currentStreak = 0
        }
        markWeekResolved(saved: targetMet)
    }

    private func markWeekResolved(saved: Bool) {
        defaults.set(true, forKey: Keys.weekResolved)
    }
}
