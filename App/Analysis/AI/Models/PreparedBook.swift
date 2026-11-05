import Foundation

struct PreparedBook: Sendable {
    let content: BookContent
    let sentences: [NumberedSentence]
    let tags: SentenceTags
    let vocabulary: NameVocabulary
    let chapters: Range<Int>
}
