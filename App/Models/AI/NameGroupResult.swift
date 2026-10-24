import Foundation

struct NameGroupResult: Sendable {
    let groups: [NameGroupChoice]
    let failedCalls: Int
}
