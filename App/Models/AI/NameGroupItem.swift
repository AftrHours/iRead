import Foundation
import FoundationModels

@Generable
struct NameGroupItem {
    @Guide(description: "Names that belong to the same person, spelled exactly as given")
    var names: [String]
    @Guide(description: "The number of the sentence that shows they are the same person")
    var evidenceSentence: Int
}
