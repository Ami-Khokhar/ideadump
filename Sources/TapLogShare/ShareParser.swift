import Foundation

struct ShareParse {
    let amount: Decimal?
    let note: String?
}

/// Extracts a plausible amount and merchant from a bank payment notification
/// like "CHASE: You spent $12.50 at Starbucks".
enum ShareParser {
    static func parse(_ text: String) -> ShareParse {
        guard !text.isEmpty else { return ShareParse(amount: nil, note: nil) }
        let extracted = extractAmount(from: text)
        let note = extractNote(from: text, amountString: extracted.raw)
        return ShareParse(amount: extracted.value, note: note)
    }

    private static func extractAmount(from text: String) -> (value: Decimal?, raw: String) {
        let patterns = [
            #"[$€£]\s?([0-9]+(?:\.[0-9]{1,2})?)"#,
            #"([0-9]+(?:\.[0-9]{1,2}))"#,
        ]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let raw = String(text[match])
                let cleaned = raw
                    .replacingOccurrences(of: "$", with: "")
                    .replacingOccurrences(of: "€", with: "")
                    .replacingOccurrences(of: "£", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if let value = Money.parse(cleaned) {
                    return (value, raw)
                }
            }
        }
        return (nil, "")
    }

    private static func extractNote(from text: String, amountString: String) -> String? {
        var cleaned = text
        if !amountString.isEmpty {
            cleaned = cleaned.replacingOccurrences(of: amountString, with: " ")
        }
        let stopWords: Set<String> = [
            "spent", "at", "on", "your", "you", "a", "payment", "of", "total", "for",
            "the", "with", "to", "purchase", "debit", "card", "xxx", "xxxx", "amt",
            "amount", "approved", "done", "from", "receipt", "merchant",
        ]
        var words = cleaned.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        words = words.filter { word in
            let lower = word.lowercased()
            return !stopWords.contains(lower)
                && lower.rangeOfCharacter(from: .decimalDigits) == nil
                && lower != "chase:" && lower != "bank:" && lower != "visa:" && lower != "amex:"
        }
        let note = words.prefix(4).joined(separator: " ").trimmingCharacters(in: .punctuationCharacters)
        return note.isEmpty ? nil : String(note)
    }
}
