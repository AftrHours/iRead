import SwiftUI

/// Decorative book tile used in the upload introduction.
struct OnboardingBookIllustration: View {
    let symbol: String
    let tint: Color
    let rotation: Double

    var body: some View {
        GeometryReader { proxy in
            Image(systemName: symbol)
                .font(.system(size: min(42, proxy.size.width * 0.46), weight: .regular))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LibraryPalette.card, in: .rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                .rotationEffect(.degrees(rotation))
        }
        .frame(maxWidth: 90)
        .aspectRatio(0.8, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
