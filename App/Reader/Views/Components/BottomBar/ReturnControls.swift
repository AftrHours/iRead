import SwiftUI

/// After a Jump: Stay On This Page and Back to Latest Read. After returning: a short toast. Otherwise nothing.
struct ReturnControls: View {
    let canReturn: Bool
    let toastText: String?
    let onDismiss: () -> Void
    let onReturn: () -> Void

    var body: some View {
        if canReturn {
            HStack(spacing: 16) {
                Button("Stay On This Page", action: onDismiss)
                    .buttonStyle(ReturnPillStyle(fill: AppColors.settingsBackground, text: AppColors.textSecondary))
                Button("Back to Latest Read", action: onReturn)
                    .buttonStyle(ReturnPillStyle(fill: AppColors.actionPrimary, text: Color(white: 0.1)))
            }
        } else if let toastText {
            Text(toastText)
                .font(AppTypography.body())
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .frame(minHeight: 44)
                .background(Color(red: 0xC4 / 255, green: 0xC3 / 255, blue: 0xDA / 255), in: .capsule)
                .transition(.opacity)
        }
    }
}

/// A capsule with a soft shadow, as in the design's Component 6.
private struct ReturnPillStyle: ButtonStyle {
    let fill: Color
    let text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.body())
            .foregroundStyle(text)
            .padding(.horizontal, 28)
            .frame(minHeight: 44)
            .background(fill, in: .capsule)
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

#Preview("Return") {
    ReturnControls(canReturn: true, toastText: nil, onDismiss: {}, onReturn: {})
}

#Preview("Toast") {
    ReturnControls(canReturn: false, toastText: "Returned to page 12", onDismiss: {}, onReturn: {})
}
