#if DEBUG
import SwiftUI

/// Every phrase UnderlineEngine considered in the shown chapter, and why it was or wasn't underlined.
struct UnderlineDebugView: View {
    @State private var underlineDebugVM: UnderlineDebugVM
    @Environment(\.dismiss) private var dismiss

    init(underlineDebugVM: UnderlineDebugVM) {
        _underlineDebugVM = State(initialValue: underlineDebugVM)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(underlineDebugVM.summary)
                    if let note = underlineDebugVM.note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("This chapter") {
                    ForEach(underlineDebugVM.rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.phrase)
                                .fontWeight(row.isUnderlined ? .semibold : .regular)
                                .foregroundStyle(row.isUnderlined ? .primary : .secondary)
                            Text(row.detail)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay {
                if underlineDebugVM.rows.isEmpty {
                    ContentUnavailableView("Nothing Yet", systemImage: "underline", description: Text("The engine is still reading this chapter."))
                }
            }
            .navigationTitle("Underline Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .task { await underlineDebugVM.onAppear() }
    }
}
#endif
