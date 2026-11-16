import SwiftUI

/// After a Jump: Stay On This Page and Back to Latest Read. After returning: a short toast. Otherwise nothing.
/// Sized as in the design (Component 6): pills 149 × 34, footnote type, 12pt apart, with a 44pt tap area.
struct ReturnControls: View {
    private static let pillHeight: CGFloat = 34
    private static let pillGap: CGFloat = 12
    /// Both pills together: 2 × 149 + the gap.
    private static let maxWidth: CGFloat = 310

    let canReturn: Bool
    let toastText: String?
    let onDismiss: () -> Void
    let onReturn: () -> Void

    var body: some View {
        if canReturn {
            HStack(spacing: Self.pillGap) {
                Button("Stay On This Page", action: onDismiss)
                    .buttonStyle(ReturnPillStyle(fill: AppColors.settingsBackground, text: AppColors.textSecondary))
                Button("Back to Latest Read", action: onReturn)
                    .buttonStyle(ReturnPillStyle(fill: AppColors.actionPrimary, text: Color(white: 0.1)))
            }
            .frame(maxWidth: Self.maxWidth)
        } else if let toastText {
            Text(toastText)
                .font(AppTypography.footnote())
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(height: Self.pillHeight)
                .background(Color(red: 0xC4 / 255, green: 0xC3 / 255, blue: 0xDA / 255), in: .capsule)
                .transition(.opacity)
        }
    }
}

/// A capsule with a soft shadow, as in the design's Component 6. Equal widths side by side; the 44pt tap area is bigger than the pill.
private struct ReturnPillStyle: ButtonStyle {
    let fill: Color
    let text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.footnote())
            .foregroundStyle(text)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(fill, in: .capsule)
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            .padding(.vertical, 5)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

#Preview("Return") {
    ReturnControls(canReturn: true, toastText: nil, onDismiss: {}, onReturn: {})
}

#Preview("Toast") {
    ReturnControls(canReturn: false, toastText: "Returned to page 12", onDismiss: {}, onReturn: {})
}
