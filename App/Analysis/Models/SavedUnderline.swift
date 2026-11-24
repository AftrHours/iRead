import Foundation

/// The app's copy of one underline found by UnderlineEngine: what is kept on disk, in iCloud, and shown
struct SavedUnderline: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let sentence: Int
    let paragraph: Int
    let range: NSRange
    let text: String
    /// UnderlineKind's raw value
    let kind: String
    /// "model" or "rules"
    let decidedBy: String
    /// The earlier passage that explains it
    let reference: ContextPassage
}
