import SwiftUI
import UIKit

/// A whole screen's page: the book and chapter on top, the text, and the page label at the bottom, so all of it turns together.
/// It only draws what `PageContent` says and reports taps; where things go, what to highlight and what a tap means are decided elsewhere.
final class PageTextView: UIView {
    let page: Page
    let settings: ReadingSettings
    let horizontalMargin: CGFloat
    let marks: [Mark]
    /// What changes without laying the text out again (focus mode shortens the page label), and is set in place.
    private(set) var chrome: PageChrome {
        didSet { showChrome() }
    }
    private(set) var layout: PageLayout {
        didSet { setNeedsLayout() }
    }
    private(set) var highlights: [NSRange] {
        didSet {
            guard oldValue != highlights else { return }
            guard window != nil else { return showBackgrounds() }
            UIView.transition(with: textView, duration: 0.25, options: [.transitionCrossDissolve, .allowUserInteraction]) {
                self.showBackgrounds()
            }
        }
    }
    private(set) var mentionedRange: NSRange? {
        didSet {
            if oldValue != mentionedRange { setNeedsLayout() }
        }
    }
    private var mentionTag: UIHostingController<MentionPopover>?
    private var isMentionTagHiding = false
    private var actions: PageActions
    private let textView = UITextView(usingTextLayoutManager: false)
    private let titleLabel = UILabel()
    private let chapterLabel = UILabel()
    private let pageLabel = UILabel()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private let returnMark = UIView()
    private lazy var modeControl = ReaderAccessibilityButton(container: self) { [weak self] in
        self?.actions.onCenterTapped()
    }
    private var referenceButtons: [(mark: Mark, button: ReaderAccessibilityButton)] = []
    private var focusRequest: ReaderFocusRequest?
    private var focusTask: Task<Void, Never>?
    private let onEdgeTapped: (_ isForward: Bool) -> Void

    /// Between the book title and the chapter title under it.
    private static let titleSpacing: CGFloat = 10
    /// The chapter title is the book title's colour, faded.
    private static let chapterTitleAlpha: CGFloat = 0.5

    /// `page` as `content` shows it. The pager that owns the view says what its edge taps do.
    init(page: Page, content: PageContent, actions: PageActions, onEdgeTapped: @escaping (_ isForward: Bool) -> Void) {
        self.page = page
        settings = content.settings
        horizontalMargin = content.horizontalMargin
        marks = content.marks(on: page)
        chrome = content.chrome(of: page)
        layout = content.layout
        highlights = content.highlights(on: page)
        mentionedRange = content.mentionedRange(on: page)
        self.actions = actions
        self.onEdgeTapped = onEdgeTapped
        super.init(frame: .zero)
        backgroundColor = PageTextStyle.backgroundColor(for: settings.theme)
        configureTextView()
        configureLabels()
        showChrome()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func configureTextView() {
        textView.attributedText = PageTextStyle.attributedText(page.text, settings: settings, marks: marks)
        showBackgrounds()
        textView.isAccessibilityElement = true
        textView.accessibilityTraits = .staticText
        textView.accessibilityValue = page.text
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        addSubview(textView)
    }

    /// The book title over the chapter title on top, the page label below: subheadline semibold, a faded caption, a caption.
    private func configureLabels() {
        let textColor = PageTextStyle.textColor(for: settings.theme)
        let standardSize = UITraitCollection(preferredContentSizeCategory: .large)
        let titleFont = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: standardSize)
        titleLabel.font = .systemFont(ofSize: titleFont.pointSize, weight: .semibold)
        titleLabel.accessibilityTraits = [.header, .staticText]
        chapterLabel.isAccessibilityElement = false
        titleLabel.textColor = textColor
        chapterLabel.font = .preferredFont(forTextStyle: .caption2, compatibleWith: standardSize)
        chapterLabel.textColor = textColor.withAlphaComponent(Self.chapterTitleAlpha)
        pageLabel.font = .preferredFont(forTextStyle: .caption1)
        pageLabel.textColor = textColor
        pageLabel.textAlignment = .center
        progressTrack.backgroundColor = UIColor(AppColors.progressBarBg)
        progressFill.backgroundColor = UIColor(AppColors.progressBarLine)
        returnMark.backgroundColor = AppColors.readerReturnMark
        progressTrack.layer.cornerRadius = PageLayoutKnobs.progressBarHeight / 2
        progressTrack.clipsToBounds = true
        progressTrack.isAccessibilityElement = false
        progressTrack.addSubview(progressFill)
        progressTrack.addSubview(returnMark)
        addSubview(progressTrack)
        for label in [titleLabel, chapterLabel] {
            label.textAlignment = .center
            label.lineBreakMode = .byTruncatingTail
            addSubview(label)
        }
        addSubview(pageLabel)
        let source = page.text as NSString
        for mark in marks.sorted(by: { $0.range.location < $1.range.location }) where mark.isUnderline {
            guard mark.range.length > 0, NSMaxRange(mark.range) <= source.length else { continue }
            let button = ReaderAccessibilityButton(container: self) { [weak self] in
                guard let self else { return }
                actions.onMarkTapped(mark, referenceRect(for: mark))
            }
            button.accessibilityLabel = "Reference: " + source.substring(with: mark.range)
            button.accessibilityHint = "Opens the earlier passage."
            referenceButtons.append((mark, button))
        }
        accessibilityElements = [titleLabel, textView] + referenceButtons.map { $0.button as NSObject } + [modeControl, pageLabel]
    }

