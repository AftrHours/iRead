import CoreGraphics
import Foundation

/// How a page turn feels and when it counts, in one place.
enum PageTurnKnobs {
    /// Measured from Apple Books: a tap turn takes about 0.42s, quick at first, then a long settle.
    static let slideDuration: TimeInterval = 0.42
    /// Apple Books' Fast Fade takes 150–180 ms.
    static let fadeDuration: TimeInterval = 0.18
    /// The lifted page's shadow, which also has to leave the screen before the turn ends.
    static let shadowRadius: CGFloat = 12
    static let shadowOpacity: Float = 0.22
    /// The page beneath starts this share of the width off to the right, so it seems to come in from there:
    /// 80% in when the turn starts, all the way in when it ends.
    static let beneathOffset: CGFloat = 0.2
    /// About the screen's own corners, as the cards fill it: an iPhone's are round, an iPad's much less so.
    static let phoneCornerRadius: CGFloat = 55
    static let padCornerRadius: CGFloat = 18
    /// A swipe this far, or this fast (points and points per second), turns the page.
    static let turnDistance: CGFloat = 36
    static let turnVelocity: CGFloat = 400
    /// A released Slide carries on once it is this share of the way.
    static let completionProgress: CGFloat = 0.3
    /// The edge zones that turn the page are at least this wide.
    static let minTapSize: CGFloat = 44
}

/// The decisions of a page turn, apart from the views that draw it.
enum PageTurnRules {
    enum TapZone: Equatable {
        case previous
        case next
        case center
    }

    /// Whether a released Slide carries on to the next page, or goes back. `velocity` is toward the next page.
    /// Far enough or fast enough carries on, unless it is flicked back.
    static func completes(progress: CGFloat, velocity: CGFloat) -> Bool {
        velocity > -PageTurnKnobs.turnVelocity
            && (progress > PageTurnKnobs.completionProgress || velocity > PageTurnKnobs.turnVelocity)
    }

    /// Fast Fade follows no finger: a swipe far or fast enough fades to the next page (true) or the previous one (false).
    /// nil when the swipe is neither.
    static func fadeTurnsForward(translation: CGFloat, velocity: CGFloat) -> Bool? {
        let distance = abs(translation) >= PageTurnKnobs.turnDistance
            ? translation
            : (abs(velocity) >= PageTurnKnobs.turnVelocity ? velocity : 0)
        return distance == 0 ? nil : distance < 0
    }

    /// How far a drag of `translation` has taken a Slide, from 0 to 1, when the page has `distance` to travel.
    static func dragProgress(translation: CGFloat, isForward: Bool, distance: CGFloat) -> CGFloat {
        guard distance > 0 else { return 0 }
        let travelled = isForward ? -translation : translation
        return min(max(travelled / distance, 0), 1)
    }

    /// The spring's start velocity is relative to the distance left, so the pages leave the finger at its speed.
    static func springVelocity(fingerVelocity: CGFloat, remaining: CGFloat) -> CGFloat {
        remaining > 1 ? abs(fingerVelocity) / remaining : 0
    }

    /// Where a tap on a page lands: the edges turn the page, the middle shows or hides the bars.
    /// On an iPhone the margin is under 44pt, so the edge zones reach into the text.
    static func tapZone(x: CGFloat, textMinX: CGFloat, textMaxX: CGFloat, width: CGFloat) -> TapZone {
        if x < max(textMinX, PageTurnKnobs.minTapSize) {
            .previous
        } else if x > min(textMaxX, width - PageTurnKnobs.minTapSize) {
            .next
        } else {
            .center
        }
    }
}
