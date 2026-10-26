import Foundation

enum LitBankAlignerKnobs {
    static let anchorTokens = 6
    static let maxLeadingTokensToSkip = 20
    static let resyncWindow = 40
}

enum LitBankAligner {
    static func align(_ document: LitBankDocument, in content: BookContent) -> AlignedText? {
        let tokens = document.tokens
        for skip in 0...LitBankAlignerKnobs.maxLeadingTokensToSkip {
            guard skip + LitBankAlignerKnobs.anchorTokens <= tokens.count else { break }
            let anchor = Array(tokens[skip..<(skip + LitBankAlignerKnobs.anchorTokens)])
            for (chapterIndex, chapter) in content.chapters.enumerated() {
                let text = chapter.text as NSString
                guard let start = firstMatch(of: anchor, in: text) else { continue }
                let ranges = ranges(of: tokens, from: skip, in: text, startingAt: start)
                let found = ranges.compactMap { $0 }
                guard let first = found.first, let last = found.last else { continue }
                return AlignedText(chapter: chapterIndex, tokenRanges: ranges,
                                   window: NSRange(location: first.location, length: last.location + last.length - first.location))
            }
        }
        return nil
    }

    private static func ranges(of tokens: [String], from skip: Int, in text: NSString, startingAt start: Int) -> [NSRange?] {
        var ranges = [NSRange?](repeating: nil, count: tokens.count)
        var cursor = start
        for index in skip..<tokens.count {
            cursor = skippingSpace(in: text, from: cursor)
            if let end = match(tokens[index], in: text, at: cursor) {
                ranges[index] = NSRange(location: cursor, length: end - cursor)
                cursor = end
                continue
            }
            let limit = min(text.length, cursor + LitBankAlignerKnobs.resyncWindow)
            for position in cursor..<limit {
                if let end = match(tokens[index], in: text, at: position) {
                    ranges[index] = NSRange(location: position, length: end - position)
                    cursor = end
                    break
                }
            }
        }
        return ranges
    }

    private static func firstMatch(of anchor: [String], in text: NSString) -> Int? {
        for start in 0..<text.length {
            var cursor = start
            var matched = true
            for token in anchor {
                cursor = skippingSpace(in: text, from: cursor)
                guard let end = match(token, in: text, at: cursor) else { matched = false; break }
                cursor = end
            }
            if matched { return start }
        }
        return nil
    }

    private static func skippingSpace(in text: NSString, from start: Int) -> Int {
        var cursor = start
        while cursor < text.length, CharacterSet.whitespacesAndNewlines.contains(Unicode.Scalar(text.character(at: cursor)) ?? "x") {
            cursor += 1
        }
        return cursor
    }

    private static func match(_ token: String, in text: NSString, at start: Int) -> Int? {
        let wanted = Array(token.utf16)
        var t = 0
        var position = start
        while t < wanted.count {
            guard position < text.length else { return nil }
            let found = text.character(at: position)
            if same(wanted[t], found) {
                t += 1
            } else if wanted[t] == 0x2D, t + 1 < wanted.count, wanted[t + 1] == 0x2D, found == 0x2014 || found == 0x2013 {
                t += 2
            } else {
                return nil
            }
            position += 1
        }
        return position
    }

    private static func same(_ a: UInt16, _ b: UInt16) -> Bool {
        if a == b { return true }
        let doubleQuotes: Set<UInt16> = [0x22, 0x201C, 0x201D]
        let singleQuotes: Set<UInt16> = [0x27, 0x2018, 0x2019]
        return (doubleQuotes.contains(a) && doubleQuotes.contains(b)) || (singleQuotes.contains(a) && singleQuotes.contains(b))
    }
}
