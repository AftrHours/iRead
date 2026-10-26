import SwiftUI

struct ChapterSymbolsView: View {
    let referenceVM: ReferenceVM
    @Environment(\.dismiss) private var dismiss
    @State private var expandedIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if referenceVM.chapterEntities.isEmpty {
                    ContentUnavailableView("No Characters Yet", systemImage: "person.2", description: Text("Characters appear here once the book is analyzed."))
                } else {
                    List(referenceVM.chapterEntities, id: \.id) { entity in
                        row(entity)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Characters in This Chapter")
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

    private func row(_ entity: Entity) -> some View {
        let isExpanded = expandedIDs.contains(entity.id)
        let style = referenceVM.symbolStyle(for: entity)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                if isExpanded {
                    expandedIDs.remove(entity.id)
                } else {
                    expandedIDs.insert(entity.id)
                }
            } label: {
                HStack(spacing: 20) {
                    Image(systemName: style.systemName)
                        .foregroundStyle(Color(SymbolPalette.color(at: style.colorIndex)))
                        .frame(width: 24)
                    Text(entity.name)
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isExpanded ? .isSelected : [])
            if isExpanded {
                Text(entity.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 44)
                HStack {
                    Spacer()
                    Button("Edit Symbol") {
                        referenceVM.editSymbolTapped(entity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
