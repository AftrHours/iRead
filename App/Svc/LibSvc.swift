// Svc/LibSvc.swift
import Foundation

protocol LibSvc: Sendable {
    func fetchBooks() async throws -> [BookRecord]
}
