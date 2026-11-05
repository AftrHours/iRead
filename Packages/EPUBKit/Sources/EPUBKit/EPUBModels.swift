import Foundation

public struct EPUBMetadata: Sendable {
    public let title: String?
    public let author: String?
}

/// A chapter as the table of contents divides the book, with its text split into paragraphs.
public struct EPUBChapter: Sendable {
    public let title: String
    public let paragraphs: [String]
}

public enum EPUBError: Error {
    /// A required file is missing from the EPUB, or its XML can't be read.
    case unreadable
}
