import Foundation

struct ResolvedAnalysis: Sendable {
    var entities: [ResolvedEntity] = []
    var mentions: [ResolvedMention] = []
    var modelCalls = 0
}
