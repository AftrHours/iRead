import SwiftUI

struct ReaderView: View {
    @State private var readerVM: ReaderVM

    init(readerVM: ReaderVM) {
        _readerVM = State(initialValue: readerVM)
    }

    var body: some View {
        VStack(spacing: 16) {
            Button("Back", systemImage: "chevron.left") {
                readerVM.backTapped()
            }
            Text(readerVM.bookID.uuidString)
                .foregroundStyle(.secondary)
        }
    }
}
