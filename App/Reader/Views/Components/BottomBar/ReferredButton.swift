import SwiftUI


struct ReferredButton: View {
    fileprivate static let pillHeight: CGFloat = 34
    private static let pillGap: CGFloat = 12
    /// Both pills together: 2 × 149 + the gap.
    private static let maxWidth: CGFloat = 310

    let prompt: ReferenceVM.ReturnPrompt
    let onDismiss: () -> Void
    let onReturn: () -> Void

    var body: some View {
        switch prompt {
        case .none:
            EmptyView()
        case .choice:
            choice
        case .returned(let page):
            toast("Returned to page \(page)")
        }
    }

    // The pills come and go at once; only the toast fades.
    private var choice: some View {
        HStack(spacing: Self.pillGap) {
            Button("Stay On This Page", action: onDismiss)
                .buttonStyle(ReturnPillStyle(fill: AppColors.settingsBackground, text: AppColors.textSecondary))
            Button("Back to Latest Read", action: onReturn)
                .buttonStyle(ReturnPillStyle(fill: AppColors.actionPrimary, text: Color(white: 0.1)))
        }
        .frame(maxWidth: Self.maxWidth)
        .transition(.identity)
    }

    private func toast(_ text: String) -> some View {
        Text(text)
            .font(AppTypography.footnote())
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: Self.pillHeight)
            .background(Color(red: 0xC4 / 255, green: 0xC3 / 255, blue: 0xDA / 255), in: .capsule)
            .transition(.opacity)
    }
}

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
            .frame(height: ReferredButton.pillHeight)
            .background(fill, in: .capsule)
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            .padding(.vertical, 5)
            .contentShape(.rect)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

#Preview("Return") {
    ReferredButton(prompt: .choice, onDismiss: {}, onReturn: {})
}

#Preview("Toast") {
    ReferredButton(prompt: .returned(page: 12), onDismiss: {}, onReturn: {})
}
