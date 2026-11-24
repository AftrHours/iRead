#if DEBUG
import SwiftUI
import UniformTypeIdentifiers

/// Every phrase UnderlineEngine considered in the shown chapter, and why it was or wasn't underlined.
struct UnderlineDebugView: View {
    @State private var underlineDebugVM: UnderlineDebugVM
    @Environment(\.dismiss) private var dismiss
    @State private var picksExportFolder = false

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
                Section {
                    Text(underlineDebugVM.bookLine)
                        .font(.callout)
                    if !underlineDebugVM.bookFolder.isEmpty {
                        Text(underlineDebugVM.bookFolder)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    if underlineDebugVM.bookIsRunning {
                        Button("Stop", role: .destructive) { underlineDebugVM.stopBook() }
                    } else {
                        Button("Underline whole book") { underlineDebugVM.startBook() }
                    }
                    Button("Export saved chapters…") { picksExportFolder = true }
                    if let exportLine = underlineDebugVM.exportLine {
                        Text(exportLine)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("Whole book")
                } footer: {
                    Text("Keep the app in front. Chapters already saved are skipped, so a stopped run carries on where it was. "
                         + "Export copies every book's saved chapters into the folder you pick, one folder per book.")
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
        .fileImporter(isPresented: $picksExportFolder, allowedContentTypes: [.folder]) { result in
            guard case .success(let destination) = result else { return }
            Task { await underlineDebugVM.export(to: destination) }
        }
        .task { await underlineDebugVM.onAppear() }
    }
}

#Preview("Underline Debug") {
    let readerVM = PreviewFixtures.readerVM()
    UnderlineDebugView(underlineDebugVM: UnderlineDebugVM(
        refCtrl: readerVM.referenceVM.refCtrl,
        ratingCtrl: readerVM.ratingVM.ratingCtrl,
        chapterIndex: nil
    ))
}
#endif
