import SwiftUI

@main
struct iReadApp: App {
    // Initialize the dependency graph once for the application lifecycle
    @StateObject private var libVM: LibVM = {
        let service = LibSvcLive()
        let controller = LibCtrlLive(libSvc: service)
        return LibVM(libCtrl: controller)
    }()
    
    var body: some Scene {
        WindowGroup {
            LibView(libVM: libVM)
        }
    }
}
