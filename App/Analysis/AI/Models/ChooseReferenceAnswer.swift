import Foundation
import FoundationModels

@Generable
struct ChooseReferenceAnswer {
    @Guide(description: "The candidate number the phrase refers to, or -1 when the sentences do not make it clear")
    var candidate: Int
    @Guide(description: "The number of the sentence that shows it")
    var evidenceSentence: Int
}
