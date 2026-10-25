import Foundation

struct EngineProgress: Sendable {
    let done: Int
    let total: Int

    var fraction: Double {
        total == 0 ? 1 : min(1, Double(done) / Double(total))
    }
}
