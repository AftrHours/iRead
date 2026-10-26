#if DEBUG
import Foundation
import Observation

@MainActor
@Observable
final class EngineDebugVM {
    private(set) var summary: [EngineDebugSection] = []
    private(set) var characters: [EngineDebugCharacter] = []
    private(set) var sentences: [EngineDebugSentence] = []
    private(set) var isLoading = true
    private(set) var isAnalysing = false
    private(set) var progress: EngineProgress?
    private let refCtrl: RefCtrl
    private let page: Page?

    init(refCtrl: RefCtrl, page: Page?) {
        self.refCtrl = refCtrl
        self.page = page
    }

    func onAppear() async {
        while !Task.isCancelled {
            guard let snapshot = await refCtrl.snapshot() else {
                try? await Task.sleep(for: .seconds(1))
                continue
            }
            summary = EngineDebugReport.summary(of: snapshot)
            characters = EngineDebugReport.characters(of: snapshot)
            sentences = page.map { EngineDebugReport.sentences(on: $0, in: snapshot) } ?? []
            isLoading = false
            isAnalysing = snapshot.chaptersDone < snapshot.chaptersTotal
            progress = await refCtrl.progress()
            guard isAnalysing else { break }
            try? await Task.sleep(for: .seconds(1))
        }
        isLoading = false
        isAnalysing = false
    }
}
#endif
