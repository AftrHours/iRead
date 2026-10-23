import Foundation

struct LibCtrl {
    let libRepo: LibRepo
    
    func loadLibrary() async throws -> [BookRecord] {
        return try await libRepo.fetchBooks()
    }
}
