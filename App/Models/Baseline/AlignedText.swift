import Foundation

struct AlignedText: Sendable {
    let chapter: Int
    let tokenRanges: [NSRange?]
    let window: NSRange

    var unmatchedTokens: Int { tokenRanges.filter { $0 == nil }.count }
}
