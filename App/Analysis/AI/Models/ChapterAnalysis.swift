import Foundation

struct ChapterAnalysis: Sendable, Codable {
    let chapter: Int
    let engineVersion: Int
    let parserVersion: Int
    let mentions: [ResolvedMention]
    let memory: CastMemory
}
