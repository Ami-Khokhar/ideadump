import XCTest
@testable import TapLog

/// The temporary CSV a share hands to the system is a plain-text copy of the
/// user's expense history. These pin its lifecycle: written when a transfer
/// starts, removed when it ends (completed or cancelled), swept by a
/// delete-all — but never deleted while a transfer still holds it.
final class TemporaryExportTests: XCTestCase {
    private var fm: FileManager { FileManager.default }

    override func setUp() {
        super.setUp()
        try? fm.removeItem(at: TemporaryExport.url)
    }

    override func tearDown() {
        // Ends a transfer a failing test left active; a no-op otherwise.
        TemporaryExport.end()
        try? fm.removeItem(at: TemporaryExport.url)
        super.tearDown()
    }

    private func writeFile() throws {
        try Data("date,amount\n".utf8).write(to: TemporaryExport.url)
    }

    func testBeginWritesTheExportAndMarksTheTransferActive() throws {
        try TemporaryExport.begin(text: "Date,Amount\n2026-01-01,120\n")

        XCTAssertEqual(try String(contentsOf: TemporaryExport.url, encoding: .utf8), "Date,Amount\n2026-01-01,120\n")
        XCTAssertTrue(TemporaryExport.isTransferActive)
    }

    func testATransferThatStartedAndEndedLeavesNoFile() throws {
        try TemporaryExport.begin(text: "Date,Amount\n")

        TemporaryExport.end()
        XCTAssertFalse(TemporaryExport.isTransferActive)
        XCTAssertFalse(fm.fileExists(atPath: TemporaryExport.url.path))
    }

    /// The lock guards an order — mark active, then write — that a unit test
    /// cannot pause inside; what it does guarantee is observable here: a write
    /// that fails leaves the transfer unmarked and no file behind.
    func testAFailedWriteLeavesNoActiveTransfer() throws {
        try? fm.removeItem(at: TemporaryExport.url)
        try fm.createDirectory(at: TemporaryExport.url, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: TemporaryExport.url) }

        XCTAssertThrowsError(try TemporaryExport.begin(text: "Date,Amount\n"))
        XCTAssertFalse(TemporaryExport.isTransferActive)
    }

    func testEndRemovesTheFileAfterACompletedTransfer() throws {
        try TemporaryExport.begin(text: "Date,Amount\n")

        TemporaryExport.end()

        XCTAssertFalse(fm.fileExists(atPath: TemporaryExport.url.path))
    }

    func testEndAfterACancelledShareAlsoRemovesTheFileAndReleasesTheTransfer() throws {
        try TemporaryExport.begin(text: "Date,Amount\n")
        // A cancelled share reaches the same end() as a completed one; what
        // matters is that the transfer is released afterwards, so a later
        // sweep is allowed to run again.
        TemporaryExport.end()
        try writeFile()

        TemporaryExport.sweep()

        XCTAssertFalse(fm.fileExists(atPath: TemporaryExport.url.path), "the ended transfer must not block a later sweep")
    }

    func testEndWithoutAnActiveTransferLeavesTheFileAlone() throws {
        try writeFile()

        TemporaryExport.end()

        XCTAssertTrue(fm.fileExists(atPath: TemporaryExport.url.path), "a screen closing without a share must not delete a file it does not own")
    }

    func testSweepDuringAnActiveTransferKeepsTheFile() throws {
        try TemporaryExport.begin(text: "Date,Amount\n")

        TemporaryExport.sweep()

        XCTAssertTrue(fm.fileExists(atPath: TemporaryExport.url.path), "delete-all must not delete a file an in-flight share is handing over")
    }

    func testSweepRemovesALeftoverExportWhenNoTransferIsActive() throws {
        // A leftover from a session that ended without `end()` running.
        try writeFile()

        TemporaryExport.sweep()

        XCTAssertFalse(fm.fileExists(atPath: TemporaryExport.url.path))
    }
}
