import XCTest
@testable import TapLog

/// CSV export must be safe to open in a spreadsheet: commas, quotes, and
/// newlines inside text fields can never shift columns (RFC 4180).
final class CSVExporterTests: XCTestCase {
    private let lookup = CategoryLookup([
        SpendCategory(key: "chai", name: "Chai", emoji: "☕️"),
        SpendCategory(key: "coffee-tea", name: "Coffee, Tea", emoji: "🍵"),
    ])

    private func row(_ entry: Entry) -> [String] {
        let csv = CSVExporter.makeCSV(entries: [entry], lookup: lookup)
        let trimmed = csv.hasSuffix("\n") ? String(csv.dropLast()) : csv
        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.first, "Date,Amount,Category,Note,Archived,Intent")
        XCTAssertEqual(lines.count, 2, "one header + one data line")
        return Self.parseCSVLine(String(lines[1]))
    }

    /// Minimal RFC 4180 field parser for asserting on quoted rows.
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(line)
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if inQuotes {
                if char == "\"", index + 1 < chars.count, chars[index + 1] == "\"" {
                    field.append("\"")
                    index += 1 // skip the second quote of the escaped pair
                } else if char == "\"" {
                    inQuotes = false
                } else {
                    field.append(char)
                }
            } else {
                switch char {
                case "\"": inQuotes = true
                case ",": fields.append(field); field = ""
                default: field.append(char)
                }
            }
            index += 1
        }
        fields.append(field)
        return fields
    }

    func testPlainRowHasSixColumns() {
        let entry = Entry(amount: 12.5, category: "chai", note: "morning")
        let fields = row(entry)
        XCTAssertEqual(fields.count, 6)
        XCTAssertEqual(fields[1], "12.5")
        XCTAssertEqual(fields[2], "Chai")
        XCTAssertEqual(fields[3], "morning")
        XCTAssertEqual(fields[4], "no")
        XCTAssertEqual(fields[5], "unmarked")
        // Date round-trips through the same ISO8601 formatting the exporter uses.
        XCTAssertEqual(fields[0], entry.date.formatted(.iso8601))
    }

    func testNoteWithCommaQuoteAndNewlineIsEscaped() {
        let entry = Entry(amount: 5, category: "chai", note: "tea, extra \"hot\"\nsecond line")
        // The embedded newline rules out line-based helpers — assert the full document.
        XCTAssertEqual(
            CSVExporter.makeCSV(entries: [entry], lookup: lookup),
            "Date,Amount,Category,Note,Archived,Intent\n"
                + "\(entry.date.formatted(.iso8601)),5,\"Chai\",\"tea, extra \"\"hot\"\"\nsecond line\",no,unmarked\n"
        )
    }

    func testCustomCategoryNameContainingCommaIsEscaped() {
        let entry = Entry(amount: 40, category: "coffee-tea")
        let fields = row(entry)
        XCTAssertEqual(fields.count, 6)
        XCTAssertEqual(fields[2], "Coffee, Tea")
    }

    func testDeletedCategoryFallsBackToOther() {
        let entry = Entry(amount: 9, category: "removed-long-ago")
        XCTAssertEqual(row(entry)[2], "Other")
    }

    func testNilNoteExportsAsEmptyQuotedField() {
        let entry = Entry(amount: 3, category: "chai")
        XCTAssertEqual(row(entry)[3], "")
    }

    func testArchivedFlagExported() {
        XCTAssertEqual(row(Entry(amount: 1, category: "chai", isArchived: true))[4], "yes")
    }

    func testPendingEntriesAreExcludedFromExport() {
        let pending = Entry(amount: 1, category: "chai", isPending: true)
        XCTAssertEqual(CSVExporter.makeCSV(entries: [pending], lookup: lookup), "Date,Amount,Category,Note,Archived,Intent\n")
    }

    // MARK: - Spreadsheet formula injection

    /// Cells whose text starts with `=`, `+`, `-` or `@` are evaluated as
    /// formulas by Excel/Numbers/LibreOffice even inside quoted CSV fields.
    /// A leading apostrophe forces them to be read as text.
    func testFormulaLeadingNoteIsNeutralized() {
        for (payload, expected) in [
            ("=SUM(A1:A2)", "'=SUM(A1:A2)"),
            ("+1+1", "'+1+1"),
            ("-2 - discount", "'-2 - discount"),
            ("@everyone", "'@everyone"),
        ] {
            XCTAssertEqual(row(Entry(amount: 1, category: "chai", note: payload))[3], expected)
        }
    }

    func testWhitespaceAndControlPrefixDoNotHideFormulas() {
        for payload in [" =cmd", "\t+v", "\u{01}=x", "\u{7f}@y"] {
            let fields = row(Entry(amount: 1, category: "chai", note: payload))
            XCTAssertTrue(fields[3].hasPrefix("'"), "expected neutralized note for \(payload.debugDescription)")
        }
    }

    func testFormulaLeadingCategoryNameIsNeutralized() {
        let lookup = CategoryLookup([SpendCategory(key: "eq", name: "=DANGER", emoji: "⚠️")])
        let entry = Entry(amount: 2, category: "eq")
        let csv = CSVExporter.makeCSV(entries: [entry], lookup: lookup)
        let dataLine = csv.split(separator: "\n", omittingEmptySubsequences: false)[1]
        XCTAssertTrue(dataLine.contains("\"'=DANGER\""), "got \(dataLine)")
    }

    /// The category column goes through the same guard as the note column.
    func testWhitespaceAndControlPrefixOnCategoryIsNeutralized() {
        for name in [" =DANGER", "\t=DANGER", "\u{01}=DANGER"] {
            let lookup = CategoryLookup([SpendCategory(key: "eq", name: name, emoji: "⚠️")])
            let csv = CSVExporter.makeCSV(
                entries: [Entry(amount: 2, category: "eq")], lookup: lookup
            )
            XCTAssertTrue(
                csv.contains("'" + name),
                "expected neutralized category for \(name.debugDescription)"
            )
        }
    }

    /// A spreadsheet reads the first scalar, so `=` plus a combining mark must
    /// still be neutralized even though it is one grapheme cluster.
    func testCombiningMarkAfterStarterIsNeutralized() {
        let fields = row(Entry(amount: 1, category: "chai", note: "=\u{0301}cmd"))
        XCTAssertEqual(fields[3], "'=\u{0301}cmd")
    }

    func testOrdinaryTextIsNotPrefixedAndAmountsAreUntouched() {
        XCTAssertEqual(row(Entry(amount: -2.5, category: "chai", note: "tea time"))[1], "-2.5")
        XCTAssertEqual(row(Entry(amount: -2.5, category: "chai", note: "tea time"))[3], "tea time")
        XCTAssertEqual(row(Entry(amount: 7, category: "chai", note: "ok =later"))[3], "ok =later")
    }

    /// A spreadsheet only honors the quotes when the field opens with them, so
    /// the neutralizing apostrophe has to sit inside: a formula-leading note
    /// that also holds a comma, a quote or a newline must stay one field.
    func testFormulaLeadingNoteStaysOneWellFormedField() {
        let entry = Entry(amount: 8, category: "chai", note: "=SUM(A1,B1)")
        let csv = CSVExporter.makeCSV(entries: [entry], lookup: lookup)
        XCTAssertTrue(
            csv.hasSuffix(",\"'=SUM(A1,B1)\",no,unmarked\n"),
            "column-shifting CSV: \(csv)"
        )

        let messy = Entry(amount: 8, category: "chai", note: "=A1\"B\"\nC,D")
        let messyCSV = CSVExporter.makeCSV(entries: [messy], lookup: lookup)
        XCTAssertTrue(
            messyCSV.hasSuffix(",\"'=A1\"\"B\"\"\nC,D\",no,unmarked\n"),
            "not one quoted field: \(messyCSV)"
        )
    }

    func testUnicodeNoteSurvivesExport() {
        XCTAssertEqual(row(Entry(amount: 4, category: "chai", note: "café ☕️ – naïve"))[3], "café ☕️ – naïve")
    }

    // MARK: - Intent column

    /// The whole point of the column: an entry the user never answered for must
    /// not read as "impulse" (or as anything else) once the data leaves the app.
    func testIntentColumnDistinguishesAllThreeStates() {
        XCTAssertEqual(row(Entry(amount: 1, category: "chai", intent: .impulse))[5], "impulse")
        XCTAssertEqual(row(Entry(amount: 1, category: "chai", intent: .planned))[5], "planned")
        XCTAssertEqual(row(Entry(amount: 1, category: "chai", intent: nil))[5], "unmarked")
    }
}
