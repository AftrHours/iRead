import Foundation

protocol PagerSvc: Sendable {
    func pageRanges(for text: String, viewport: Viewport, settings: ReadingSettings) async -> [NSRange]
}
