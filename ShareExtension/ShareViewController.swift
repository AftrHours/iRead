import SwiftUI
import UIKit

/// The Share extension's entry point: finds the shared link, then shows `ShareView`.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        Task { @MainActor [weak self] in
            guard let self else { return }
            let link = await sharedLink()
            let shareCtrl = ShareCtrl(bookLookupSvc: BookLookupSvcURLSession(), downloadSvc: DownloadSvcURLSession(),
                                      libraryIndexRepo: LibraryIndexRepo(), pendingImportRepo: PendingImportRepo())
            let shareVM = ShareVM(shareCtrl: shareCtrl) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
            show(ShareView(shareVM: shareVM, link: link))
        }
    }

    private func show(_ shareView: ShareView) {
        let host = UIHostingController(rootView: shareView)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    private var sharedProviders: [NSItemProvider] {
        (extensionContext?.inputItems as? [NSExtensionItem])?.flatMap { $0.attachments ?? [] } ?? []
    }

    private func sharedLink() async -> URL? {
        await AppleBooksLink.find(in: sharedProviders)
    }
}