    /// Whether this view already shows `page` as `content` has it, so it can stay on screen instead of being built again.
    /// Highlights don't count: `refresh` changes them in place, so they can fade.
    func isShowing(_ page: Page, in content: PageContent) -> Bool {
        self.page == page
            && settings == content.settings
            && horizontalMargin == content.horizontalMargin
            && marks.filter(\.isUnderline) == content.marks(on: page).filter(\.isUnderline)
    }

    /// Brings what changes without a new layout (the labels, where they sit, the highlights, what a tap does) up to date with `content`.
    func refresh(from content: PageContent, actions: PageActions) {
        chrome = content.chrome(of: page)
        layout = content.layout
        highlights = content.highlights(on: page)
        mentionedRange = content.mentionedRange(on: page)
        self.actions = actions
    }

    private func showChrome() {
        titleLabel.text = chrome.title
        chapterLabel.text = chrome.chapterTitle.uppercased()
        titleLabel.accessibilityLabel = [chrome.title, chrome.chapterTitle].filter { !$0.isEmpty }.joined(separator: ", ")
        titleLabel.accessibilityValue = chrome.readingModeDescription
        modeControl.accessibilityLabel = "Reading mode"
        modeControl.accessibilityValue = chrome.readingModeDescription
        modeControl.accessibilityHint = chrome.isReadingMode ? "Double-tap to show references." : "Double-tap to hide references."
        let modeAction = chrome.isReadingMode ? "Turn reading mode off and show references" : "Turn reading mode on and hide references"
        textView.accessibilityCustomActions = [UIAccessibilityCustomAction(name: modeAction) { [weak self] _ in
            guard let self else { return false }
            actions.onCenterTapped()
            return true
        }]
        pageLabel.text = chrome.pageLabel
        progressTrack.isHidden = chrome.progress == nil
        returnMark.isHidden = chrome.returnMark == nil
        setNeedsLayout()
    }

    // Only the pager's displayed view receives this call. Preparing a neighbouring page must stay silent.
    func focusWhenVisible(_ request: ReaderFocusRequest?) {
        guard UIAccessibility.isVoiceOverRunning, focusRequest != request else { return }
        focusTask?.cancel()
        focusRequest = request
        textView.accessibilityLabel = request?.target == .chapterAndContent ? chrome.chapterTitle : nil
        scheduleFocus()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        focusTask?.cancel()
        if window != nil { scheduleFocus() }
    }

