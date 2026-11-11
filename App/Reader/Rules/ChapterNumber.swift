import Foundation

enum ChapterNumber {
    static func from(title: String) -> Int? {
        let words = title
            .replacingOccurrences(of: ".", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .map { $0.lowercased() }
        if let chapterIndex = words.firstIndex(of: "chapter"), chapterIndex + 1 < words.count {
            return number(in: words[chapterIndex + 1])
        }
    
        guard let first = words.first else { return nil }
        if let digits = Int(first) { return digits }
        let firstToken = title.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        return firstToken.hasSuffix(".") ? roman(first) : nil
    }

    private static func number(in word: String) -> Int? {
        Int(word) ?? spelled(word) ?? roman(word)
    }

    private static let ones = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
                               "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
                               "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19]
    private static let tens = ["twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70,
                               "eighty": 80, "ninety": 90]

    /// "two" → 2, "twenty-one" → 21. Up to ninety-nine.
    private static func spelled(_ word: String) -> Int? {
        let parts = word.split(separator: "-").map(String.init)
        switch parts.count {
        case 1: return ones[parts[0]] ?? tens[parts[0]]
        case 2:
            guard let ten = tens[parts[0]], let one = ones[parts[1]], one < 10 else { return nil }
            return ten + one
        default: return nil
        }
    }

    /// "ii" → 2, "xliv" → 44. Only well-formed numerals up to 399, so words like "mix" are not read as numbers.
    private static func roman(_ word: String) -> Int? {
        let values: [Character: Int] = ["i": 1, "v": 5, "x": 10, "l": 50, "c": 100]
        let digits = word.compactMap { values[$0] }
        guard !digits.isEmpty, digits.count == word.count else { return nil }
        var total = 0
        for (index, value) in digits.enumerated() {
            let next = index + 1 < digits.count ? digits[index + 1] : 0
            total += value < next ? -value : value
        }
        guard (1..<400).contains(total), romanString(total) == word else { return nil }
        return total
    }

    private static func romanString(_ number: Int) -> String {
        let table: [(Int, String)] = [(100, "c"), (90, "xc"), (50, "l"), (40, "xl"), (10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")]
        var rest = number
        var result = ""
        for (value, symbol) in table {
            while rest >= value {
                result += symbol
                rest -= value
            }
        }
        return result
    }
}
