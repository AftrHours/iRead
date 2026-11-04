#if DEBUG
import Foundation
import Observation
import UnderlineEngine

@MainActor
@Observable
final class UnderlineDebugVM {
    struct Row: Identifiable {
        let id: Int
        let phrase: String
        let detail: String
        let isUnderlined: Bool
    }

    private(set) var summary = ""
    private(set) var note: String?
    private(set) var rows: [Row] = []
    private let refCtrl: RefCtrl
    private let chapterIndex: Int?

    init(refCtrl: RefCtrl, chapterIndex: Int?) {
        self.refCtrl = refCtrl
        self.chapterIndex = chapterIndex
    }

    /// Refreshes every second while open, because the engine may still be working on the chapter.
    func onAppear() async {
        guard let chapterIndex else { return }
        while !Task.isCancelled {
            let model = await refCtrl.underlinesUseModel() ? "Foundation Models" : "Rules only"
            let records = await refCtrl.underlineRecords(inChapter: chapterIndex)
            if records.isEmpty {
                // A chapter loaded from disk has its underlines but not the dropped phrases.
                let underlines = await refCtrl.underlines(inChapter: chapterIndex)
                summary = "\(model) · \(underlines.count) underlined"
                note = underlines.isEmpty ? nil : "Loaded from a saved chapter, so dropped phrases aren't listed."
                rows = underlines.enumerated().map { index, underline in
                    Row(id: index, phrase: underline.text,
                        detail: "s\(underline.sentence) · \(underline.kind.rawValue) · \(underline.decidedBy.rawValue) · explained by s\(underline.reference.sentence)",
                        isUnderlined: true)
                }
            } else {
                summary = "\(model) · \(records.filter(\.kept).count) underlined · \(records.filter { !$0.kept }.count) dropped"
                note = nil
                rows = records.sorted { $0.sentence < $1.sentence }.enumerated().map { index, record in
                    Row(id: index, phrase: record.phrase, detail: Self.detail(of: record), isUnderlined: record.kept)
                }
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private static func detail(of record: UnderlineRecord) -> String {
        let outcome = record.kept
            ? "explained by s\(record.pickedSentence.map(String.init) ?? "?")"
            : "dropped: \(record.dropped?.rawValue ?? "unknown")"
        return ["s\(record.sentence)", record.kind.rawValue, record.path?.rawValue, outcome].compactMap { $0 }.joined(separator: " · ")
    }
}
#endif
