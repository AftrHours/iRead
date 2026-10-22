// Models/BookRecord.swift
import Foundation

struct BookRecord: Identifiable {
    let id: UUID
    let title: String
    let author: String
    let isContinueReading: Bool
}
