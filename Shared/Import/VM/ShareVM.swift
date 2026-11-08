import Foundation
import Observation

/// The share sheet: searching, then the book found (Send on) or why it can't be opened (Send off).
@MainActor
@Observable
final class ShareVM {
    enum State: Equatable {
        case searching
        case found(GutenbergEdition)
        case failed(String)
    }

    static let searchingMessage = "Finding this book…"
    static let foundNote = "Free Project Gutenberg edition. Apple Books doesn’t share its own files."

    private(set) var state = State.searching
    private var downloadedFile: URL?
    private let shareCtrl: ShareCtrl
    private let onFinish: @MainActor () -> Void

    var isSendEnabled: Bool {
        if case .found = state { true } else { false }
    }

    init(shareCtrl: ShareCtrl, onFinish: @escaping @MainActor () -> Void) {
        self.shareCtrl = shareCtrl
        self.onFinish = onFinish
    }

    /// nil when the share had no link at all.
    func onAppear(link: URL?) async {
        guard let link else {
            state = .failed(Self.sheetText(for: .unsupportedLink))
            return
        }
        let outcome = await shareCtrl.findFreeEdition(for: link)
        if case .found(let edition, let file) = outcome {
            downloadedFile = file
            state = .found(edition)
        } else {
            state = .failed(Self.sheetText(for: outcome))
        }
    }

    func sendTapped() {
        guard case .found(let edition) = state, let downloadedFile else { return }
        do {
            try shareCtrl.saveForApp(edition, file: downloadedFile)
            onFinish()
        } catch {
            state = .failed("iRead couldn’t save this book. Try again.")
        }
    }

    func cancelTapped() {
        if let downloadedFile { try? FileManager.default.removeItem(at: downloadedFile) }
        onFinish()
    }

    private static func sheetText(for outcome: ShareOutcome) -> String {
        switch outcome {
        case .found: ""
        case .unsupportedLink: "Only Apple Books links can be shared to iRead for now."
        case .notFound(let title?):
            "“\(title)” isn’t available as a free Project Gutenberg book, so it can’t be opened in iRead."
        case .notFound(nil): "This book isn’t available as a free Project Gutenberg book, so it can’t be opened in iRead."
        case .alreadyInLibrary(let title): "“\(title)” is already in your iRead library."
        case .unreachable: "iRead couldn’t reach Project Gutenberg. Try again later."
        case .tooLarge: "This book is larger than 100 MB."
        }
    }
}
