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
    private(set) var isModelRunning = false
    private(set) var progress: EngineProgress?
    private let refCtrl: RefCtrl
    private let page: Page?

    init(refCtrl: RefCtrl, page: Page?) {
        self.refCtrl = refCtrl
        self.page = page
    }

    func onAppear() async {
        while !Task.isCancelled {
            guard let snapshot = try? await refCtrl.snapshot() else { break }
            summary = EngineDebugReport.summary(of: snapshot)
            characters = EngineDebugReport.characters(of: snapshot)
            sentences = page.map { EngineDebugReport.sentences(on: $0, in: snapshot) } ?? []
            isLoading = false
            isModelRunning = snapshot.isModelAvailable && snapshot.modelDuration == nil
            progress = await refCtrl.progress()
            guard isModelRunning else { break }
            try? await Task.sleep(for: .seconds(1))
        }
        isLoading = false
        isModelRunning = false
    }
}
#endif
