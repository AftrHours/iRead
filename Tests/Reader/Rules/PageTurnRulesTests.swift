import Foundation
import Testing
@testable import iRead

@Suite("PageTurnRules")
struct PageTurnRulesTests {
    @Test("RD-37 a released Slide carries on when far enough or fast enough, and goes back when flicked back")
    func completes() {
        // Far enough, even at rest.
        #expect(PageTurnRules.completes(progress: 0.31, velocity: 0))
        #expect(!PageTurnRules.completes(progress: 0.29, velocity: 0))
        // A fast flick toward the next page carries on from a short way.
        #expect(PageTurnRules.completes(progress: 0.05, velocity: 401))
        #expect(!PageTurnRules.completes(progress: 0.05, velocity: 399))
        // Flicked back, it goes back even when it was dragged far.
        #expect(!PageTurnRules.completes(progress: 0.9, velocity: -401))
        #expect(PageTurnRules.completes(progress: 0.9, velocity: -399))
    }

    @Test("RD-41 a Fast Fade swipe turns when far or fast enough, toward where it points")
    func fadeSwipe() {
        // Left (negative) is forward.
        #expect(PageTurnRules.fadeTurnsForward(translation: -36, velocity: 0) == true)
        #expect(PageTurnRules.fadeTurnsForward(translation: 36, velocity: 0) == false)
        #expect(PageTurnRules.fadeTurnsForward(translation: -35, velocity: 0) == nil)
        // A short, fast flick counts too; a short, slow one doesn't.
        #expect(PageTurnRules.fadeTurnsForward(translation: 10, velocity: -401) == true)
        #expect(PageTurnRules.fadeTurnsForward(translation: -10, velocity: 401) == false)
        #expect(PageTurnRules.fadeTurnsForward(translation: 10, velocity: -399) == nil)
    }

    @Test("RD-42 a drag takes a Slide from 0 to 1 over the page's width, and never past either end")
    func dragProgress() {
        #expect(PageTurnRules.dragProgress(translation: -100, isForward: true, distance: 400) == 0.25)
        #expect(PageTurnRules.dragProgress(translation: 100, isForward: false, distance: 400) == 0.25)
        // Dragged the wrong way, or far past the end.
        #expect(PageTurnRules.dragProgress(translation: 100, isForward: true, distance: 400) == 0)
        #expect(PageTurnRules.dragProgress(translation: -1000, isForward: true, distance: 400) == 1)
        #expect(PageTurnRules.dragProgress(translation: -100, isForward: true, distance: 0) == 0)
        // The spring leaves the finger at its speed, over the distance left; nothing to carry when almost there.
        #expect(PageTurnRules.springVelocity(fingerVelocity: -800, remaining: 200) == 4)
        #expect(PageTurnRules.springVelocity(fingerVelocity: -800, remaining: 1) == 0)
    }

    @Test("RD-43 the edges of a page turn it, the middle shows or hides the bars, and an edge is at least a finger wide")
    func tapZones() {
        // An iPhone: the text starts 40 in, which is under a finger, so the zones reach into the text.
        func phone(_ x: CGFloat) -> PageTurnRules.TapZone {
            PageTurnRules.tapZone(x: x, textMinX: 40, textMaxX: 400, width: 440)
        }
        #expect(phone(10) == .previous)
        #expect(phone(43) == .previous)
        #expect(phone(44) == .center)
        #expect(phone(396) == .center)
        #expect(phone(397) == .next)
        // An iPad: the margin is wider than a finger, so it is the zone.
        #expect(PageTurnRules.tapZone(x: 70, textMinX: 78, textMaxX: 742, width: 820) == .previous)
        #expect(PageTurnRules.tapZone(x: 80, textMinX: 78, textMaxX: 742, width: 820) == .center)
        #expect(PageTurnRules.tapZone(x: 745, textMinX: 78, textMaxX: 742, width: 820) == .next)
    }
}
