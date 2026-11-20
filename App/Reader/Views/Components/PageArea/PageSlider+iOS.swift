import UIKit

/// Slide and Fast Fade, like Apple Books. Taps and swipes turn the page the same way in each style:
/// in Slide the page lifts off as a rounded card and follows the finger, uncovering the next page already lying beneath it
/// (going back, the previous page slides in over it); Fast Fade cross-fades in place.
/// Curl stays with UIPageViewController (`PageTurnView`).
/// It moves the pages and runs the animation. Whether a turn counts, and where a tap lands, is `PageTurnRules`.
final class PageSlider: UIView, UIGestureRecognizerDelegate {
    /// A Slide: the page the turn goes to, and which way.
    private struct Slide {
        let view: PageTextView
        let isForward: Bool
    }

    /// What the slider is doing. Only one thing at a time.
    private enum Turn {
        case idle
        /// A finger is moving a lifted page.
        case dragging(Slide)
        /// An animation carries the turn to its end (a fade has no `slide`). `finish` puts the last frame in place and ends the turn.
        case animating(UIViewPropertyAnimator, slide: Slide?, finish: () -> Void)
    }

    private var content: PageContent?
    private var actions = PageActions.none
    private var currentView: PageTextView?
    private let cache = PageViewCache()
    private var turn = Turn.idle

    private var isTurning: Bool {
        if case .idle = turn { false } else { true }
    }

    /// Fast Fade, or else Slide (Curl never gets here: it has its own pager).
    private var isFade: Bool {
        content?.settings.pageTurnStyle == .fastFade
    }

    private var cardCornerRadius: CGFloat {
        traitCollection.userInterfaceIdiom == .pad ? PageTurnKnobs.padCornerRadius : PageTurnKnobs.phoneCornerRadius
    }

