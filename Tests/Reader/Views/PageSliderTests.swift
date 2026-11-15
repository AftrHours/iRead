import Foundation
import Testing
@testable import iRead

@Suite("PageSlider")
struct PageSliderTests {
    @Test("RD-37 a released Slide carries on when far enough or fast enough, and goes back when flicked back")
    func completes() {
        // Far enough, even at rest.
        #expect(PageSlider.completes(progress: 0.31, velocity: 0))
        #expect(!PageSlider.completes(progress: 0.29, velocity: 0))
        // A fast flick toward the next page carries on from a short way.
        #expect(PageSlider.completes(progress: 0.05, velocity: 401))
        #expect(!PageSlider.completes(progress: 0.05, velocity: 399))
        // Flicked back, it goes back even when it was dragged far.
        #expect(!PageSlider.completes(progress: 0.9, velocity: -401))
        #expect(PageSlider.completes(progress: 0.9, velocity: -399))
    }
}
