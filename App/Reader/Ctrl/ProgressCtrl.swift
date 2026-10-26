import Foundation

actor ProgressCtrl {
    private let bookID: UUID
    private let progRepo: ProgRepo
    private let eventSvc: EventSvc
    private var readingProgress: ReadingProgress?

    init(bookID: UUID, progRepo: ProgRepo, eventSvc: EventSvc) {
        self.bookID = bookID
        self.progRepo = progRepo
        self.eventSvc = eventSvc
    }

    func savedProgress() async -> ReadingProgress? {
        readingProgress = await progRepo.progress(for: bookID)
        return readingProgress
    }

    func positionRestored(_ isRestored: Bool) async {
        await eventSvc.log(.positionRestore(bookID: bookID, isRestored: isRestored))
    }

    func pageRead(_ progress: ReadingProgress) async {
        let wasFinished = self.readingProgress?.finishedAt != nil
        let readingProgress = ReadingProgressCalculator.merged(progress, after: self.readingProgress)
        self.readingProgress = readingProgress
        await progRepo.save(readingProgress)
        if !wasFinished, readingProgress.finishedAt != nil {
            await eventSvc.log(.bookFinished(bookID: bookID))
        }
    }

    func saveNow() async {
        guard let readingProgress else { return }
        await progRepo.saveNow(readingProgress)
    }
}
