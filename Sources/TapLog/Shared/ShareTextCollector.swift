import Foundation

/// Decides which shared text pieces reach the parser, and in which order.
///
/// The share extension only loads `NSItemProvider` payloads; this policy is a
/// pure function so `TapLogTests` can exercise it without a share sheet.
enum ShareTextCollector {
    /// One item as the share sheet offered it. `attachmentIDs` are the ids of
    /// that item's text-conforming attachments, in the order the app presented
    /// them; the caller owns the mapping from id to provider.
    struct Item: Equatable {
        let body: String?
        let attachmentIDs: [Int]
    }

    /// One reserved place in the extracted text. An attachment's payload lands in
    /// its own place, so the order the load callbacks arrive in cannot reorder
    /// the pieces the sharing app presented.
    enum Place: Equatable {
        case body(String)
        case attachment(id: Int)
    }

    /// Reserves a place for each piece that can still contribute text.
    ///
    /// A body that already carries an amount suppresses its item's attachments,
    /// because the body is the whole message. A body without an amount keeps
    /// them as a fallback after it: a rich link's body can be a summary while the
    /// payment SMS sits in a text attachment. No item contributes more than
    /// `ShareParser.maxAttachments` places in total.
    static func places(for items: [Item]) -> [Place] {
        var places: [Place] = []
        outer: for item in items {
            guard places.count < ShareParser.maxAttachments else { break }
            if let body = item.body {
                places.append(.body(body))
                if ShareParser.parse(body).amount != nil { continue }
            }
            for id in item.attachmentIDs {
                guard places.count < ShareParser.maxAttachments else { break outer }
                places.append(.attachment(id: id))
            }
        }
        return places
    }

    /// The ordered pieces the parser sees, with every place that produced no
    /// text dropped: an attachment the sheet could not load, an unsupported
    /// payload, or one whose bytes were empty or malformed UTF-8.
    static func pieces(from places: [Place], loaded: [Int: Any]) -> [String] {
        places.compactMap { place in
            switch place {
            case let .body(text):
                return text
            case let .attachment(id):
                return loaded[id].flatMap { ShareParser.nonemptyText(from: $0) }
            }
        }
    }
}
