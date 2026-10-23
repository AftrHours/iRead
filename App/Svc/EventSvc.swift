import Foundation

protocol EventSvc: Sendable {
    func log(_ event: ReaderEvent) async
}
