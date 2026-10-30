import SwiftUI

struct ContentsView: View {
    let readerVM: ReaderVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(readerVM.chapterTitles.indices, id: \.self) { index in
                Button {
                    readerVM.chapterTapped(index)
                } label: {
                    HStack {
                        Text(readerVM.chapterTitles[index])
                        Spacer()
                        Text(readerVM.startPageLabel(ofChapter: index))
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("Contents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
    }
}
