import SwiftUI

struct ReferredButton: View {
    let prompt: ReferenceVM.ReturnPrompt
    var waitingForPassage = false
    var completedPassage: UUID?
    let onDismiss: () -> Void
    let onReturn: () -> Void

    var body: some View {
        switch prompt {
        case .none:
            EmptyView()
        case .choice:
            ReferredChoice(waitingForPassage: waitingForPassage, completedPassage: completedPassage,
                           onDismiss: onDismiss, onReturn: onReturn)
        case .returned(let message):
            ReferredToast(text: message)
        }
    }
}

#Preview("Return") {
    ReferredButton(prompt: .choice, onDismiss: {}, onReturn: {})
}

#Preview("Toast") {
    ReferredButton(prompt: .returned(message: "Returned to page 12"), onDismiss: {}, onReturn: {})
}
