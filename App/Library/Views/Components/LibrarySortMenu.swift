import SwiftUI

/// Inline native sort choices; selection changes are handled by LibVM.
struct LibrarySortMenu: View {
    @Bindable var libVM: LibVM

    var body: some View {
        Section("Sort by") {
            Picker("Sort by", selection: $libVM.menuSortOption) {
                ForEach(libVM.menuSortOptions) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }
}

#Preview("Library Sort Choices") {
    Menu("Sort Library") {
        LibrarySortMenu(libVM: PreviewFixtures.libraryVM())
    }
    .padding()
    .background(AppColors.menuBackground)
}
