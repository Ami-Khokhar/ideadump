import XCTest
@testable import TapLog

/// The paywall shows the user's own record instead of invented trees. These pin
/// what counts, what doesn't, and when the record is too thin to be worth showing.
final class PaywallEvidenceTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return c
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: Date(timeIntervalSince1970: 1_780_000_000))!
    }

    func testCountsEntriesDistinctDaysAndTotal() {
        let entries = [
            Entry(amount: 40, category: "chai", date: day(0)),
            Entry(amount: 60, category: "food", date: day(0)),   // same day
            Entry(amount: 100, category: "metro", date: day(1)),
            Entry(amount: 200, category: "rent", date: day(5)),
        ]

        let evidence = PaywallEvidence.make(entries: entries, calendar: calendar)

        XCTAssertEqual(evidence.entryCount, 4)
        XCTAssertEqual(evidence.dayCount, 3, "two entries on one day are one day")
        XCTAssertEqual(evidence.tracked, 400)
    }

    func testArchivedAndPendingEntriesDoNotCount() {
        // The same exclusion every other screen applies: a pending share-sheet
        // entry is not yet the user's record, and an archived one is withdrawn.
        let entries = [
            Entry(amount: 40, category: "chai", date: day(0)),
            Entry(amount: 999, category: "chai", date: day(1), isArchived: true),
            Entry(amount: 999, category: "chai", date: day(2), isPending: true),
        ]

        let evidence = PaywallEvidence.make(entries: entries, calendar: calendar)

        XCTAssertEqual(evidence.entryCount, 1)
        XCTAssertEqual(evidence.dayCount, 1)
        XCTAssertEqual(evidence.tracked, 40, "an archived or pending amount must not inflate the total")
    }

    func testThinRecordIsNotShown() {
        // Telling someone who has logged twice that they have logged twice is an
        // argument against paying, so the paywall falls back to describing Pro.
        let twoLogs = (0..<2).map { Entry(amount: 10, category: "chai", date: day($0)) }
        XCTAssertFalse(PaywallEvidence.make(entries: twoLogs, calendar: calendar).isWorthShowing)

        // Enough entries, but all on one afternoon — not yet a habit.
        let oneDayBurst = (0..<12).map { _ in Entry(amount: 10, category: "chai", date: day(0)) }
        XCTAssertFalse(PaywallEvidence.make(entries: oneDayBurst, calendar: calendar).isWorthShowing)

        let realRecord = (0..<10).map { Entry(amount: 10, category: "chai", date: day($0)) }
        XCTAssertTrue(PaywallEvidence.make(entries: realRecord, calendar: calendar).isWorthShowing)
    }

    func testEmptyStoreIsSafe() {
        let evidence = PaywallEvidence.make(entries: [], calendar: calendar)
        XCTAssertEqual(evidence.entryCount, 0)
        XCTAssertEqual(evidence.dayCount, 0)
        XCTAssertEqual(evidence.tracked, 0)
        XCTAssertFalse(evidence.isWorthShowing)
    }

    func testSummaryLineSingularAndPlural() {
        let single = PaywallEvidence(entryCount: 1, dayCount: 1, tracked: 40)
        XCTAssertTrue(single.summaryLine.contains("1 expense ·"), single.summaryLine)
        XCTAssertTrue(single.summaryLine.contains("1 day ·"), single.summaryLine)

        let many = PaywallEvidence(entryCount: 143, dayCount: 24, tracked: 18_400)
        XCTAssertTrue(many.summaryLine.contains("143 expenses"), many.summaryLine)
        XCTAssertTrue(many.summaryLine.contains("24 days"), many.summaryLine)
        XCTAssertTrue(many.summaryLine.hasSuffix("tracked"), many.summaryLine)
    }
}
