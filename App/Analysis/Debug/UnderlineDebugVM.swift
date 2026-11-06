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
    private(set) var cloudLines: [String] = []
    private let refCtrl: RefCtrl
    private let ratingCtrl: RatingCtrl
    private let chapterIndex: Int?

    init(refCtrl: RefCtrl, ratingCtrl: RatingCtrl, chapterIndex: Int?) {
        self.refCtrl = refCtrl
        self.ratingCtrl = ratingCtrl
        self.chapterIndex = chapterIndex
    }

    /// Refreshes every second while open, because the engine may still be working on the chapter.
    func onAppear() async {
        guard let chapterIndex else { return }
        let account = Self.text(of: await ratingCtrl.cloudAccount())
        while !Task.isCancelled {
            cloudLines = await cloudStatus(chapterIndex, account: account)
            let model = await refCtrl.underlinesUseModel() ? "Foundation Models" : "Rules only"
            let records = await refCtrl.underlineRecords(inChapter: chapterIndex)
            if records.isEmpty {
                // A chapter loaded from disk has its underlines but not the dropped phrases.
                let underlines = await refCtrl.underlines(inChapter: chapterIndex)
                summary = "\(model) · \(underlines.count) underlined"
                note = underlines.isEmpty ? nil : "Loaded from a saved chapter, so dropped phrases aren't listed."
                rows = underlines.enumerated().map { index, underline in
                    Row(id: index, phrase: underline.text,
                        detail: "s\(underline.sentence) · \(underline.kind) · \(underline.decidedBy) · explained by s\(underline.reference.sentence)",
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

    private static func text(of account: CloudAccount?) -> String {
        switch account {
        case .signedIn?: "signed in"
        case .signedOut?: "not signed in (Settings app)"
        case .restricted?: "not allowed on this device"
        case .unknown?: "couldn't tell (offline?)"
        case nil: "none"
        }
    }

    private func cloudStatus(_ chapterIndex: Int, account: String) async -> [String] {
        let sharing = switch await ratingCtrl.sharesRatings() {
        case true?: "on"
        case false?: "off"
        case nil: "not asked yet"
        }
        let ratings = await ratingCtrl.ratingsStatus()
        return [
            "Account: \(account)",
            "This chapter: \(await refCtrl.cloudResult(inChapter: chapterIndex) ?? "still underlining")",
            "Ratings: sharing \(sharing) · \(ratings.unsent) waiting to send" + (ratings.lastSend.map { " · \($0)" } ?? "")
        ]
    }

    private static func detail(of record: UnderlineRecord) -> String {
        let outcome = record.kept
            ? "explained by s\(record.pickedSentence.map(String.init) ?? "?")"
            : "dropped: \(record.dropped?.rawValue ?? "unknown")"
        return ["s\(record.sentence)", record.kind.rawValue, record.path?.rawValue, outcome].compactMap { $0 }.joined(separator: " · ")
    }
}

/// The debug sheet's reads, kept here so only debug code sees UnderlineEngine's records.
extension RefCtrl {
    func underlinesUseModel() async -> Bool {
        await underlineRepo.usesModel
    }

    func underlineRecords(inChapter chapter: Int) async -> [UnderlineRecord] {
        guard let content = try? await bookContentRepo.content(for: bookID) else { return [] }
        return await underlineRepo.records(inChapter: chapter, of: content.fingerprint)
    }

    func underlines(inChapter chapter: Int) async -> [SavedUnderline] {
        guard let content = try? await bookContentRepo.content(for: bookID) else { return [] }
        return await underlineRepo.underlines(inChapter: chapter, of: content.fingerprint)
    }

    func cloudResult(inChapter chapter: Int) async -> String? {
        guard let content = try? await bookContentRepo.content(for: bookID) else { return nil }
        return await underlineRepo.cloudResult(inChapter: chapter, of: content.fingerprint)
    }
}

extension RatingCtrl {
    func ratingsStatus() async -> (unsent: Int, lastSend: String?) {
        (await ratingRepo.unsentCount, await ratingRepo.lastSendResult)
    }
}
#endif
