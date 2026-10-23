import Foundation

struct LibCtrlLive: LibCtrl {
    let libRepo: any LibRepo
    
    func loadLibrary() async throws -> [BookRecord] {
        return try await libRepo.fetchBooks()
    }
}
