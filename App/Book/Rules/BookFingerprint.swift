import CryptoKit
import Foundation

/// Names a book by its text, so it matches on every device and every import (its ID is new for each import).
enum BookFingerprint {
    static func of(_ chapters: [Chapter]) -> String {
        var hash = SHA256()
        for chapter in chapters {
            hash.update(data: Data(chapter.text.utf8))
            // So the same text split into other chapters gets another fingerprint.
            hash.update(data: Data([0]))
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
