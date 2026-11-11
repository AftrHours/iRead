import SwiftUI

/// Sort choices rendered inside the Library's main menu.
struct LibrarySortMenu: View {
    @Bindable var libVM: LibVM
    var onOptionSelected: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sort by")
                .font(AppTypography.caption1())
                .foregroundStyle(AppColors.menuTextMuted)
                .padding(.bottom, 2)

            ForEach(LibrarySortOption.menuOptions) { option in
                Button {
                    libVM.sortChanged(option)
                    onOptionSelected()
                } label: {
                    HStack {
                        Group {
                            if libVM.sortOption == option {
                                Image(systemName: "checkmark")
                            } else {
                                Color.clear
                            }
                        }
                            .frame(width: 16)
                            .font(AppTypography.callout(.semibold))
                        Text(option.title)
                        Spacer()
                    }
                    .foregroundStyle(AppColors.menuText)
                    .frame(minHeight: 40)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview("Library Sort Choices") {
    LibrarySortMenu(libVM: PreviewFixtures.libraryVM())
        .padding()
        .background(AppColors.menuBackground)
}
