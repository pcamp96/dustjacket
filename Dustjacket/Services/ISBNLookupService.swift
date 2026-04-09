import Foundation

struct ISBNLookupService {
    private let hardcoverService: HardcoverServiceProtocol

    init(hardcoverService: HardcoverServiceProtocol) {
        self.hardcoverService = hardcoverService
    }

    func lookup(isbn: String) async throws -> Edition? {
        guard let cleaned = Self.normalizedISBN(from: isbn) else {
            return nil
        }

        // Try the cleaned ISBN directly first (works for both ISBN-10 and ISBN-13)
        let editions = try await hardcoverService.getEditionByISBN(cleaned)
        if let first = editions.first {
            return Edition(from: first)
        }

        // If ISBN-10, also try the converted ISBN-13
        if cleaned.count == 10 {
            let isbn13 = convertISBN10to13(cleaned)
            let editions13 = try await hardcoverService.getEditionByISBN(isbn13)
            if let first = editions13.first {
                return Edition(from: first)
            }
        }

        return nil
    }

    static func normalizedISBN(from rawValue: String) -> String? {
        if let extracted = extractISBN(from: rawValue) {
            return extracted
        }

        let cleaned = rawValue.filter { $0.isNumber || $0 == "X" || $0 == "x" }.uppercased()
        guard cleaned.count == 10 || cleaned.count == 13 else { return nil }
        return isValidISBN(cleaned) ? cleaned : nil
    }

    func convertISBN10to13(_ isbn10: String) -> String {
        let prefix = "978"
        let base = prefix + isbn10.dropLast()
        let digits = base.compactMap { $0.wholeNumberValue }

        var sum = 0
        for (index, digit) in digits.enumerated() {
            sum += digit * (index.isMultiple(of: 2) ? 1 : 3)
        }
        let checkDigit = (10 - (sum % 10)) % 10

        return base + "\(checkDigit)"
    }

    /// Extract ISBN from a raw text string (e.g., OCR result or live text)
    /// Handles formats like: "ISBN 0-02-086740-9", "978-0-123456-78-9", "9780123456789"
    static func extractISBN(from text: String) -> String? {
        let patterns = [
            #"(?i)ISBN(?:-1[03])?[:\s]*((?:97[89](?:[\s-]*\d){10})|(?:\d(?:[\s-]*\d){8}[\s-]*[\dXx]))"#,
            #"((?:97[89](?:[\s-]*\d){10}))"#,
            #"((?:\d(?:[\s-]*\d){8}[\s-]*[\dXx]))"#
        ]

        for pattern in patterns {
            let matches = matches(in: text, pattern: pattern)
            for match in matches {
                let cleaned = match.filter { $0.isNumber || $0 == "X" || $0 == "x" }.uppercased()
                if isValidISBN(cleaned) {
                    return cleaned
                }
            }
        }

        return nil
    }

    static func likelyContainsISBN(_ text: String) -> Bool {
        if text.localizedCaseInsensitiveContains("isbn") {
            return true
        }

        let digitCount = text.count(where: \.isNumber)
        guard digitCount >= 9 else { return false }

        return text.contains("978") || text.contains("979") || digitCount >= 10
    }

    static func isValidISBN(_ candidate: String) -> Bool {
        switch candidate.count {
        case 10:
            isValidISBN10(candidate)
        case 13:
            isValidISBN13(candidate)
        default:
            false
        }
    }

    private static func isValidISBN10(_ candidate: String) -> Bool {
        let normalized = candidate.uppercased()
        guard normalized.count == 10 else { return false }

        var sum = 0
        for (index, character) in normalized.enumerated() {
            let value: Int
            if index == 9 && character == "X" {
                value = 10
            } else if let digit = character.wholeNumberValue {
                value = digit
            } else {
                return false
            }

            sum += value * (10 - index)
        }

        return sum.isMultiple(of: 11)
    }

    private static func isValidISBN13(_ candidate: String) -> Bool {
        guard candidate.count == 13 else { return false }
        let digits = candidate.compactMap(\.wholeNumberValue)
        guard digits.count == 13 else { return false }

        let checksum = digits.dropLast().enumerated().reduce(0) { partial, pair in
            let multiplier = pair.offset.isMultiple(of: 2) ? 1 : 3
            return partial + pair.element * multiplier
        }
        let checkDigit = (10 - (checksum % 10)) % 10
        return checkDigit == digits.last
    }

    private static func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            let captureRange: NSRange
            if match.numberOfRanges > 1, match.range(at: 1).location != NSNotFound {
                captureRange = match.range(at: 1)
            } else {
                captureRange = match.range
            }

            guard let range = Range(captureRange, in: text) else {
                return nil
            }

            return String(text[range])
        }
    }
}
