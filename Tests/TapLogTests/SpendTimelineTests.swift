import XCTest
@testable import TapLog

/// The spend widget's day boundary is arithmetic, not a render, so it can be
/// pinned here. The cases that matter are the ones a plain 24-hour addition gets
/// wrong: the two days a year where local midnight is 23 or 25 hours away.
final class SpendTimelineTests: XCTestCase {
    /// A real DST-observing zone, not a hand-rolled offset: the calendar has to
    /// decide where midnight is, or these tests prove nothing about device
    /// behaviour.
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    private let quickButtons = [
        QuickButton(amount: 10, categoryKey: "chai", emoji: "☕️", label: "☕️ 10"),
        QuickButton(amount: 120, categoryKey: "food", emoji: "🍽️", label: "🍽️ 120"),
    ]

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    private func snapshot(
        at date: Date,
        total: Decimal = 245,
        count: Int = 4
    ) -> SpendSnapshot {
        SpendSnapshot(date: date, total: total, count: count, quickButtons: quickButtons)
    }

    func testTimelineIsTodayThenTheNextLocalMidnight() {
        let now = date(2026, 6, 15, 10, 0)

        let timeline = SpendTimeline.entries(
            now: now,
            snapshot: snapshot(at: now),
            calendar: calendar
        )

        XCTAssertEqual(timeline.entries.count, 2)
        XCTAssertEqual(timeline.entries[0].date, now)
        XCTAssertEqual(timeline.entries[1].date, date(2026, 6, 16, 0, 0))
    }

    func testSpringForwardMidnightIsTwentyThreeHoursAway() {
        // 2026-03-08 is the US spring-forward day: local midnight is 23 hours
        // after the day began.
        let now = date(2026, 3, 8, 0, 30)

        let reset = SpendTimeline.entries(
            now: now,
            snapshot: snapshot(at: now),
            calendar: calendar
        ).entries[1]

        XCTAssertEqual(reset.date, date(2026, 3, 9, 0, 0))
        XCTAssertEqual(
            reset.date.timeIntervalSince(calendar.startOfDay(for: now)),
            TimeInterval(23 * 3_600),
            accuracy: 0.5,
            "a device would roll over an hour early if the reset assumed 24 hours"
        )
        XCTAssertGreaterThan(reset.date, now)
    }

    func testFallBackMidnightIsTwentyFiveHoursAway() {
        // 2026-11-01 is the US fall-back day: local midnight is 25 hours after
        // the day began.
        let now = date(2026, 11, 1, 0, 30)

        let reset = SpendTimeline.entries(
            now: now,
            snapshot: snapshot(at: now),
            calendar: calendar
        ).entries[1]

        XCTAssertEqual(reset.date, date(2026, 11, 2, 0, 0))
        XCTAssertEqual(
            reset.date.timeIntervalSince(calendar.startOfDay(for: now)),
            TimeInterval(25 * 3_600),
            accuracy: 0.5,
            "a device would roll over an hour late if the reset assumed 24 hours"
        )
        XCTAssertGreaterThan(reset.date, now)
    }

    func testResetEntryZeroesTotalsAndKeepsLearnedButtons() {
        let now = date(2026, 6, 15, 10, 0)
        let today = snapshot(at: now, total: Decimal(string: "245.50")!, count: 4)

        let reset = SpendTimeline.entries(
            now: now,
            snapshot: today,
            calendar: calendar
        ).entries[1]

        XCTAssertEqual(reset.total, 0)
        XCTAssertEqual(reset.count, 0)
        XCTAssertEqual(
            reset.quickButtons,
            today.quickButtons,
            "the learned quick buttons are not a daily total and must survive midnight"
        )
    }

    func testRefreshIsThirtyMinutesLaterMidDay() {
        let now = date(2026, 6, 15, 10, 0)

        let refreshAfter = SpendTimeline.entries(
            now: now,
            snapshot: snapshot(at: now),
            calendar: calendar
        ).refreshAfter

        XCTAssertEqual(refreshAfter, date(2026, 6, 15, 10, 30))
    }

    func testRefreshStopsAtMidnightWhenTheDayIsNearlyOver() {
        let now = date(2026, 6, 15, 23, 50)

        let refreshAfter = SpendTimeline.entries(
            now: now,
            snapshot: snapshot(at: now),
            calendar: calendar
        ).refreshAfter

        XCTAssertEqual(
            refreshAfter,
            date(2026, 6, 16, 0, 0),
            "asking past midnight would cross the boundary instead of landing on it"
        )
    }

    func testEntriesAreStrictlyAscending() {
        let now = date(2026, 6, 15, 10, 0)

        let entries = SpendTimeline.entries(
            now: now,
            snapshot: snapshot(at: now),
            calendar: calendar
        ).entries

        XCTAssertLessThan(entries[0].date, entries[1].date)
    }
}
