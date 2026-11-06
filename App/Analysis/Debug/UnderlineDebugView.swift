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
                Section("iCloud") {
                    ForEach(underlineDebugVM.cloudLines, id: \.self) { line in
                        Text(line)
                            .font(.callout)
                    }
                }
                Section("This chapter") {
                    if underlineDebugVM.rows.isEmpty {
                        Text("Nothing yet: the engine is still reading this chapter.")
                            .foregroundStyle(.secondary)
                    }
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
