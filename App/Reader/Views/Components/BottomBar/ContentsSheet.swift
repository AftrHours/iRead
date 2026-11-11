import SwiftUI

struct ContentsSheet: View {
    let chapterTitles: [String]
    let startPageLabel: (Int) -> String
    let onChapterTapped: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(chapterTitles.indices, id: \.self) { index in
                Button {
                    onChapterTapped(index)
                } label: {
                    HStack {
                        Text(chapterTitles[index])
                        Spacer()
                        Text(startPageLabel(index))
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
    }
}

#Preview("Contents – as Sheet") {
    let chapterTitles = (1...20).map { "Chapter \($0)" }
    Color.gray.opacity(0.2)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            ContentsSheet(
                chapterTitles: chapterTitles,
                startPageLabel: { "\($0 * 14 + 1)" },
                onChapterTapped: { print("Chapter \($0 + 1) ditekan") }
            )
        }
}
