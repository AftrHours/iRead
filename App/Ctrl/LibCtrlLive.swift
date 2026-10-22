// Ctrl/LibCtrlLive.swift
import Foundation

struct LibCtrlLive: LibCtrl {
    let libSvc: any LibSvc
    
    func loadLibrary() async throws -> [BookRecord] {
        return try await libSvc.fetchBooks()
    }
}
