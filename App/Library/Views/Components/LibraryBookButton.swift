import SwiftUI

extension EnvironmentValues {
    // Each book reserves two consecutive VoiceOver stops in the displayed order.
    @Entry var libraryBookMenuPriority: Double = 0
}

/// The primary book action is a separate accessibility element from the options menu.
struct LibraryBookButton<Content: View>: View {
    @Environment(\.libraryBookMenuPriority) private var menuPriority
    let item: LibraryBookItemVM
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilitySortPriority(menuPriority + 1)
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityValue(item.accessibilityValue)
        .accessibilityHint(item.accessibilityHint)
        .accessibilityAddTraits(item.showsSelection && item.isSelected ? .isSelected : [])
    }
}
