#if DEBUG
import Foundation
import UnderlineEngine

/// What the debug screen lists: how the run is going, and every underlined sentence by chapter.
struct EngineDebugReport {
    let summary: [EngineDebugRow]
    let chapters: [EngineDebugChapter]
    let currentChapter: Int?

    init(progress: UnderlineProgress?, underlines: [Underline], dropped: [Int: [DroppedPhrase]], content: BookContent, currentChapter: Int?, now: Date = .now) {
        let droppedCount = dropped.values.map(\.count).reduce(0, +)
        summary = Self.summary(progress: progress, underlineCount: underlines.count, droppedCount: droppedCount, content: content, now: now)
        chapters = Self.chapters(progress: progress, underlines: underlines, dropped: dropped, content: content)
        self.currentChapter = currentChapter
    }

    private static func summary(progress: UnderlineProgress?, underlineCount: Int, droppedCount: Int, content: BookContent, now: Date) -> [EngineDebugRow] {
        guard let progress else { return [EngineDebugRow(label: "Status", value: "Not started")] }
        var rows = [
            EngineDebugRow(label: "Status", value: phaseText(progress, content: content, now: now)),
            EngineDebugRow(label: "Path", value: progress.usesModel ? "Foundation Models" : "Rules only (no model)"),
            EngineDebugRow(label: "Chapters done", value: "\(progress.doneChapters.count) of \(progress.chapterCount)"),
            EngineDebugRow(label: "Underlines", value: "\(underlineCount)"),
            EngineDebugRow(label: "Dropped phrases", value: "\(droppedCount)")
        ]
        if progress.phase == .modelNotAnswering {
            rows.append(EngineDebugRow(label: "Note", value: "Nothing was saved for this chapter. It runs again when the book opens."))
        }
        return rows
    }

    private static func phaseText(_ progress: UnderlineProgress, content: BookContent, now: Date) -> String {
        switch progress.phase {
        case .loading: "Loading saved chapters"
        case .working(let chapter):
            "Working on \(content.chapters[chapter].title), \(Duration.seconds(now.timeIntervalSince(progress.workingSince ?? now)).formatted(.time(pattern: .minuteSecond)))"
        case .paused: "Paused: device is hot or in Low Power Mode"
        case .finished: "Finished"
        case .modelNotAnswering: "Stopped: the model isn't answering"
        case .stopped: "Stopped: app left the book"
        }
    }

    private static func chapters(progress: UnderlineProgress?, underlines: [Underline], dropped: [Int: [DroppedPhrase]], content: BookContent) -> [EngineDebugChapter] {
        let byChapter = Dictionary(grouping: underlines) { content.paragraphs[$0.paragraph].chapterIndex }
        return content.chapters.indices.map { index in
            let found = (byChapter[index] ?? []).sorted { ($0.sentence, $0.range.location) < ($1.sentence, $1.range.location) }
            return EngineDebugChapter(
                id: index,
                title: content.chapters[index].title,
                status: status(of: index, count: found.count, progress: progress),
                underlines: found.map { row(for: $0, content: content) },
                drops: drops(dropped[index] ?? [])
            )
        }
    }

    /// Grouped by reason, the most common first.
    private static func drops(_ phrases: [DroppedPhrase]) -> [EngineDebugDrops] {
        Dictionary(grouping: phrases, by: \.reason)
            .map { reason, phrases in
                EngineDebugDrops(reason: text(for: reason), phrases: phrases.sorted { $0.sentence < $1.sentence }.map { "s\($0.sentence): \($0.phrase)" })
            }
            .sorted { ($0.phrases.count, $1.reason) > ($1.phrases.count, $0.reason) }
    }

    private static func text(for reason: DropReason) -> String {
        switch reason {
        case .noCandidate: "No earlier sentence scored high enough"
        case .pickedNone: "Picked no sentence"
        case .confirmRejected: "Confirm said it doesn't explain the phrase"
        case .guardRejected: "Guard rejected the pick"
        case .densityLimit: "Over the limit for its paragraph"
        case .modelFailed: "Model call failed"
        }
    }

    private static func status(of chapter: Int, count: Int, progress: UnderlineProgress?) -> String {
        if progress?.doneChapters.contains(chapter) == true { return "Done, \(count)" }
        if progress?.phase == .working(chapter: chapter) { return "Working, \(count) so far" }
        return count > 0 ? "Not finished, \(count) so far" : "Not done"
    }

    private static func row(for underline: Underline, content: BookContent) -> EngineDebugUnderline {
        EngineDebugUnderline(
            id: underline.id,
            label: "s\(underline.sentence) · \(underline.kind.rawValue) · \(underline.decidedBy.rawValue)",
            sentence: sentence(of: underline, content: content),
            reference: underline.reference.text,
            referenceLabel: "s\(underline.reference.sentence)"
        )
    }

    /// The sentence with its phrase in bold. Falls back to the phrase alone if the indexes don't line up.
    private static func sentence(of underline: Underline, content: BookContent) -> AttributedString {
        var phrase = AttributedString(underline.text)
        phrase.inlinePresentationIntent = .stronglyEmphasized
        guard content.sentences.indices.contains(underline.sentence) else { return phrase }
        let sentenceRange = content.sentences[underline.sentence].range
        let paragraph = content.paragraphs[underline.paragraph]
        let chapter = content.chapters[paragraph.chapterIndex].text as NSString
        let text = chapter.substring(with: paragraph.range) as NSString
        let start = underline.range.location - sentenceRange.location
        guard NSMaxRange(sentenceRange) <= text.length, start >= 0, start + underline.range.length <= sentenceRange.length else { return phrase }
        let sentence = text.substring(with: sentenceRange) as NSString
        let after = start + underline.range.length
        return AttributedString(sentence.substring(to: start)) + phrase + AttributedString(sentence.substring(from: after))
    }
}
#endif
