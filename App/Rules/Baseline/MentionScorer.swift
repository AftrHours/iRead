import Foundation

enum MentionScorer {
    static func score(_ mentions: [ResolvedMention], against document: LitBankDocument, aligned: AlignedText,
                      in content: BookContent, label: String = "PER") -> MentionScore {
        let chapterText = content.chapters[aligned.chapter].text as NSString
        let gold = document.spans.filter { $0.label == label }.compactMap { goldRange($0, aligned: aligned) }
        let predicted = mentions.compactMap { predictedRange($0, aligned: aligned, in: content) }

        var unusedGold = Array(gold.indices)
        var unusedPredicted = Array(predicted.indices)
        var exact = 0
        var overlapping = 0
        for g in gold.indices {
            guard let p = unusedPredicted.first(where: { predicted[$0] == gold[g] }) else { continue }
            exact += 1
            unusedGold.removeAll { $0 == g }
            unusedPredicted.removeAll { $0 == p }
        }
        for g in unusedGold {
            guard let p = unusedPredicted.first(where: { NSIntersectionRange(predicted[$0], gold[g]).length > 0 }) else { continue }
            overlapping += 1
            unusedGold.removeAll { $0 == g }
            unusedPredicted.removeAll { $0 == p }
        }
        func counts(matched: Int) -> MentionCounts {
            MentionCounts(truePositives: matched, falsePositives: predicted.count - matched, falseNegatives: gold.count - matched)
        }
        return MentionScore(exact: counts(matched: exact), overlap: counts(matched: exact + overlapping),
                            missed: unusedGold.map { chapterText.substring(with: gold[$0]) },
                            spurious: unusedPredicted.map { chapterText.substring(with: predicted[$0]) })
    }

    private static func goldRange(_ span: LitBankSpan, aligned: AlignedText) -> NSRange? {
        let ranges = aligned.tokenRanges[span.firstToken...span.lastToken].compactMap { $0 }
        guard let first = ranges.first, let last = ranges.last else { return nil }
        return NSRange(location: first.location, length: last.location + last.length - first.location)
    }

    private static func predictedRange(_ mention: ResolvedMention, aligned: AlignedText, in content: BookContent) -> NSRange? {
        let sentence = content.sentences[mention.sentence]
        let paragraph = content.paragraphs[sentence.paragraph]
        guard paragraph.chapterIndex == aligned.chapter else { return nil }
        let range = NSRange(location: paragraph.range.location + sentence.range.location + mention.location, length: mention.length)
        guard NSIntersectionRange(range, aligned.window) == range else { return nil }
        return range
    }
}
