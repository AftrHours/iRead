import SwiftUI

struct EditSymbolView: View {
    let entity: Entity
    let onSave: (SymbolStyle) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SymbolStyle

    init(entity: Entity, style: SymbolStyle, onSave: @escaping (SymbolStyle) -> Void) {
        self.entity = entity
        self.onSave = onSave
        _draft = State(initialValue: style)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 20) {
                        Image(systemName: draft.systemName)
                            .font(.system(size: 40))
                            .foregroundStyle(Color(SymbolPalette.color(at: draft.colorIndex)))
                            .frame(width: 70, height: 70)
                            .background(Color(.systemGray6), in: .rect(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entity.name)
                                .font(.title3.weight(.semibold))
                            Text("Current symbol")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    symbolRow("Shape", symbols: SymbolPaletteKnobs.shapes)
                    symbolRow("Icon", symbols: SymbolPaletteKnobs.icons)
                    section("Color") {
                        LazyVGrid(columns: columns(SymbolPaletteKnobs.colors.count), spacing: 12) {
                            ForEach(SymbolPaletteKnobs.colors.indices, id: \.self) { index in
                                colorButton(index)
                            }
                        }
                    }
                }
                .padding(28)
            }
            .navigationTitle("Edit Symbol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        onSave(draft)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
    }

    private func columns(_ count: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func symbolRow(_ title: String, symbols: [String]) -> some View {
        section(title) {
            // Both rows use the shape row's column count, so their tiles line up.
            LazyVGrid(columns: columns(SymbolPaletteKnobs.shapes.count), spacing: 12) {
                ForEach(symbols, id: \.self) { systemName in
                    let isSelected = draft.systemName == systemName
                    Button {
                        draft.systemName = systemName
                    } label: {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemGray6))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                Image(systemName: systemName)
                                    .font(.system(size: 30))
                                    .foregroundStyle(.primary)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isSelected ? Color.primary : .clear, lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(systemName.replacingOccurrences(of: ".fill", with: ""))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func colorButton(_ index: Int) -> some View {
        let isSelected = draft.colorIndex == index
        return Button {
            draft.colorIndex = index
        } label: {
            Circle()
                .fill(Color(SymbolPalette.color(at: index)))
                .padding(4)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Circle()
                        .stroke(isSelected ? Color.primary : .clear, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Color \(index + 1)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
