import Foundation

struct ResolvedAnalysis: Sendable {
    var tags: SentenceTags
    var entities: [ResolvedEntity] = []
    var mentions: [ResolvedMention] = []
    var modelCalls = 0
    var modelFailures = 0
}
