#if DEBUG
import SwiftUI

struct EngineDebugView: View {
    enum Tab: String, CaseIterable {
        case chapter = "This Chapter"
        case book = "Whole Book"
    }

    @State private var engineDebugVM: EngineDebugVM
    @State private var tab = Tab.chapter
    @Environment(\.dismiss) private var dismiss

    init(engineDebugVM: EngineDebugVM) {
        _engineDebugVM = State(initialValue: engineDebugVM)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Underlines")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .close) { dismiss() }
                    }
                    ToolbarItem(placement: .principal) {
                        Picker("Section", selection: $tab) {
                            ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 280)
                    }
                }
        }
        .task { await engineDebugVM.onAppear() }
    }

    @ViewBuilder
    private var content: some View {
        if let report = engineDebugVM.report {
            List {
                Section("Run") {
                    ForEach(report.summary) { row in
                        LabeledContent(row.label, value: row.value)
                    }
                }
                ForEach(chapters(in: report)) { chapter in
                    Section("\(chapter.title) · \(chapter.status)") {
                        if chapter.underlines.isEmpty {
                            Text("No underlines")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(chapter.underlines, content: row)
                        ForEach(chapter.drops, content: dropsRow)
                    }
                }
            }
        } else {
            ProgressView()
        }
    }

    private func chapters(in report: EngineDebugReport) -> [EngineDebugChapter] {
        guard tab == .chapter else { return report.chapters }
        return report.chapters.filter { $0.id == report.currentChapter }
    }

    private func dropsRow(_ drops: EngineDebugDrops) -> some View {
        DisclosureGroup("\(drops.reason): \(drops.phrases.count)") {
            ForEach(Array(drops.phrases.enumerated()), id: \.offset) { _, phrase in
                Text(phrase)
                    .font(.caption)
            }
        }
    }

    private func row(_ underline: EngineDebugUnderline) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(underline.label)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text(underline.sentence)
            Text("\(underline.referenceLabel): \(underline.reference)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
