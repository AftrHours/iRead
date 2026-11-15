import UIKit

/// Slide and Fast Fade, like Apple Books. Taps and swipes turn the page the same way in each style:
/// in Slide the page lifts off as a rounded card and follows the finger, uncovering the next page already lying beneath it
/// (going back, the previous page slides in over it); Fast Fade cross-fades in place.
/// Curl stays with UIPageViewController (`PageTurnView`).
final class PageSlider: UIView, UIGestureRecognizerDelegate {
    /// Measured from Apple Books: a tap turn takes about 0.42s, quick at first, then a long settle.
    private static let slideDuration: TimeInterval = 0.42
    /// Apple Books' Fast Fade takes 150–180 ms.
    private static let fadeDuration: TimeInterval = 0.18
    /// The moving page's shadow, which also has to leave the screen before the turn ends.
    private static let shadowRadius: CGFloat = 12
    /// The page beneath starts this share of the width off to the right, so it seems to come in from there:
    /// 80% in when the turn starts, all the way in when it ends.
    private static let beneathOffset: CGFloat = 0.2
    /// About the screen's own corners, as the cards fill it: an iPhone's are round, an iPad's much less so.
    private var cardCornerRadius: CGFloat { traitCollection.userInterfaceIdiom == .pad ? 18 : 55 }
    /// A swipe this far, or this fast, turns the page.
    private static let turnDistance: CGFloat = 36
    private static let turnVelocity: CGFloat = 400

    private var content: PageContent?
    private var actions = PageActions.none
    private var currentView: PageTextView?
    /// Built ahead of time, so a turn never waits for a page to lay out. Keyed by page number.
    private var preparedViews: [Int: PageTextView] = [:]
    /// The page a Slide is moving to, and which way.
    private var turn: (view: PageTextView, isForward: Bool)?
    private var animator: UIViewPropertyAnimator?
    /// Puts the running animation's last frame in place and ends the turn. Run once, by the animator or by a new turn.
    private var endTurn: (() -> Void)?

