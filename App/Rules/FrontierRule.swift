import Foundation

enum FrontierRule {
    static func frontier(old: Int, lastVisibleSentence: Int) -> Int {
        max(old, lastVisibleSentence)
    }
}
