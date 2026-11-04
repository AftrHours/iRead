import Foundation
import Testing
@testable import iRead

@Suite("LibrarySorter")
struct LibrarySorterTests {
    private let books = [
        Self.book("banana", author: "zola", progress: 0.2, added: 100, read: 300),
        Self.book("Apple", author: "Austen", progress: 0.9, added: 300, read: nil),
        Self.book("cherry", author: "brontë", progress: 0.5, added: 200, read: 500)
    ]

    private static func book(_ title: String, author: String, progress: Double, added: Double, read: Double?) -> BookRecord {
        BookRecord(id: UUID(), title: title, author: author, isContinueReading: false, progress: progress,
                   dateAdded: Date(timeIntervalSince1970: added), lastReadAt: read.map { Date(timeIntervalSince1970: $0) })
    }

    @Test("LIB-01 title sort ignores case")
    func titleSort() {
        let sorted = LibrarySorter.sorted(books, by: .title, pinning: nil)
        #expect(sorted.map(\.title) == ["Apple", "banana", "cherry"])
    }

    @Test("LIB-02 author sort ignores case")
    func authorSort() {
        let sorted = LibrarySorter.sorted(books, by: .author, pinning: nil)
        #expect(sorted.map(\.author) == ["Austen", "brontë", "zola"])
    }

    @Test("LIB-03 date added sort is newest first")
    func dateAddedSort() {
        let sorted = LibrarySorter.sorted(books, by: .dateAdded, pinning: nil)
        #expect(sorted.map(\.title) == ["Apple", "cherry", "banana"])
    }

    @Test("LIB-04 latest read sort is most recent first, unread last")
    func latestReadSort() {
        let sorted = LibrarySorter.sorted(books, by: .latestRead, pinning: nil)
        #expect(sorted.map(\.title) == ["cherry", "banana", "Apple"])
    }

    @Test("LIB-05 read progress sort is highest first")
    func readProgressSort() {
        let sorted = LibrarySorter.sorted(books, by: .readProgress, pinning: nil)
        #expect(sorted.map(\.progress) == [0.9, 0.5, 0.2])
    }

    @Test("LIB-06 pinned book sorts first", arguments: LibrarySortOption.allCases)
    func pinnedFirst(sortOption: LibrarySortOption) throws {
        let unpinned = LibrarySorter.sorted(books, by: sortOption, pinning: nil)
        let last = try #require(unpinned.last)
        let pinned = LibrarySorter.sorted(books, by: sortOption, pinning: last.id)
        #expect(pinned.first?.id == last.id)
        #expect(pinned.dropFirst().map(\.id) == unpinned.dropLast().map(\.id))
    }
}
