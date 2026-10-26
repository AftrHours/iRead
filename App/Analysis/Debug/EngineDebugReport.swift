#if DEBUG
import SwiftUI

enum EngineDebugReport {
    static func summary(of snapshot: AnalysisSnapshot) -> [EngineDebugSection] {
        let resolved = snapshot.resolved
        let content = snapshot.content
        let names = resolved.mentions.filter { $0.form == .name }.count
        let firstChapter = resolved.mentions.first.map { content.paragraphs[content.sentences[$0.sentence].paragraph].chapterIndex }
        return [
            EngineDebugSection(title: "Chapters", rows: [
                EngineDebugRow(label: "Story starts at", value: firstChapter.map { "\($0): \(content.chapters[$0].title)" } ?? "None yet"),
                EngineDebugRow(label: "Analysed", value: "\(snapshot.chaptersDone) of \(snapshot.chaptersTotal)")
            ]),
            EngineDebugSection(title: "Engine", rows: [
                EngineDebugRow(label: "Model", value: snapshot.usesModel ? "Foundation Models" : "Off: rules only"),
                EngineDebugRow(label: "Mentions", value: "\(resolved.mentions.count) (\(names) names, \(resolved.mentions.count - names) descriptions)"),
                EngineDebugRow(label: "Named characters", value: "\(resolved.entities.filter(\.isNamed).count)"),
                EngineDebugRow(label: "Described characters", value: "\(resolved.entities.filter { !$0.isNamed }.count)"),
                EngineDebugRow(label: "Linked", value: "\(resolved.linkedMentions.count)"),
                EngineDebugRow(label: "Undecided", value: "\(resolved.mentions.filter(\.isUndecided).count)"),
                EngineDebugRow(label: "Decided by model", value: "\(resolved.mentions.filter { $0.decidedBy == .model }.count)"),
                EngineDebugRow(label: "Model calls", value: "\(snapshot.modelCalls)"),
                EngineDebugRow(label: "Failed slices", value: "\(snapshot.failedSlices)")
            ]),
            EngineDebugSection(title: "On screen", rows: [
                EngineDebugRow(label: "Characters with a symbol", value: "\(snapshot.book.entities.count)"),
                EngineDebugRow(label: "Mentions", value: "\(snapshot.book.mentions.count)"),
                EngineDebugRow(label: "Underlines", value: "\(snapshot.book.mentions.filter { $0.passage != nil }.count)")
            ])
        ]
    }

    static func characters(of snapshot: AnalysisSnapshot) -> [EngineDebugCharacter] {
        let counts = Dictionary(grouping: snapshot.book.mentions, by: \.entityID).mapValues(\.count)
        return snapshot.book.entities.map { entity in
            EngineDebugCharacter(
                id: entity.id,
                name: entity.name,
                symbolName: entity.symbolName,
                color: symbolColor(for: entity),
                names: entity.names.joined(separator: ", "),
                mentionCount: counts[entity.id, default: 0],
                firstSeen: entity.appearances.first?.text ?? "No appearance description yet"
            )
        }
    }

    static func sentences(on page: Page, in snapshot: AnalysisSnapshot) -> [EngineDebugSentence] {
        let content = snapshot.content
        let entities = Dictionary(uniqueKeysWithValues: snapshot.book.entities.map { ($0.id, $0) })
        let mentionsBySentence = Dictionary(grouping: snapshot.resolved.mentions, by: \.sentence)
        return content.sentences.indices.compactMap { index in
            let sentence = content.sentences[index]
            let paragraph = content.paragraphs[sentence.paragraph]
            let range = NSRange(location: paragraph.range.location + sentence.range.location, length: sentence.range.length)
            guard paragraph.chapterIndex == page.chapterIndex, NSIntersectionRange(range, page.range).length > 0 else { return nil }
            let mentions = (mentionsBySentence[index] ?? []).sorted { $0.location < $1.location }
            let shown = mentions.map { mention in (mention, entity(of: mention, in: snapshot.resolved, shown: entities)) }
            return EngineDebugSentence(
                id: index,
                text: highlighted(SentenceText.of(sentence, in: content), mentions: shown),
                links: shown.map { link(for: $0.0, shownAs: $0.1, in: snapshot.resolved) }
            )
        }
    }

    private static func entity(of mention: ResolvedMention, in resolved: ResolvedAnalysis, shown entities: [String: Entity]) -> Entity? {
        resolved.entityKey(of: mention, asOf: mention.sentence).flatMap { entities[AnalysisMapper.id(of: $0)] }
    }

    private static func highlighted(_ text: String, mentions: [(ResolvedMention, Entity?)]) -> AttributedString {
        var result = AttributedString(text)
        for (mention, entity) in mentions {
            guard let stringRange = Range(NSRange(location: mention.location, length: mention.length), in: text),
                  let range = Range(stringRange, in: result) else { continue }
            result[range].foregroundColor = entity.map(symbolColor) ?? .secondary
            result[range].font = .body.bold()
        }
        return result
    }

    private static func link(for mention: ResolvedMention, shownAs entity: Entity?, in resolved: ResolvedAnalysis) -> String {
        let character = resolved.entityKey(of: mention, asOf: mention.sentence).flatMap { resolved.entity($0) }
        let target = character.map { "#\($0.key) \($0.label)" } ?? "no character"
        let decidedBy = switch mention.decidedBy {
        case .rule: "rule"
        case .model: "model"
        case nil: "none"
        }
        let notes = [entity == nil && character != nil ? "no symbol" : nil, mention.isUndecided ? "undecided" : nil].compactMap { $0 }
        return "“\(mention.text)” → \(target) · \(decidedBy)\(notes.isEmpty ? "" : " · " + notes.joined(separator: ", "))"
    }

    /// The analysis's own colour for a character, ignoring the reader's edits.
    private static func symbolColor(for entity: Entity) -> Color {
        Color(uiColor: SymbolPalette.color(at: SymbolPalette.style(for: entity, edited: [:]).colorIndex))
    }
}
#endif
