import SwiftUI

struct ReaderMenuView: View {
    let readerVM: ReaderVM
    let readerSettingsVM: ReaderSettingsVM

    var body: some View {
        VStack(spacing: 0) {
            Button {
                readerVM.contentsTapped()
            } label: {
                row("Contents", systemImage: "list.bullet")
            }
            Button {
                readerVM.searchTapped()
            } label: {
                row("Search in Book", systemImage: "magnifyingglass")
            }
            Button {
                readerVM.themeSettingsTapped()
            } label: {
                row("Theme & Settings", systemImage: "textformat.size")
            }
            Divider()
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            Toggle("Symbols", isOn: Binding(get: { readerSettingsVM.settings.areSymbolsShown }, set: { readerSettingsVM.symbolsToggled($0) }))
                .padding(.horizontal, 20)
                .frame(minHeight: 44)
            Button {
                readerVM.symbolDetailsTapped()
            } label: {
                row("Symbol Details", systemImage: "chevron.right")
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .frame(width: 280)
        .presentationCompactAdaptation(.popover)
        .presentationBackground(Color(.systemBackground))
    }

    private func row(_ title: String, systemImage: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: systemImage)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 44)
        .contentShape(.rect)
    }
}
