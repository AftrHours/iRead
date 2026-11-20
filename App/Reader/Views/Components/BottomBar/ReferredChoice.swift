import SwiftUI

/// The two pills after a Jump, sized as in the design (Component 6). They come and go at once; only the toast fades.
struct ReferredChoice: View {
    var waitingForPassage = false
    var completedPassage: UUID?
    let onDismiss: () -> Void
    let onReturn: () -> Void

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @AccessibilityFocusState(for: .voiceOver) private var stayFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onDismiss) {
                Text("Stay On This Page")
                    .font(AppTypography.footnote(.regular))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(width: 149, height: 34)
                    .background(AppColors.settingsBg, in: .capsule)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    .padding(.vertical, 8)
                    .contentShape(.rect)
            }
            .accessibilityFocused($stayFocused)
            Button(action: onReturn) {
                Text("Back to Latest Read")
                    .font(AppTypography.footnote(.regular))
                    .foregroundStyle(AppColors.actionPrimaryText)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(width: 149, height: 34)
                    .background(AppColors.actionPrimary, in: .capsule)
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    .padding(.vertical, 8)
                    .contentShape(.rect)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHidden(voiceOverEnabled && waitingForPassage)
        .task(id: completedPassage) {
            guard completedPassage != nil, voiceOverEnabled else { return }
            await Task.yield()
            if !Task.isCancelled { stayFocused = true }
        }
        .buttonStyle(.plain)
        .transition(.identity)
    }
}

#Preview("Choice") {
    ReferredChoice(onDismiss: {}, onReturn: {})
}
