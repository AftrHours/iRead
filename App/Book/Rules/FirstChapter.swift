import EPUBKit
import Foundation

/// Finds the chapter where the story starts, so a book opens past its cover, copyright page and license.
enum FirstChapter {
    static let minimumWords = 300

    private static let startTitles = ["prologue", "prolog", "part one", "part 1", "book one", "book 1"]
    private static let frontMatterTitles = [
        "contents", "table of contents", "copyright", "title page", "dedication", "acknowledgement", "acknowledgements",
        "acknowledgment", "acknowledgments", "preface", "foreword", "introduction", "project gutenberg", "license", "licence",
        "cover", "colophon", "about the author", "also by", "epigraph"
    ]

    /// The first chapter, in order, that:
    /// 1. its file calls body matter;
    /// 2. is numbered 1, or is a prologue or the first part;
    /// 3. isn't front matter by its title and has at least `minimumWords` words.
    /// Chapter 0 when none does. Chapters their file calls front or back matter never count for 2 and 3.
    static func index(titles: [String], wordCounts: [Int], parts: [EPUBPart?]) -> Int {
        func part(_ index: Int) -> EPUBPart? {
            parts.indices.contains(index) ? parts[index] : nil
        }
        func isStory(_ index: Int) -> Bool {
            part(index) != .front && part(index) != .back
        }
        if let body = titles.indices.first(where: { part($0) == .body }) {
            return body
        }
        if let start = titles.indices.first(where: { isStory($0) && isStart(titles[$0]) }) {
            return start
        }
        let long = titles.indices.first { index in
            isStory(index) && !isFrontMatter(titles[index]) && wordCounts.indices.contains(index) && wordCounts[index] >= minimumWords
        }
        return long ?? 0
    }

    private static func isStart(_ title: String) -> Bool {
        if ChapterNumber.from(title: title) == 1 {
            return true
        }
        let words = normalized(title)
        return startTitles.contains { words == $0 || words.hasPrefix($0 + " ") }
    }

    private static func isFrontMatter(_ title: String) -> Bool {
        let words = " " + normalized(title) + " "
        return frontMatterTitles.contains { words.contains(" " + $0 + " ") }
    }

    /// Lowercase words only, so "Table of Contents" and "TABLE OF CONTENTS." compare equal.
    private static func normalized(_ title: String) -> String {
        title.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: " ")
    }
}
