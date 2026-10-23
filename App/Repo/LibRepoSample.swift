import Foundation

struct LibRepoSample: LibRepo {
    func fetchBooks() async throws -> [BookRecord] {
        [
            BookRecord(id: sampleID(1), title: "Little Women", author: "Louisa May Alcott", isContinueReading: true),
            BookRecord(id: sampleID(2), title: "title", author: "author", isContinueReading: true),
            BookRecord(id: sampleID(3), title: "title", author: "author", isContinueReading: false),
            BookRecord(id: sampleID(4), title: "title", author: "author", isContinueReading: false)
        ]
    }

    private func sampleID(_ number: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, number))
    }
}
