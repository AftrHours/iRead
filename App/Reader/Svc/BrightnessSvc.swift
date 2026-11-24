import UIKit

struct BrightnessSvc {
    @MainActor
    func brightness() async -> Double {
        Double(screen?.brightness ?? 0)
    }

    @MainActor
    func changeBrightness(to value: Double) async {
        screen?.brightness = CGFloat(value)
    }

    @MainActor
    private var screen: UIScreen? {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen
    }
}
