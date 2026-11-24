import Foundation

enum LibrarySorter {
    static func sorted(_ books: [BookRecord], by sortOption: LibrarySortOption, pinning pinnedID: UUID?) -> [BookRecord] {
        books.sorted { lhs, rhs in
            if lhs.id == pinnedID { return true }
            if rhs.id == pinnedID { return false }
            switch sortOption {
            case .title:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .author:
                return lhs.author.localizedCaseInsensitiveCompare(rhs.author) == .orderedAscending
            case .dateAdded:
                return lhs.dateAdded > rhs.dateAdded
            case .latestRead:
                return (lhs.lastReadAt ?? .distantPast) > (rhs.lastReadAt ?? .distantPast)
            case .readProgress:
                return lhs.progress > rhs.progress
            }
        }
    }
}
