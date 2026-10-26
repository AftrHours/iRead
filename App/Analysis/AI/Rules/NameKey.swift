import Foundation

enum NameKey {
    static func of(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: ".", with: "").split(separator: " ").joined(separator: " ")
    }
}
