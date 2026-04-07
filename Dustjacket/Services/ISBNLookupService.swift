import Foundation

struct ISBNLookupService {
    private let hardcoverService: HardcoverServiceProtocol

    init(hardcoverService: HardcoverServiceProtocol) {
        self.hardcoverService = hardcoverService
    }

    func lookup(isbn: String) async throws -> Edition? {
        let normalized = normalizeISBN(isbn)
        let editions = try await hardcoverService.getEditionByISBN(normalized)
        return editions.first.map { Edition(from: $0) }
    }

    /// Convert ISBN-10 to ISBN-13, or clean up ISBN-13
    private func normalizeISBN(_ isbn: String) -> String {
        let digits = isbn.filter(\.isNumber)

        if digits.count == 13 {
            return digits
        }

        if digits.count == 10 {
            return convertISBN10to13(digits)
        }

        // Return as-is for other lengths
        return digits
    }

    private func convertISBN10to13(_ isbn10: String) -> String {
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
        // First: look for "ISBN" prefix followed by a number with optional dashes/spaces
        let isbnPrefixPattern = "ISBN[:\\s-]*([0-9][0-9\\s-]{8,17}[0-9Xx])"
        if let regex = try? NSRegularExpression(pattern: isbnPrefixPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: text) {
            let digits = String(text[range]).filter { $0.isNumber || $0 == "X" || $0 == "x" }
            if digits.count == 10 || digits.count == 13 {
                return digits
            }
        }

        // Second: look for bare ISBN-13 (with or without dashes)
        let isbn13Pattern = "97[89][0-9\\s-]{10,17}"
        if let regex = try? NSRegularExpression(pattern: isbn13Pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            let digits = String(text[range]).filter(\.isNumber)
            if digits.count == 13 {
                return digits
            }
        }

        // Third: look for bare ISBN-10 (10 consecutive digits/X)
        let isbn10Pattern = "\\d{9}[\\dXx]"
        if let regex = try? NSRegularExpression(pattern: isbn10Pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            return String(text[range])
        }

        return nil
    }
}