    private func scheduleFocus() {
        guard window != nil, let request = focusRequest else { return }
        focusTask = Task { @MainActor [weak self] in
            await Task.yield()
            // A Contents sheet or reference popover owns VoiceOver focus until dismissal finishes.
            while self?.window?.rootViewController?.presentedViewController != nil {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
            guard let self, !Task.isCancelled, window != nil, UIAccessibility.isVoiceOverRunning,
                  actions.claimReadingFocus(request.id) else { return }
            layoutIfNeeded()
            if case let .passage(text) = request.target {
                let announcement = NSAttributedString(
                    string: text, attributes: [.accessibilitySpeechAnnouncementPriority: UIAccessibilityPriority.high]
                )
                UIAccessibility.post(notification: .announcement, argument: announcement)
                return
            }
            let isOpening = request.target == .heading
            let target: UIView = isOpening ? titleLabel : textView
            UIAccessibility.post(notification: isOpening ? .screenChanged : .layoutChanged, argument: target)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = Viewport.textFrame(in: layout.text, horizontalMargin: horizontalMargin)
        // Title over chapter, centred in the header.
        let header = layout.header.insetBy(dx: layout.header.height + 4, dy: 0)
        let titleHeight = titleLabel.intrinsicContentSize.height
        let chapterHeight = chapterLabel.intrinsicContentSize.height
        let titlesTop = header.midY - (titleHeight + Self.titleSpacing + chapterHeight) / 2
        titleLabel.frame = CGRect(x: header.minX, y: titlesTop, width: header.width, height: titleHeight)
        chapterLabel.frame = CGRect(x: header.minX, y: titlesTop + titleHeight + Self.titleSpacing,
                                    width: header.width, height: chapterHeight)
        layoutFooter()
        layoutMentionTag()
        modeControl.accessibilityFrameInContainerSpace = CGRect(x: bounds.midX - 22, y: layout.footer.midY - 22, width: 44, height: 44)
        for (mark, button) in referenceButtons {
            button.accessibilityFrameInContainerSpace = referenceRect(for: mark)
        }
    }

    private func referenceRect(for mark: Mark) -> CGRect {
        let manager = textView.layoutManager
        let glyphs = manager.glyphRange(forCharacterRange: mark.range, actualCharacterRange: nil)
        return textView.convert(manager.boundingRect(forGlyphRange: glyphs, in: textView.textContainer), to: self)
    }

    /// Lays the text out now, so showing the page later costs nothing.
    func prepareLayout() {
        layoutIfNeeded()
        textView.layoutManager.ensureLayout(for: textView.textContainer)
    }

    /// The highlights behind the text, in one purple. Edited in the text storage, so changing them never lays the page out again.
    private func showBackgrounds() {
        let storage = textView.textStorage
        storage.beginEditing()
        storage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: storage.length))
        for range in highlights {
            storage.addAttribute(.backgroundColor, value: AppColors.readerHighlight, range: range)
        }
        storage.endEditing()
    }

    @objc private func tapped(_ tap: UITapGestureRecognizer) {
        // Underlines first: the edge zones reach into the text.
        if let (mark, rect) = underline(at: tap.location(in: textView)) {
            actions.onMarkTapped(mark, textView.convert(rect, to: self))
            return
        }
        switch PageTurnRules.tapZone(x: tap.location(in: self).x, textMinX: textView.frame.minX, textMaxX: textView.frame.maxX,
                                     width: bounds.width) {
        case .previous: onEdgeTapped(false)
        case .next: onEdgeTapped(true)
        case .center: actions.onCenterTapped()
        }
    }

    /// The underline under `point`, with the line it is on. Each line counts as at least a finger tall.
    private func underline(at point: CGPoint) -> (Mark, CGRect)? {
        let layoutManager = textView.layoutManager
        for mark in marks where mark.isUnderline {
            let glyphs = layoutManager.glyphRange(forCharacterRange: mark.range, actualCharacterRange: nil)
            var tappedLine: CGRect?
            layoutManager.enumerateEnclosingRects(
                forGlyphRange: glyphs,
                withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                in: textView.textContainer
            ) { rect, stop in
                let padding = max(0, (PageTurnKnobs.minTapSize - rect.height) / 2)
                if rect.insetBy(dx: 0, dy: -padding).contains(point) {
                    tappedLine = rect
                    stop.pointee = true
                }
            }
            if let tappedLine {
                return (mark, tappedLine)
            }
        }
        return nil
    }
}

