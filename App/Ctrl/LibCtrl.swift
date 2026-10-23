import Foundation

protocol LibCtrl: Sendable {
    func loadLibrary() async throws -> [BookRecord]
}
