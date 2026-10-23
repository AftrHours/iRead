import Foundation
import Observation

@MainActor
@Observable
final class ReaderVM {
    let bookID: UUID

    private let nav: any Nav

    init(bookID: UUID, nav: any Nav) {
        self.bookID = bookID
        self.nav = nav
    }

    func backTapped() {
        nav.closeReader()
    }
}
