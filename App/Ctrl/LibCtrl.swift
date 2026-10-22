// Ctrl/LibCtrl.swift
import Foundation

protocol LibCtrl: Sendable {
    func loadLibrary() async throws -> [BookRecord]
}
