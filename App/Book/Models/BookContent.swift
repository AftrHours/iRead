import Foundation

struct BookContent: Sendable {
    let chapters: [Chapter]
    let paragraphs: [Paragraph]
    let sentences: [Sentence]
    let parserVersion: Int
}
