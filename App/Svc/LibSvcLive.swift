// Svc/LibSvcLive.swift
import Foundation

struct LibSvcLive: LibSvc {
    func fetchBooks() async throws -> [BookRecord] {
        // Simulating data retrieval
        return [
            BookRecord(id: UUID(), title: "title", author: "author", isContinueReading: true),
            BookRecord(id: UUID(), title: "title", author: "author", isContinueReading: true),
            BookRecord(id: UUID(), title: "title", author: "author", isContinueReading: false),
            BookRecord(id: UUID(), title: "title", author: "author", isContinueReading: false)
        ]
    }
}
