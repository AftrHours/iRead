import OSLog

/// A protocol so tests can count logged events.
protocol EventSvc: Sendable {
    func log(_ event: ReaderEvent) async
}

struct EventSvcOSLog: EventSvc {
    private let logger = Logger(subsystem: Logger.appSubsystem, category: "events")

    func log(_ event: ReaderEvent) async {
        switch event {
        case .positionRestore(let bookID, let isRestored):
            logger.notice("RD_Position_Restore book_id=\(bookID.uuidString, privacy: .public) restored_ok=\(isRestored, privacy: .public)")
        case .bookFinished(let bookID):
            logger.notice("RD_Book_Finished book_id=\(bookID.uuidString, privacy: .public)")
        }
    }
}
