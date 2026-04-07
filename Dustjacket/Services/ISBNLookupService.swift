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

    /// Extract ISBN from a raw text string (e.g., OCR result)
    static func extractISBN(from text: String) -> String? {
        let patterns = [
            "97[89]\\d{10}",   // ISBN-13
            "\\d{9}[\\dXx]"    // ISBN-10
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                return String(text[range])
            }
        }

        return nil
    }
}
