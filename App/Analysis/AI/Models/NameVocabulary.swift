import Foundation

struct NameVocabulary: Sendable, Codable {
    let names: Set<String>
    let nameCounts: [String: Int]
}
