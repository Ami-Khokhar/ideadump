import Foundation

struct ShareParse {
    let amount: Decimal?
    let note: String?
}

/// Extracts a plausible amount and merchant from a bank payment notification
/// like "CHASE: You spent $12.50 at Starbucks" or "Rs 1,200 debited HDFC".
enum ShareParser {
    /// Limits on text that arrives from another app. A share sheet is untrusted
    /// input: the other app chooses how much it hands over, and both the parser
    /// and the label it fills run inside the share extension's memory budget.
    static let maxAttachments = 8
    static let maxFieldLength = 2_000
    static let maxTextLength = 4_000

    /// Joins the pieces a share offered into the bounded text the parser sees.
    /// Keeps the first `maxAttachments` pieces and applies the field and total
    /// caps through `cutAtTokenBoundary`, so a cap never lands inside a number:
    /// a token that straddles a cap keeps its head and loses its trailing digits,
    /// and an amount in the lost tail is declined rather than read in fragments.
    static func boundedText(_ pieces: [String]) -> String {
        var kept: [String] = []
        var total = 0
        for piece in pieces.prefix(maxAttachments) {
            let separator = kept.isEmpty ? 0 : 1
            guard total + separator < maxTextLength else { break }
            let slice = cutAtTokenBoundary(
                piece, limit: min(maxFieldLength, maxTextLength - total - separator)
            )
            kept.append(slice)
            total += slice.count + separator
        }
        return kept.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(_ text: String) -> ShareParse {
        let text = cutAtTokenBoundary(text, limit: maxTextLength)
        guard !text.isEmpty else { return ShareParse(amount: nil, note: nil) }
        let extracted = extractAmount(from: text)
        let note = extractNote(from: text, amountString: extracted.raw)
        return ShareParse(amount: extracted.value, note: note)
    }

    /// A single shared piece, trimmed to the field cap without leaving a fragment
    /// of a number. The share extension calls this as it loads each attachment,
    /// so a straddling number cannot reach the parser as a fragment.
    static func boundedPiece(_ piece: String) -> String {
        cutAtTokenBoundary(piece, limit: maxFieldLength)
    }

    /// Slices `text` to at most `limit` characters without cutting a number in
    /// half. A raw cut can leave a fragment of a number at the end —
    /// `Rs 1,234.56` cut after `Rs 1,2` parses as `1.20` — so when the cut lands
    /// inside a token, the token keeps its non-numeric head and loses its
    /// trailing run of digits, commas and dots. The head of a token cannot carry
    /// a partial number, and keeping it means a keyword beside the cut (an OTP
    /// marker, "spent") is not lost with the tail.
    static func cutAtTokenBoundary(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let cutIndex = text.index(text.startIndex, offsetBy: limit)
        let prefix = String(text[..<cutIndex])
        // What was cut decides: if it is whitespace, every token in the prefix
        // is complete and nothing needs dropping.
        if text[cutIndex].isWhitespace { return prefix }
        guard let separator = prefix.lastIndex(where: \.isWhitespace) else {
            return stripTrailingNumber(prefix)
        }
        let head = prefix[...separator]
        let partial = prefix[prefix.index(after: separator)...]
        return String(head) + stripTrailingNumber(String(partial))
    }

    /// Drops a trailing run of digits and numeric separators, so the remainder
    /// cannot be read as a partial amount.
    private static func stripTrailingNumber(_ token: String) -> String {
        var trimmed = token
        while let last = trimmed.last, last.isNumber || last == "," || last == "." {
            trimmed.removeLast()
        }
        return trimmed
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

    /// Whether the text is, or also is, a one-time code message. A bare number
    /// beside an OTP cannot be told from the code, so the loose fallback
    /// declines it even when the same text mentions a payment: refusing to log
    /// is recoverable, silently confirming the code as an expense is not.
    static func mentionsOneTimeCode(_ text: String) -> Bool {
        let pattern = #"(?i)\b(otp|one[\s-]?time\s+password|verification\s+code|security\s+code|auth(?:entication)?\s+code|\bpin\b)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func extractAmount(from text: String) -> (value: Decimal?, raw: String) {
        // An amount named with a currency symbol or word is the amount, even
        // beside a balance, a card number or an OTP, so those patterns come
        // first and the first match wins.
        let anchored = [
            #"[₹$€£]\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#,
            #"(?i)\brs\.?\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#,
            #"(?i)\binr\.?\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#,
        ]
        if let anchored = firstAmount(patterns: anchored, in: text) { return anchored }

        // The loose fallback runs only once the text has both said money moved
        // and not looked like a one-time code.
        guard mentionsSpending(text), !mentionsOneTimeCode(text) else { return (nil, "") }
        return firstAmount(patterns: [#"([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#], in: text) ?? (nil, "")
    }

    private static func firstAmount(
        patterns: [String], in text: String
    ) -> (value: Decimal?, raw: String)? {
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
        return nil
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
