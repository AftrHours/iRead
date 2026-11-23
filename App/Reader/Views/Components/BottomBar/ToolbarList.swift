import SwiftUI

struct ToolbarList: View {
    let readerVM: ReaderVM

    var body: some View {
        Button("Contents", systemImage: "list.bullet") {
            readerVM.contentsTapped()
        }
        Button("Characters", systemImage: "person.2") {
            readerVM.charactersTapped()
        }
        Button("Search in Book", systemImage: "magnifyingglass") {
            readerVM.searchTapped()
        }
        Button("Theme & Settings", systemImage: "textformat") {
            readerVM.themeSettingsTapped()
        }
    }
}

#Preview("Toolbar List") {
    List {
        ToolbarList(readerVM: PreviewFixtures.readerVM())
    }
}
