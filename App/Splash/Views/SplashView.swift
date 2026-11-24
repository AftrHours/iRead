import Lottie
import SwiftUI

/// Plays the splash animation once (`Resources/Animation/Splash-light.lottie` or `-dark`, matching the system appearance).
struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            LottieView { try await DotLottieFile.named(colorScheme == .dark ? "Splash-dark" : "Splash-light") }
                // Stops at frame 89, not the end: the popover is an image layer that ends at frame 90, one frame before the rest.
                .playbackMode(.playing(.toFrame(89, loopMode: .playOnce)))
                .resizable()
        }
        .accessibilityElement()
        .accessibilityLabel("Refrn")
    }
}

private struct SplashOverlay: ViewModifier {
    @State private var isShowing = true

    func body(content: Content) -> some View {
        ZStack {
            content
            if isShowing { SplashView().transition(.opacity).zIndex(1) }
        }
        .task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.3)) { isShowing = false }
        }
    }
}

extension View {
    func splashScreen() -> some View { modifier(SplashOverlay()) }
}

#Preview { SplashView() }