    private var isTurning: Bool { turn != nil || endTurn != nil }
    private var style: PageTurnStyle { content?.settings.pageTurnStyle ?? .slide }
    /// Far enough for the moving page and its shadow to clear the screen.
    private var slideDistance: CGFloat { bounds.width + Self.shadowRadius * 2 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    // MARK: Content

    func update(_ content: PageContent, actions: PageActions) {
        self.content = content
        self.actions = actions
        // Mid-turn, the turn decides what is shown; it reads the new content when it ends.
        guard !isTurning else { return }
        showShownPage()
    }

    private func showShownPage() {
        guard let content else { return }
        if let currentView, currentView.isShowing(content.shownPage, in: content) {
            currentView.refresh(from: content, actions: actions)
            return
        }
        show(pageView(for: content.shownPage, content: content))
    }

    /// After a turn: the content may have changed meanwhile (marks, settings). A different shown page is left alone,
    /// since it may only be the content from before the turn.
    private func refreshCurrentPage() {
        guard let content, let currentView, content.shownPage == currentView.page else { return }
        showShownPage()
    }

    private func show(_ view: PageTextView) {
        if currentView !== view {
            currentView?.removeFromSuperview()
        }
        insertSubview(view, at: 0)
        view.frame = bounds
        currentView = view
        prepareNeighborsLater()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !isTurning else { return }
        currentView?.frame = bounds
    }

    /// A prepared page when one still fits the content, else a new one.
    private func pageView(for page: Page, content: PageContent) -> PageTextView {
        if let view = preparedViews[page.number], view.isShowing(page, in: content) {
            view.refresh(from: content, actions: actions)
            return view
        }
        let view = PageTextView(page: page, content: content, actions: actions,
                                onEdgeTapped: { [weak self] isForward in self?.turnPage(isForward: isForward) })
        preparedViews[page.number] = view
        return view
    }

    /// After the screen settles, so building them never lands in the middle of a turn.
    private func prepareNeighborsLater() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !isTurning, bounds.width > 0, let content, let page = currentView?.page else { return }
            let neighbors = [content.neighbor(of: page, isForward: true), content.neighbor(of: page, isForward: false)].compactMap { $0 }
            let keep = Set([page.number] + neighbors.map(\.number))
            preparedViews = preparedViews.filter { keep.contains($0.key) }
            for neighbor in neighbors {
                let view = pageView(for: neighbor, content: content)
                view.frame = bounds
                view.prepareLayout()
            }
        }
    }

    // MARK: Turning

    private func turnPage(isForward: Bool) {
        // A tap during a turn ends it at once and starts the next, so quick taps keep up.
        finishRunningTurn()
        guard let content, let currentView, let page = content.neighbor(of: currentView.page, isForward: isForward) else { return }
        let next = pageView(for: page, content: content)
        switch style {
        case .fastFade:
            fade(to: next)
        case .slide, .curl:
            beginSlide(to: next, isForward: isForward)
            runSlide(toEnd: true, initialVelocity: 0)
        }
    }

    private func finishRunningTurn() {
        animator?.stopAnimation(true)
        animator = nil
        endTurn?()
    }

    private func run(_ animator: UIViewPropertyAnimator, end: @escaping () -> Void) {
        endTurn = { [weak self] in
            self?.endTurn = nil
            self?.animator = nil
            end()
        }
        animator.addCompletion { [weak self] _ in self?.endTurn?() }
        self.animator = animator
        animator.startAnimation()
    }

    private func fade(to next: PageTextView) {
        next.frame = bounds
        next.alpha = 0
        addSubview(next)
        let animator = UIViewPropertyAnimator(duration: Self.fadeDuration, curve: .easeOut) { next.alpha = 1 }
        run(animator) { [weak self] in
            next.alpha = 1
            self?.turnEnded(on: next)
        }
    }

    private func turnEnded(on next: PageTextView) {
        let previous = currentView
        currentView = next
        if previous !== next {
            previous?.removeFromSuperview()
        }
        next.frame = bounds
        actions.onPageChanged(next.page)
        refreshCurrentPage()
        prepareNeighborsLater()
    }

    // MARK: Slide

    private func beginSlide(to next: PageTextView, isForward: Bool) {
        guard let currentView else { return }
        next.frame = bounds
        if isForward {
            // Already in place under the current page, which slides off it.
            insertSubview(next, belowSubview: currentView)
        } else {
            // Comes in from the left over the current page, which stays put.
            next.frame.origin.x = -slideDistance
            addSubview(next)
        }
        turn = (next, isForward)
        liftCard(movingView, true)
        setSlideProgress(0)
    }

    /// The page that moves: the current one going forward, the previous one going back.
    private var movingView: PageTextView? {
        guard let turn else { return nil }
        return turn.isForward ? currentView : turn.view
    }

    /// A lifted page is a rounded card with a shadow on the page beneath. Not masked, so the shadow shows;
    /// the text never reaches the corners, so only the background needs rounding.
    private func liftCard(_ view: PageTextView?, _ isLifted: Bool) {
        guard let layer = view?.layer else { return }
        layer.cornerRadius = isLifted ? cardCornerRadius : 0
        layer.cornerCurve = .continuous
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = isLifted ? 0.22 : 0
        layer.shadowRadius = Self.shadowRadius
        layer.shadowOffset = .zero
        layer.shadowPath = isLifted ? UIBezierPath(roundedRect: CGRect(origin: .zero, size: bounds.size),
                                                   cornerRadius: cardCornerRadius).cgPath : nil
    }

    /// How far a Slide has gone, from 0 (the current page) to 1 (the next one). The lifted page covers the whole way;
    /// the page beneath it moves the last 20%, from the right, at the same pace.
    private func setSlideProgress(_ progress: CGFloat) {
        guard let turn, let currentView else { return }
        let beneathShift = Self.beneathOffset * bounds.width
        if turn.isForward {
            currentView.frame.origin.x = -progress * slideDistance
            turn.view.frame.origin.x = (1 - progress) * beneathShift
        } else {
            // Going back the same motion runs in reverse: the previous page covers this one, which eases off to the right.
            turn.view.frame.origin.x = (progress - 1) * slideDistance
            currentView.frame.origin.x = progress * beneathShift
        }
    }

    private func runSlide(toEnd: Bool, initialVelocity: CGFloat) {
        let timing = UISpringTimingParameters(dampingRatio: 1, initialVelocity: CGVector(dx: initialVelocity, dy: 0))
        let animator = UIViewPropertyAnimator(duration: Self.slideDuration, timingParameters: timing)
        animator.addAnimations { [weak self] in self?.setSlideProgress(toEnd ? 1 : 0) }
        run(animator) { [weak self] in
            guard let self, let turn else { return }
            setSlideProgress(toEnd ? 1 : 0)
            liftCard(movingView, false)
            self.turn = nil
            if toEnd {
                turnEnded(on: turn.view)
            } else {
                turn.view.removeFromSuperview()
                currentView?.frame = bounds
                refreshCurrentPage()
            }
        }
    }

    // MARK: Swipes

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y)
    }

    @objc private func panned(_ pan: UIPanGestureRecognizer) {
        switch style {
        case .fastFade: fadePanned(pan)
        case .slide, .curl: slidePanned(pan)
        }
    }

    /// Fast Fade follows no finger: a swipe far or fast enough fades to the next page.
    private func fadePanned(_ pan: UIPanGestureRecognizer) {
        guard pan.state == .ended else { return }
        let translation = pan.translation(in: self).x
        let velocity = pan.velocity(in: self).x
        let distance = abs(translation) >= Self.turnDistance ? translation : (abs(velocity) >= Self.turnVelocity ? velocity : 0)
        guard distance != 0 else { return }
        turnPage(isForward: distance < 0)
    }

    private func slidePanned(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: self).x
        switch pan.state {
        case .began:
            finishRunningTurn()
        case .changed:
            if turn == nil {
                guard translation != 0, let content, let currentView,
                      let page = content.neighbor(of: currentView.page, isForward: translation < 0) else { return }
                beginSlide(to: pageView(for: page, content: content), isForward: translation < 0)
            }
            guard let turn else { return }
            let progress = (turn.isForward ? -translation : translation) / slideDistance
            setSlideProgress(min(max(progress, 0), 1))
        case .ended, .cancelled, .failed:
            guard let turn else { return }
            let velocity = pan.velocity(in: self).x * (turn.isForward ? -1 : 1)
            let progress = min(max((turn.isForward ? -translation : translation) / slideDistance, 0), 1)
            let completes = pan.state == .ended && velocity > -Self.turnVelocity && (progress > 0.3 || velocity > Self.turnVelocity)
            let remaining = (completes ? 1 - progress : progress) * slideDistance
            // The spring's velocity is relative to the distance left, so the cards leave the finger at its speed.
            let relativeVelocity = remaining > 1 ? abs(velocity) / remaining : 0
            runSlide(toEnd: completes, initialVelocity: relativeVelocity)
        default:
            break
        }
    }

    // MARK: Accessibility

    /// VoiceOver's three-finger swipe turns the page.
    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        switch direction {
        case .left, .next: turnPage(isForward: true)
        case .right, .previous: turnPage(isForward: false)
        default: return false
        }
        return true
    }
}
