#if DEBUG
import Foundation
import Observation

@MainActor
@Observable
final class EngineDebugVM {
    private(set) var report: EngineDebugReport?
    private let refCtrl: RefCtrl
    private let chapter: Int?

    init(refCtrl: RefCtrl, page: Page?) {
        self.refCtrl = refCtrl
        chapter = page?.chapterIndex
    }

    func onAppear() async {
        while !Task.isCancelled {
            report = await refCtrl.debugReport(chapter: chapter)
            try? await Task.sleep(for: .seconds(1))
        }
    }
}
#endif