private extension PageTextView {
    func layoutFooter() {
        typealias Knobs = PageLayoutKnobs
        let footer = layout.footer
        let labelHeight = pageLabel.intrinsicContentSize.height
        let barHeight = progressTrack.isHidden ? 0 : Knobs.progressBarHeight + Knobs.progressBarGap
        let top = footer.midY - (barHeight + labelHeight) / 2
        let barWidth = min(Knobs.progressBarWidth, footer.width - 2 * footer.height)
        progressTrack.frame = CGRect(x: footer.midX - barWidth / 2, y: top, width: barWidth, height: Knobs.progressBarHeight)
        progressFill.frame = CGRect(x: 0, y: 0, width: barWidth * (chrome.progress ?? 0), height: Knobs.progressBarHeight)
        returnMark.frame = CGRect(x: barWidth * (chrome.returnMark ?? 0) - Knobs.returnMarkWidth / 2, y: 0,
                                  width: Knobs.returnMarkWidth, height: Knobs.progressBarHeight)
        let labelInset = footer.height + 4
        pageLabel.frame = CGRect(x: footer.minX + labelInset, y: top + barHeight,
                                 width: footer.width - 2 * labelInset, height: labelHeight)
    }

    func layoutMentionTag() {
        guard let range = mentionedRange, let firstLine = firstLineRect(of: range) else { return hideMentionTag() }
        let tag = mentionTag ?? makeMentionTag()
        let size = tag.sizeThatFits(in: bounds.size)
        let preferredX = firstLine.minX - MentionPopoverKnobs.arrowInset + 4
        let x = min(max(preferredX, PageLayoutKnobs.sideMargin), bounds.width - PageLayoutKnobs.sideMargin - size.width)
        // Bounds and center, not frame: the transform animates.
        tag.view.bounds = CGRect(origin: .zero, size: size)
        tag.view.center = CGPoint(x: x + size.width / 2, y: firstLine.minY - size.height / 2)
        guard tag.view.isHidden || isMentionTagHiding else { return }
        isMentionTagHiding = false
        tag.view.isHidden = false
        guard window != nil else { return }
        // Grows out of its arrow, like the reference card's popover.
        tag.view.alpha = 0
        tag.view.transform = UIAccessibility.isReduceMotionEnabled ? .identity : MentionPopoverKnobs.arrowScale(0.6, size: size)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0,
                       options: [.allowUserInteraction, .beginFromCurrentState]) {
            tag.view.alpha = 1
            tag.view.transform = .identity
        }
    }

    func hideMentionTag() {
        guard let view = mentionTag?.view, !view.isHidden, !isMentionTagHiding else { return }
        guard window != nil else { return view.isHidden = true }
        isMentionTagHiding = true
        UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
            view.alpha = 0
            if !UIAccessibility.isReduceMotionEnabled { view.transform = MentionPopoverKnobs.arrowScale(0.8, size: view.bounds.size) }
        } completion: { _ in
            guard self.isMentionTagHiding else { return }
            self.isMentionTagHiding = false
            view.isHidden = true
            view.alpha = 1
            view.transform = .identity
        }
    }

    func makeMentionTag() -> UIHostingController<MentionPopover> {
        let tag = UIHostingController(rootView: MentionPopover())
        // Otherwise the screen's safe area pushes it up.
        tag.safeAreaRegions = []
        tag.view.backgroundColor = .clear
        tag.view.isUserInteractionEnabled = false
        tag.view.accessibilityElementsHidden = true
        tag.view.isHidden = true
        addSubview(tag.view)
        mentionTag = tag
        return tag
    }

    /// Skips leading spaces: justified text stretches them onto the line before.
    func firstLineRect(of range: NSRange) -> CGRect? {
        let text = page.text as NSString
        guard range.length > 0, NSMaxRange(range) <= text.length else { return nil }
        var start = range.location
        while start < NSMaxRange(range), let scalar = UnicodeScalar(text.character(at: start)),
              CharacterSet.whitespacesAndNewlines.contains(scalar) {
            start += 1
        }
        guard start < NSMaxRange(range) else { return nil }
        let manager = textView.layoutManager
        let glyph = manager.glyphIndexForCharacter(at: start)
        let line = manager.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
        let character = manager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textView.textContainer)
        let firstLine = CGRect(x: character.minX, y: line.minY, width: line.maxX - character.minX, height: line.height)
        return textView.convert(firstLine, to: self)
    }
}

private final class ReaderAccessibilityButton: UIAccessibilityElement {
    private let perform: () -> Void

    init(container: UIView, perform: @escaping () -> Void) {
        self.perform = perform
        super.init(accessibilityContainer: container)
        accessibilityTraits = .button
    }

    override func accessibilityActivate() -> Bool {
        perform()
        return true
    }
}
