import Foundation

public struct EPUBMetadata: Sendable {
    public let title: String?
    public let author: String?
    /// The text of every `dc:identifier` and `dc:source`, in file order (a Project Gutenberg book names its URL here).
    public let identifiers: [String]
}

/// Which part of the book a file says it belongs to, through its `epub:type`.
public enum EPUBPart: Sendable {
    case front
    case body
    case back
}

/// A chapter as the table of contents divides the book, with its text split into paragraphs.
public struct EPUBChapter: Sendable {
    public let title: String
    public let paragraphs: [String]
    /// From the `epub:type` of the chapter's file; for the text before the first table-of-contents entry, front matter.
    /// Nil when the file doesn't say.
    public let part: EPUBPart?
}

public enum EPUBError: Error {
    /// A required file is missing from the EPUB, or its XML can't be read.
    case unreadable
}
