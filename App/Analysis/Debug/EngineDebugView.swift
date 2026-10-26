#if DEBUG
import SwiftUI

struct EngineDebugView: View {
    enum Tab: String, CaseIterable {
        case summary = "Summary"
        case characters = "Characters"
        case page = "This Page"
    }

    @State private var engineDebugVM: EngineDebugVM
    @State private var tab = Tab.summary
    @Environment(\.dismiss) private var dismiss

    init(engineDebugVM: EngineDebugVM) {
        _engineDebugVM = State(initialValue: engineDebugVM)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Engine Debug")
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
                        .frame(width: 360)
                    }
                }
        }
        .task { await engineDebugVM.onAppear() }
    }

    @ViewBuilder
    private var content: some View {
        if engineDebugVM.isLoading {
            ProgressView()
        } else {
            switch tab {
            case .summary: summary
            case .characters: characters
            case .page: page
            }
        }
    }

    private var summary: some View {
        List {
            if engineDebugVM.isAnalysing {
                Section("Analysis progress") { progress }
            }
            ForEach(engineDebugVM.summary) { section in
                Section(section.title) {
                    ForEach(section.rows) { row in
                        LabeledContent(row.label, value: row.value)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var progress: some View {
        if let progress = engineDebugVM.progress {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: progress.fraction)
                Text("\(Int(progress.fraction * 100))% · \(progress.done) of \(progress.total) chapters")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 8) {
                ProgressView()
                Text("Waiting to start")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var characters: some View {
        List(engineDebugVM.characters) { character in
            VStack(alignment: .leading, spacing: 4) {
                Label(character.name, systemImage: character.symbolName)
                    .font(.headline)
                    .foregroundStyle(character.color)
                Text("\(character.mentionCount) mentions · names: \(character.names.isEmpty ? "none" : character.names)")
                    .font(.caption)
                Text(character.firstSeen)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var page: some View {
        List(engineDebugVM.sentences) { sentence in
            VStack(alignment: .leading, spacing: 4) {
                Text("s\(sentence.id)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(sentence.text)
                ForEach(sentence.links, id: \.self) { link in
                    Text(link)
                        .font(.caption.monospaced())
                }
            }
        }
    }
}
#endif
