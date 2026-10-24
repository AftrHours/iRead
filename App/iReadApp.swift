import SwiftUI

@main
struct iReadApp: App {
    private let appContainer: AppContainer
    @State private var libVM: LibVM
    @State private var readerVM: ReaderVM?

    init() {
        let appContainer = AppContainer()
        self.appContainer = appContainer
        _libVM = State(initialValue: appContainer.makeLibVM())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch appContainer.appNav.route {
                case .library:
                    LibView(libVM: libVM)
                case .reader:
                    if let readerVM {
                        ReaderView(readerVM: readerVM)
                    }
                }
            }
            .onChange(of: appContainer.appNav.route) { _, route in
                guard case .reader(let book) = route else {
                    readerVM = nil
                    return
                }
                readerVM = appContainer.makeReaderVM(book: book)
            }
        }
    }
}
