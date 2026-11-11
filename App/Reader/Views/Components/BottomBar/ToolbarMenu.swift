import SwiftUI

struct ToolbarMenu<Items: View>: View {
    let foreground: Color
    let colorScheme: ColorScheme
    let isVisible: Bool
    @ViewBuilder let items: () -> Items

    var body: some View {
        Menu(content: items) {
            Image(systemName: "ellipsis")
                .font(.title3.weight(.medium))
                .foregroundStyle(foreground)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
                .glassEffect(.regular.interactive(), in: .circle)
                .environment(\.colorScheme, colorScheme)
        }
        .menuStyle(.button)
        .menuOrder(.fixed)
        .accessibilityLabel("Reading menu")
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
    }
}

#Preview("Menu Button") {
    ToolbarMenu(foreground: .primary, colorScheme: .light, isVisible: true) {
        Button("Contents", systemImage: "list.bullet") {}
        Button("Search in Book", systemImage: "magnifyingglass") {}
        Button("Theme & Settings", systemImage: "textformat") {}
    }
}
