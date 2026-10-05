import SwiftUI
import UniformTypeIdentifiers

/// A shareable CSV document (Pro feature).
struct CSVFile: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

extension CSVFile: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            try TemporaryExport.begin(text: file.text)
            return SentTransferredFile(TemporaryExport.url)
        }
    }
}

enum CSVExporter {
    static func makeCSV(entries: [Entry], lookup: CategoryLookup) -> String {
        var csv = "Date,Amount,Category,Note,Archived,Intent\n"
        // Pending share-sheet captures are provisional and must not appear in a
        // user export. Archived entries remain historical records and are included.
        for entry in entries where !entry.isPending {
            let fields = [
                entry.date.formatted(.iso8601),
                Money.plainString(entry.amount),
                quote(lookup.name(for: entry.category)),
                quote(entry.note ?? ""),
                entry.isArchived ? "yes" : "no",
                // Spelled out rather than left blank: an empty cell in a
                // spreadsheet reads as missing data, and "unmarked" is a real
                // answer that has to survive the export intact.
                entry.intent?.rawValue ?? "unmarked",
            ]
            csv += fields.joined(separator: ",") + "\n"
        }
        return csv
    }

    /// RFC 4180 quoting so commas, quotes, and newlines in notes or custom
    /// category names can never shift columns.
    ///
    /// Spreadsheet formula injection: Excel, Numbers and LibreOffice evaluate
    /// cells whose text starts with `=`, `+`, `-` or `@`. Prefixing a single
    /// quote forces the cell to be read as text. The apostrophe goes inside the
    /// quotes so the field still opens with its quote and a comma in the note
    /// cannot shift columns. Skipped characters are whitespace and C0 control
    /// characters, so `\t=` or `\u{01}=` variants are neutralized too.
    private static func quote(_ field: String) -> String {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        let value = isFormulaLeading(field) ? "'" + escaped : escaped
        return "\"\(value)\""
    }

    private static let formulaStarters: Set<Unicode.Scalar> = ["=", "+", "-", "@"]

    /// Compares the first scalar, not the first `Character`: a spreadsheet
    /// decides on the scalar, and `=` followed by a combining mark is one
    /// grapheme cluster that would otherwise be missed.
    private static func isFormulaLeading(_ field: String) -> Bool {
        let first = field.unicodeScalars.first {
            !($0.properties.isWhitespace || $0.value < 0x20 || $0.value == 0x7f)
        }
        return first.map(formulaStarters.contains) ?? false
    }
}
