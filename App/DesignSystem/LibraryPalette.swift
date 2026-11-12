import SwiftUI

/// Compatibility aliases for older views. New features should use AppColors directly.
enum LibraryPalette {
    static let page = AppColors.backgroundPrimary
    static let card = AppColors.popoverBackground
    static let primaryText = AppColors.textPrimary
    static let secondaryText = AppColors.textSecondary
    static let progressTrack = AppColors.readerReferencePanel
    static let progressFill = AppColors.actionPrimary
    static let addButton = AppColors.actionPrimary
    static let controlFill = AppColors.settingsControlBackground
    static let divider = AppColors.textSecondary.opacity(0.16)
    static let searchFill = AppColors.popoverBackground
}
