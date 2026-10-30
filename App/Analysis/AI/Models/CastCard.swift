import Foundation

struct CastCard: Sendable {
    let number: Int
    let entity: Int
    let name: String
    let aliases: [String]
    let traits: [String]
    let intro: String
    let introSentence: Int
}
