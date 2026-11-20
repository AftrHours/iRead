import SwiftUI

/// Two native menus share the capsule shown when the iPhone library is scrolled.
struct LibraryPhoneMenuGroup: View {
    let libVM: LibVM

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                LibrarySortMenu(libVM: libVM)
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(AppTypography.title3(.regular))
                    .foregroundStyle(AppColors.textPrimary)
                    .libraryIconFrame()
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .menuOrder(.fixed)
            .libraryControlLabel("Sort books", symbol: "line.3.horizontal.decrease")

            LibraryMainMenu(libVM: libVM, iconFont: AppTypography.title3(.semibold), isGrouped: true)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

#Preview("iPhone Grouped Menus") {
    LibraryPhoneMenuGroup(libVM: PreviewFixtures.libraryVM())
        .padding()
        .background(AppColors.bgPrimary)
        .preferredColorScheme(.dark)
}
