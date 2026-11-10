import SwiftUI

struct SearchView: View {
    let searchVM: SearchVM
    @Environment(\.dismiss) private var dismiss
    @State private var isSearchPresented = true

    var body: some View {
        NavigationStack {
            Group {
                if searchVM.query.isEmpty {
                    recentSearches
                } else {
                    results
                }
            }
            .listStyle(.plain)
            .searchable(
                text: Binding(get: { searchVM.query }, set: { searchVM.queryChanged($0) }),
                isPresented: $isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always)
            )
            .onSubmit(of: .search) { searchVM.querySubmitted() }
            .navigationTitle("Search in Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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

    private var results: some View {
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
    }

    @ViewBuilder
    private var recentSearches: some View {
        if searchVM.recentSearches.isEmpty {
            Color.clear
        } else {
            List {
                HStack {
                    Text("Recent Searches")
                        .font(.title3.bold())
                    Spacer()
                    Button("Clear") {
                        searchVM.clearRecentSearchesTapped()
                    }
                    .font(.body.weight(.semibold))
                    .buttonStyle(.plain)
                }
                ForEach(searchVM.recentSearches, id: \.self) { query in
                    Button {
                        searchVM.recentSearchTapped(query)
                    } label: {
                        Label(query, systemImage: "magnifyingglass")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
