import Foundation
import OSLog

extension Logger {
    /// Every log category uses the app's bundle ID, so it follows the one set in project.yml.
    static let appSubsystem = Bundle.main.bundleIdentifier ?? "iRead"
}
