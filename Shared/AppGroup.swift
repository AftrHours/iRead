import Foundation

/// The folder the app shares with the Share extension.
enum AppGroup {
    static let id = "group.com.aftrhours.reader"

    /// Falls back to a folder in Application Support when the build has no App Group (unsigned builds and tests).
    static var folder: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
            ?? .applicationSupportDirectory.appending(path: "AppGroup")
    }
}
