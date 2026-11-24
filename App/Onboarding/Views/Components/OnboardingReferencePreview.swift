import ImageIO
import SwiftUI

struct OnboardingReferencePreview: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var frame: CGImage?

    private static let source = NSDataAsset(name: "OnboardingReferenceLoop").flatMap {
        CGImageSourceCreateWithData($0.data as CFData, nil)
    }

    private var isPlaying: Bool {
        isActive && scenePhase == .active && !reduceMotion
    }

    var body: some View {
        Color.clear
            .aspectRatio(711.0 / 555.0, contentMode: .fit)
            .overlay {
                if let frame {
                    Image(decorative: frame, scale: 1).resizable().scaledToFit()
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("In The Last Carriage, the underlined phrase “familiar tuft of red hair” opens the author’s earlier description without leaving the page.")
            .task(id: isPlaying) { await displayFrames(animate: isPlaying) }
    }

    private func displayFrames(animate: Bool) async {
        guard let source = Self.source else { return }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return }
        var index = 0
        var deadline = ContinuousClock.now
        repeat {
            guard !Task.isCancelled else { return }
            frame = CGImageSourceCreateImageAtIndex(source, index, nil)
            guard animate, count > 1 else { return }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
                ?? gif?[kCGImagePropertyGIFDelayTime] as? Double ?? 0.1
            deadline += .seconds(delay > 0 ? delay : 0.1)
            do { try await Task.sleep(until: deadline, clock: .continuous) } catch { return }
            index = (index + 1) % count
        } while !Task.isCancelled
    }
}

#Preview { OnboardingReferencePreview(isActive: true).padding() }
