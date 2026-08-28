import Foundation

struct ShareParse {
    let amount: Decimal?
    let note: String?
}

/// Extracts a plausible amount and merchant from a bank payment notification
/// like "CHASE: You spent $12.50 at Starbucks" or "Rs 1,200 debited HDFC".
enum ShareParser {
    static func parse(_ text: String) -> ShareParse {
        guard !text.isEmpty else { return ShareParse(amount: nil, note: nil) }
        let extracted = extractAmount(from: text)
        let note = extractNote(from: text, amountString: extracted.raw)
        return ShareParse(amount: extracted.value, note: note)
    }

    /// Whether the text says money actually moved.
    ///
    /// Without this, the bare-number fallback below matched the first digits in
    /// *any* shared text, so sharing "Your OTP is 482910" filed a pending
    /// ₹482,910 expense. A share sheet that invents six-figure spending out of a
    /// one-time password is worse than one that declines to guess.
    static func mentionsSpending(_ text: String) -> Bool {
        // Roots, not prefixes: "\bpay" would match "Paytm" and "\bspen" would
        // match "Spencer", which hands the fallback right back to the OTP texts
        // it was gated against.
        let pattern = #"""
        (?i)(\bdebit|\bspent\b|\bspend\b|\bspending\b|\bpaid\b|\bpayments?\b|\brs\b|\binr\b|[₹$€£])
        """#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func extractAmount(from text: String) -> (value: Decimal?, raw: String) {
        // Group 1 captures just the number; the full match (e.g. "$12.50", "Rs 1,200")
        // is removed from the note text.
        var patterns = [
            #"[₹$€£]\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#,
            #"(?i)\brs\.?\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#,
            #"(?i)\binr\.?\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#,
        ]
        // The loose fallback only runs once the text has said money moved. It
        // still covers the symbol-less forms the patterns above miss — "You spent
        // 12.50 at Starbucks", "Amount in Rs: 1,200".
        if mentionsSpending(text) {
            patterns.append(#"([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#)
        }
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let numberRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            let raw = String(text[Range(match.range, in: text)!])
            // A matched candidate that fails validation (e.g. "$1,000,000,000"
            // exceeds the amount cap) must never degrade into a numeric fragment
            // of itself via the looser fallback patterns — bail out instead.
            guard let value = Money.parse(String(text[numberRange])) else {
                return (nil, "")
            }
            return (value, raw)
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
            "the", "with", "to", "purchase", "debit", "debited", "card", "xxx", "xxxx",
            "amt", "amount", "approved", "done", "from", "receipt", "merchant", "inr",
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
