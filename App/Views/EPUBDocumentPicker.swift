import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Presents Apple's document picker full screen from the library.
struct EPUBDocumentPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (Result<[URL], any Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let presenter = UIViewController()
        presenter.view.backgroundColor = .clear
        presenter.view.isUserInteractionEnabled = false
        return presenter
    }

    func updateUIViewController(_ presenter: UIViewController, context: Context) {
        context.coordinator.isPresented = $isPresented
        guard isPresented,
              presenter.presentedViewController == nil,
              !context.coordinator.isPresenting else { return }

        guard presenter.viewIfLoaded?.window != nil else { return }
        context.coordinator.isPresenting = true
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.epub], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        picker.modalPresentationStyle = .fullScreen
        presenter.present(picker, animated: true) {
            context.coordinator.isPresenting = false
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var isPresented: Binding<Bool>
        var isPresenting = false
        private let onPick: (Result<[URL], any Error>) -> Void

        init(isPresented: Binding<Bool>, onPick: @escaping (Result<[URL], any Error>) -> Void) {
            self.isPresented = isPresented
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            controller.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                self.isPresented.wrappedValue = false
                self.onPick(.success(urls))
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            isPresented.wrappedValue = false
            onPick(.failure(CocoaError(.userCancelled)))
        }
    }
}
