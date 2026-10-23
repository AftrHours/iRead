import Foundation

actor AnalysisRepo {
    private static let entities = [
        Entity(
            id: "jo",
            name: "Jo March",
            symbolName: "circle.fill",
            summary: "The second March sister, tall and boyish, who loves to write.",
            names: ["Jo"]
        ),
        Entity(
            id: "meg",
            name: "Meg March",
            symbolName: "square.fill",
            summary: "The eldest March sister, pretty and fond of nice things.",
            names: ["Meg", "Margaret"]
        ),
        Entity(
            id: "laurie",
            name: "Laurie Laurence",
            symbolName: "triangle.fill",
            summary: "Jo's neighbor, with curly black hair and dark eyes. He and Jo meet at a party.",
            names: ["Laurie"]
        )
    ]

    private static let references = [
        (
            entityID: "laurie",
            phrase: "a curly black head leaning on a thin hand at the upper window",
            passage: "Curly black hair, brown skin, big black eyes, handsome nose, fine teeth, small hands and feet, "
                + "taller than I am, very polite, for a boy, and altogether jolly. Wonder how old he is?"
        ),
        (
            entityID: "laurie",
            phrase: "the tall lad",
            passage: "Curly black hair, brown skin, big black eyes, handsome nose, fine teeth, small hands and feet, "
                + "taller than I am, very polite, for a boy, and altogether jolly. Wonder how old he is?"
        ),
        (
            entityID: "meg",
            phrase: "the young lady in the pretty slippers",
            passage: "Margaret, the eldest of the four, was sixteen, and very pretty, being plump and fair, with large eyes, "
                + "plenty of soft brown hair, a sweet mouth, and white hands, of which she was rather vain."
        )
    ]

    private let bookContentRepo: BookContentRepo
    private var analysis: BookAnalysis?

    init(bookContentRepo: BookContentRepo) {
        self.bookContentRepo = bookContentRepo
    }

    func analysis(for bookID: UUID) async throws -> BookAnalysis {
        if let analysis { return analysis }
        let content = try await bookContentRepo.content(for: bookID)
        let references = Self.references.compactMap { reference -> Mention? in
            guard let phrase = Self.find(reference.phrase, in: content),
                  let passage = Self.find(reference.passage, in: content) else { return nil }
            return Mention(
                entityID: reference.entityID,
                paragraph: phrase.paragraph,
                range: phrase.range,
                passage: ContextPassage(paragraph: passage.paragraph, range: passage.range, text: reference.passage)
            )
        }
        let names = Self.entities.flatMap { Self.nameMentions(of: $0, in: content) }
        let analysis = BookAnalysis(entities: Self.entities, mentions: references + names)
        self.analysis = analysis
        return analysis
    }

    private static func nameMentions(of entity: Entity, in content: BookContent) -> [Mention] {
        guard let regex = try? NSRegularExpression(pattern: "\\b(?:" + entity.names.joined(separator: "|") + ")\\b") else { return [] }
        return content.chapters.flatMap { chapter in
            regex.matches(in: chapter.text, range: NSRange(location: 0, length: chapter.text.utf16.count)).map { match in
                let location = paragraphLocation(of: match.range, in: chapter, content: content)
                return Mention(entityID: entity.id, paragraph: location.paragraph, range: location.range, passage: nil)
            }
        }
    }

    private static func find(_ text: String, in content: BookContent) -> (paragraph: Int, range: NSRange)? {
        for chapter in content.chapters {
            let range = (chapter.text as NSString).range(of: text)
            if range.location != NSNotFound {
                return paragraphLocation(of: range, in: chapter, content: content)
            }
        }
        return nil
    }

    private static func paragraphLocation(of range: NSRange, in chapter: Chapter, content: BookContent) -> (paragraph: Int, range: NSRange) {
        let paragraph = chapter.paragraphs.last { content.paragraphs[$0].range.location <= range.location } ?? chapter.paragraphs.lowerBound
        return (paragraph, NSRange(location: range.location - content.paragraphs[paragraph].range.location, length: range.length))
    }
}
