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
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("taplog-export.csv")
            try Data(file.text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

enum CSVExporter {
    static func makeCSV(entries: [Entry], lookup: CategoryLookup) -> String {
        var csv = "Date,Amount,Category,Note,Archived\n"
        for entry in entries {
            let note = (entry.note ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let fields = [
                entry.date.formatted(.iso8601),
                Money.plainString(entry.amount),
                lookup.name(for: entry.category),
                "\"\(note)\"",
                entry.isArchived ? "yes" : "no",
            ]
            csv += fields.joined(separator: ",") + "\n"
        }
        return csv
    }
}