    /// Far enough for the moving page and its shadow to clear the screen.
    private var slideDistance: CGFloat {
        bounds.width + PageTurnKnobs.shadowRadius * 2
    }

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
        self.actions = actions
        // Nothing changed: no page to bring up to date.
        guard content != self.content else { return }
        self.content = content
        // Mid-turn, the turn decides what is shown; it reads the new content when it ends.
        guard !isTurning else { return }
        showShownPage()
    }

    private func showShownPage() {
        guard let content else { return }
        defer { currentView?.focusWhenVisible(content.readingFocus) }
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

    private func pageView(for page: Page, content: PageContent) -> PageTextView {
        cache.view(for: page, content: content, actions: actions) { [weak self] isForward in
            self?.turnPage(isForward: isForward)
        }
    }

    /// After the screen settles, so building them never lands in the middle of a turn.
    private func prepareNeighborsLater() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !isTurning, bounds.width > 0, let content, let page = currentView?.page else { return }
            let neighbors = [true, false].compactMap { content.neighbor(of: page, isForward: $0) }
            cache.keep(Set([page.number] + neighbors.map(\.number)))
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
        guard case .idle = turn, let content, let currentView,
              let page = content.neighbor(of: currentView.page, isForward: isForward) else { return }
        let next = pageView(for: page, content: content)
        if isFade {
            fade(to: next)
        } else if let slide = beginSlide(to: next, isForward: isForward) {
            settle(slide, toEnd: true, initialVelocity: 0)
        }
    }

    private func finishRunningTurn() {
        guard case .animating(let animator, _, let finish) = turn else { return }
        animator.stopAnimation(true)
        finish()
    }

    /// Runs `animator`, then `end`, once: whether the animator finishes, or a new turn ends this one early.
    private func animate(_ animator: UIViewPropertyAnimator, slide: Slide?, end: @escaping () -> Void) {
        var isFinished = false
        let finish: () -> Void = { [weak self] in
            guard !isFinished else { return }
            isFinished = true
            self?.turn = .idle
            end()
        }
        animator.addCompletion { _ in finish() }
        turn = .animating(animator, slide: slide, finish: finish)
        animator.startAnimation()
    }

    private func fade(to next: PageTextView) {
        next.frame = bounds
        next.alpha = 0
        addSubview(next)
        let animator = UIViewPropertyAnimator(duration: PageTurnKnobs.fadeDuration, curve: .easeOut) { next.alpha = 1 }
        animate(animator, slide: nil) { [weak self] in
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

    private func beginSlide(to next: PageTextView, isForward: Bool) -> Slide? {
        guard let currentView else { return nil }
        next.frame = bounds
        if isForward {
            // Already in place under the current page, which slides off it.
            insertSubview(next, belowSubview: currentView)
        } else {
            // Comes in from the left over the current page, which stays put.
            next.frame.origin.x = -slideDistance
            addSubview(next)
        }
        let slide = Slide(view: next, isForward: isForward)
        lift(movingView(of: slide))
        setSlideProgress(0, of: slide)
        return slide
    }

    /// The page that moves: the current one going forward, the previous one going back.
    private func movingView(of slide: Slide) -> PageTextView? {
        slide.isForward ? currentView : slide.view
    }

    /// A lifted page is a rounded card with a shadow on the page beneath. Not masked, so the shadow shows;
    /// the text never reaches the corners, so only the background needs rounding.
    private func lift(_ view: PageTextView?) {
        guard let layer = view?.layer else { return }
        layer.cornerRadius = cardCornerRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = PageTurnKnobs.shadowOpacity
        layer.shadowRadius = PageTurnKnobs.shadowRadius
        layer.shadowOffset = .zero
        layer.shadowPath = UIBezierPath(roundedRect: CGRect(origin: .zero, size: bounds.size), cornerRadius: cardCornerRadius).cgPath
    }

    /// Puts a lifted page flat again.
    private func drop(_ view: PageTextView?) {
        guard let layer = view?.layer else { return }
        layer.cornerRadius = 0
        layer.shadowOpacity = 0
        layer.shadowPath = nil
    }

    /// How far a Slide has gone, from 0 (the current page) to 1 (the next one). The lifted page covers the whole way;
    /// the page beneath it moves the last 20%, from the right, at the same pace.
    private func setSlideProgress(_ progress: CGFloat, of slide: Slide) {
        guard let currentView else { return }
        let beneathShift = PageTurnKnobs.beneathOffset * bounds.width
        if slide.isForward {
            currentView.frame.origin.x = -progress * slideDistance
            slide.view.frame.origin.x = (1 - progress) * beneathShift
        } else {
            // Going back the same motion runs in reverse: the previous page covers this one, which eases off to the right.
            slide.view.frame.origin.x = (progress - 1) * slideDistance
            currentView.frame.origin.x = progress * beneathShift
        }
    }

    private func settle(_ slide: Slide, toEnd: Bool, initialVelocity: CGFloat) {
        let timing = UISpringTimingParameters(dampingRatio: 1, initialVelocity: CGVector(dx: initialVelocity, dy: 0))
        let animator = UIViewPropertyAnimator(duration: PageTurnKnobs.slideDuration, timingParameters: timing)
        animator.addAnimations { [weak self] in self?.setSlideProgress(toEnd ? 1 : 0, of: slide) }
        animate(animator, slide: slide) { [weak self] in
            guard let self else { return }
            setSlideProgress(toEnd ? 1 : 0, of: slide)
            drop(movingView(of: slide))
            if toEnd {
                turnEnded(on: slide.view)
            } else {
                slide.view.removeFromSuperview()
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
        if isFade {
            fadePanned(pan)
        } else {
            slidePanned(pan)
        }
    }

    private func fadePanned(_ pan: UIPanGestureRecognizer) {
        guard pan.state == .ended,
              let isForward = PageTurnRules.fadeTurnsForward(translation: pan.translation(in: self).x, velocity: pan.velocity(in: self).x)
        else { return }
        turnPage(isForward: isForward)
    }

    private func slidePanned(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: self).x
        switch pan.state {
        case .began:
            finishRunningTurn()
        case .changed:
            guard let slide = slideBeingDragged(translation: translation) else { return }
            setSlideProgress(dragProgress(translation, of: slide), of: slide)
        case .ended, .cancelled, .failed:
            guard case .dragging(let slide) = turn else { return }
            let velocity = pan.velocity(in: self).x * (slide.isForward ? -1 : 1)
            let progress = dragProgress(translation, of: slide)
            let completes = pan.state == .ended && PageTurnRules.completes(progress: progress, velocity: velocity)
            let remaining = (completes ? 1 - progress : progress) * slideDistance
            settle(slide, toEnd: completes,
                   initialVelocity: PageTurnRules.springVelocity(fingerVelocity: velocity, remaining: remaining))
        default:
            break
        }
    }

    /// The Slide a finger is moving: the one already started, or a new one toward the page the finger is dragging to.
    private func slideBeingDragged(translation: CGFloat) -> Slide? {
        if case .dragging(let slide) = turn { return slide }
        guard translation != 0, case .idle = turn, let content, let currentView,
              let page = content.neighbor(of: currentView.page, isForward: translation < 0),
              let slide = beginSlide(to: pageView(for: page, content: content), isForward: translation < 0) else { return nil }
        turn = .dragging(slide)
        return slide
    }

    private func dragProgress(_ translation: CGFloat, of slide: Slide) -> CGFloat {
        PageTurnRules.dragProgress(translation: translation, isForward: slide.isForward, distance: slideDistance)
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
