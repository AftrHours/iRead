import SwiftUI

/// After a Jump: ✕ and Return to Reading. After returning: a short toast. Otherwise nothing.
struct ReturnControls: View {
    let canReturn: Bool
    let toastText: String?
    let onDismiss: () -> Void
    let onReturn: () -> Void

    var body: some View {
        if canReturn {
            HStack(spacing: 0) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray2), in: .circle)
                }
                .accessibilityLabel("Dismiss")
                Button("Return to Reading", systemImage: "arrow.uturn.backward", action: onReturn)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
            }
        } else if let toastText {
            Text(toastText)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .frame(minHeight: 44)
                .background(Color(.systemGray2), in: .capsule)
                .transition(.opacity)
        }
    }
}

#Preview("Return") {
    ReturnControls(canReturn: true, toastText: nil, onDismiss: {}, onReturn: {})
}

#Preview("Toast") {
    ReturnControls(canReturn: false, toastText: "Returned to page 12", onDismiss: {}, onReturn: {})
}
