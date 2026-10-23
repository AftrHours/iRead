import Foundation

struct LibCtrl {
    let libRepo: LibRepo
    
    func loadLibrary() async throws -> [BookRecord] {
        return try await libRepo.fetchBooks()
    }

    func importBook(from url: URL) async throws -> BookRecord {
        try await libRepo.importBook(from: url)
    }
}
