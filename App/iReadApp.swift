import SwiftUI

@main
struct iReadApp: App {
    private let appContainer: AppContainer
    @State private var libVM: LibVM
    @State private var readerVM: ReaderVM?
    @State private var onboardingVM: OnboardingVM
    @AppStorage("hasCompletedHiFiOnboarding") private var hasCompletedOnboarding = false

    init() {
        let appContainer = AppContainer()
        self.appContainer = appContainer
        let libVM = appContainer.makeLibVM()
        _libVM = State(initialValue: libVM)
        _onboardingVM = State(initialValue: appContainer.makeOnboardingVM(using: libVM))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    switch appContainer.appNav.route {
                    case .library:
                        LibView(libVM: libVM)
                    case .reader:
                        if let readerVM {
                            ReaderView(readerVM: readerVM)
                        }
                    }
                } else {
                    OnboardingView(onboardingVM: onboardingVM) {
                        hasCompletedOnboarding = true
                    }
                }
            }
            .onOpenURL { url in
                Task { await libVM.fileOpened(url) }
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
