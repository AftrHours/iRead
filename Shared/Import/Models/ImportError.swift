import Foundation

enum ImportError: LocalizedError, Equatable {
    /// iTunes, Gutendex or the Gutenberg download couldn't be reached, or answered with an error.
    case unreachable
    /// The EPUB is over the size limit.
    case tooLarge
    case alreadyInLibrary(title: String)

    var errorDescription: String? {
        switch self {
        case .unreachable: "Refrn couldn’t reach Project Gutenberg. Try again later."
        case .tooLarge: "This book is larger than 100 MB."
        case .alreadyInLibrary(let title): "“\(title)” is already in your library."
        }
    }
}
