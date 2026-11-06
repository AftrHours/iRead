import SwiftUI

/// Sort control for the library screen.
struct LibrarySortMenu: View {
    @Bindable var libVM: LibVM

    var body: some View {
        Menu {
            Picker("Sort by", selection: Binding(
                get: { libVM.sortOption },
                set: { libVM.sortChanged($0) }
            )) {
                ForEach(LibrarySortOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.title3.weight(.medium))
                .foregroundStyle(LibraryPalette.primaryText)
                .frame(width: 48, height: 48)
                .background(LibraryPalette.controlFill, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sort library")
    }
}
