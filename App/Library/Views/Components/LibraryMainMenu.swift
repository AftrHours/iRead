import SwiftUI

/// Selection, layout, sort, and account controls for the Library.
struct LibraryMainMenu: View {
    @Bindable var libVM: LibVM
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 10) {
            menuButton("Select", systemImage: "checkmark.circle") {
                libVM.selectionModeTapped()
                isPresented = false
            }

            divider

            menuButton("Grid", systemImage: "square.grid.2x2", selected: libVM.viewMode == .grid) {
                if libVM.viewMode != .grid { libVM.toggleViewMode() }
                isPresented = false
            }
            menuButton("List", systemImage: "list.bullet", selected: libVM.viewMode == .list) {
                if libVM.viewMode != .list { libVM.toggleViewMode() }
                isPresented = false
            }

            divider

            LibrarySortMenu(libVM: libVM) {
                isPresented = false
            }

            divider

            VStack(alignment: .leading, spacing: 8) {
                Text("iRead Account")
                    .font(AppTypography.caption1())
                    .foregroundStyle(AppColors.menuTextMuted)
                Button {
                    libVM.accountSettingsTapped()
                    isPresented = false
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "person.crop.circle")
                            .font(AppTypography.callout())
                        Text(libVM.accountActionTitle)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .font(AppTypography.callout())
                    .foregroundStyle(libVM.cloudAccount == .signedIn ? AppColors.accountSignOut : AppColors.accountSignIn)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 286)
        .background(AppColors.menuBackground, in: .rect(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(AppColors.textSecondary.opacity(0.16), lineWidth: 1)
        }
        .presentationCompactAdaptation(.popover)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColors.textSecondary.opacity(0.18))
            .frame(height: 1)
            .padding(.vertical, 3)
    }

    private func menuButton(_ title: String, systemImage: String, selected: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark" : systemImage)
                    .opacity(selected ? 1 : 0)
                    .frame(width: 10)
                    .font(AppTypography.callout(.semibold))
                Image(systemName: systemImage)
                    .frame(width: 18)
                    .font(AppTypography.callout())
                Text(title)
                    .font(AppTypography.callout())
                Spacer(minLength: 0)
            }
            .foregroundStyle(AppColors.menuText)
            .frame(minHeight: 40)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Library Menu") {
    LibraryMainMenu(libVM: PreviewFixtures.libraryVM(), isPresented: .constant(true))
        .padding()
        .background(AppColors.backgroundPrimary)
}
