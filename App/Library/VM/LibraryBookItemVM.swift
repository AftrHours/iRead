import UIKit

/// Immutable display values for one book in either Library layout.
struct LibraryBookItemVM: Identifiable {
    let book: BookRecord
    var cover: UIImage?
    var showsSelection = false
    var isSelected = false

    var id: UUID { book.id }
    var title: String { book.title }
    var author: String { book.author }
    var progress: LibraryProgressVM { LibraryProgressVM(progress: book.progress) }
    var isMenuHidden: Bool { showsSelection }
    var menuAccessibilityLabel: String { "More options for \(title)" }
    var selectionSymbol: String { isSelected ? "checkmark.circle.fill" : "circle" }
    var selectionAccessibilityLabel: String { isSelected ? "Selected" : "Not selected" }
    var finishedActionTitle: String { book.isFinished ? "Mark as Still Reading" : "Mark as Finished" }
    var finishedActionSymbol: String { book.isFinished ? "book" : "checkmark.circle" }
}
