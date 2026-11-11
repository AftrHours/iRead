import SwiftUI

struct ToolbarList: View {
    let readerVM: ReaderVM

    var body: some View {
        Button("Contents", systemImage: "list.bullet") {
            readerVM.contentsTapped()
        }
        Button("Search in Book", systemImage: "magnifyingglass") {
            readerVM.searchTapped()
        }
        Button("Theme & Settings", systemImage: "textformat") {
            readerVM.themeSettingsTapped()
        }
    }
}
