import Foundation

enum LibrarySortOption: String, CaseIterable, Identifiable, Sendable {
    case title
    case author
    case dateAdded
    case latestRead
    case readProgress

    var id: String { rawValue }
    var title: String {
        switch self {
        case .title: "Title"
        case .author: "Author"
        case .dateAdded: "Date Added"
        case .latestRead: "Latest Read"
        case .readProgress: "Read Progress"
        }
    }
}
