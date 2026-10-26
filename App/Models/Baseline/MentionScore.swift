import Foundation

struct MentionCounts: Sendable {
    var truePositives = 0
    var falsePositives = 0
    var falseNegatives = 0

    var precision: Double { truePositives + falsePositives == 0 ? 0 : Double(truePositives) / Double(truePositives + falsePositives) }
    var recall: Double { truePositives + falseNegatives == 0 ? 0 : Double(truePositives) / Double(truePositives + falseNegatives) }
    var f1: Double { precision + recall == 0 ? 0 : 2 * precision * recall / (precision + recall) }
}

struct MentionScore: Sendable {
    let exact: MentionCounts
    let overlap: MentionCounts
    let missed: [String]
    let spurious: [String]
}
