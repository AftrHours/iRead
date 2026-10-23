import Foundation

protocol ReaderCtrl: Sendable {
    func openBook() async throws -> BookRecord
    func chapterTitles() async -> [String]
    func currentPage(viewport: Viewport) async -> Page
    func pages(around page: Page) async -> [Page]
    func pageChanged(to page: Page) async
    func saveNow() async
}
