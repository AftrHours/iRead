import SwiftUI

struct SearchView: View {
    let searchVM: SearchVM
    @Environment(\.dismiss) private var dismiss
    @State private var isSearchPresented = true

    var body: some View {
        NavigationStack {
            List(searchVM.results) { result in
                Button {
                    searchVM.resultTapped(result)
                } label: {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.chapterTitle)
                                .font(.subheadline.weight(.semibold))
                            Text(result.snippet)
                                .font(.subheadline)
                                .lineLimit(3)
                        }
                        Spacer()
                        Text("\(result.pageNumber)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .searchable(
                text: Binding(get: { searchVM.query }, set: { searchVM.queryChanged($0) }),
                isPresented: $isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always)
            )
            .navigationTitle("Search in Book")
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
