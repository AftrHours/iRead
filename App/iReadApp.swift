import SwiftUI

@main
struct iReadApp: App {
    @State private var appNav: AppNav
    @State private var libVM: LibVM

    init() {
        let appNav = AppNav()
        _appNav = State(initialValue: appNav)
        _libVM = State(initialValue: LibVM(libCtrl: LibCtrlLive(libRepo: LibRepoSample()), nav: appNav))
    }

    var body: some Scene {
        WindowGroup {
            switch appNav.route {
            case .library:
                LibView(libVM: libVM)
            case .reader(let bookID):
                ReaderView(readerVM: ReaderVM(bookID: bookID, nav: appNav))
            }
        }
    }
}
