import Foundation
import FoundationModels

@Generable
struct SliceReadAnswer {
    @Generable
    struct Assignment {
        @Guide(description: "The number of a listed mention")
        var mention: Int
        @Guide(description: "The card number of the character it refers to, or 0 when it is not a character")
        var card: Int
        @Guide(description: "The number of the sentence that shows it")
        var sentence: Int
    }

    @Generable
    struct MissedName {
        @Guide(description: "A character name that is not in the mention list, copied exactly from the sentence")
        var name: String
        @Guide(description: "The number of the sentence it appears in")
        var sentence: Int
    }

    @Generable
    struct SameName {
        @Guide(description: "A name, copied exactly")
        var first: String
        @Guide(description: "Another name for the same person, copied exactly")
        var second: String
        @Guide(description: "The number of the sentence that shows they are the same person")
        var sentence: Int
    }

    @Generable
    struct Trait {
        @Guide(description: "The card number of the character")
        var card: Int
        @Guide(description: "A short description of the character, copied exactly from the sentence")
        var text: String
        @Guide(description: "The number of the sentence it appears in")
        var sentence: Int
    }

    var assignments: [Assignment]
    var missedNames: [MissedName]
    var sameNames: [SameName]
    var traits: [Trait]
}
