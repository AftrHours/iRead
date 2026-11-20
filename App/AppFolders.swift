import Foundation

/// Where the app saves things. `standard` is each repo's own default folder; a UI test gets one new temporary folder,
/// so it starts clean and never touches the reader's real books, progress or underlines.
struct AppFolders {
    let books: URL
    let underlines: URL
    /// Reading settings and ratings.
    let settings: URL
    let pendingImports: URL
    let libraryIndex: URL

    /// The launch argument the UI tests pass. The app then also skips the on-device model and iCloud (see AppContainer).
    static let uiTestingArgument = "-uiTesting"

    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains(uiTestingArgument)
    }

    static var current: AppFolders {
        isUITesting ? uiTesting() : standard
    }

    static let standard = AppFolders(
        books: .applicationSupportDirectory.appending(path: "Books"),
        underlines: .applicationSupportDirectory.appending(path: "Underlines"),
        settings: .applicationSupportDirectory,
        pendingImports: AppGroup.folder.appending(path: "PendingImports"),
        libraryIndex: AppGroup.folder
    )

    static func uiTesting() -> AppFolders {
        let root = URL.temporaryDirectory.appending(path: "iRead-UITest-\(UUID().uuidString)")
        return AppFolders(
            books: root.appending(path: "Books"),
            underlines: root.appending(path: "Underlines"),
            settings: root.appending(path: "Settings"),
            pendingImports: root.appending(path: "PendingImports"),
            libraryIndex: root.appending(path: "LibraryIndex")
        )
    }
}
