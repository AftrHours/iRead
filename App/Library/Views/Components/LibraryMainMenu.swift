import SwiftUI

/// Native ellipsis menu for selection, layout, sorting, and account actions.
struct LibraryMainMenu: View {
    @Bindable var libVM: LibVM
    var iconFont: Font = AppTypography.body(.medium)

    var body: some View {
        Menu {
            Button("Select", systemImage: "checkmark.circle", action: libVM.selectionModeTapped)

            Section {
                Picker("Layout", selection: $libVM.menuViewMode) {
                    Label("Grid", systemImage: "square.grid.2x2").tag(LibVM.ViewMode.grid)
                    Label("List", systemImage: "list.bullet").tag(LibVM.ViewMode.list)
                }
                .pickerStyle(.inline)
            }

            LibrarySortMenu(libVM: libVM)

            Section("iRead Account") {
                Button(libVM.accountActionTitle, systemImage: "person.crop.circle", action: libVM.accountSettingsTapped)
                    .foregroundStyle(libVM.isAccountSignedIn ? AppColors.accountSignOut : AppColors.accountSignIn)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(iconFont)
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 48, height: 48)
                .glassEffect(.regular, in: .circle)
        }
        .buttonStyle(.plain)
        .menuOrder(.fixed)
        .accessibilityLabel("Library options")
    }
}

#Preview("Library Menu") {
    LibraryMainMenu(libVM: PreviewFixtures.libraryVM())
        .padding()
        .background(AppColors.backgroundPrimary)
}
