import UIKit

/// A whole screen's page: the book and chapter on top, the text, and the page label at the bottom, so all of it turns together.
final class PageTextView: UIView {
    let page: Page
    let settings: ReadingSettings
    let horizontalMargin: CGFloat
    let marks: [Mark]
    /// Labels only, so they change in place (focus mode shortens the page label) without laying the text out again.
    private(set) var chrome: PageChrome {
        didSet { showChrome() }
    }
    private(set) var frames: PageFrames {
        didSet { setNeedsLayout() }
    }
    private var actions: PageActions
    private let textView = UITextView(usingTextLayoutManager: false)
    private let titleLabel = UILabel()
    private let chapterLabel = UILabel()
    private let pageLabel = UILabel()
    private let onEdgeTapped: (_ isForward: Bool) -> Void

    private static let minTapSize: CGFloat = 44
    /// The top bar's title-to-chapter spacing.
    private static let titleSpacing: CGFloat = 10

    /// `page` as `content` shows it. The pager that owns the view says what its edge taps do.
    init(page: Page, content: PageContent, actions: PageActions, onEdgeTapped: @escaping (_ isForward: Bool) -> Void) {
        self.page = page
        settings = content.settings
        horizontalMargin = content.horizontalMargin
        marks = content.marks(on: page)
        chrome = content.chrome(page)
        frames = content.frames
        self.actions = actions
        self.onEdgeTapped = onEdgeTapped
        super.init(frame: .zero)
        backgroundColor = PageTextStyle.backgroundColor(for: settings.theme)
        textView.attributedText = attributedText()
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        addSubview(textView)
        // The same type as the top and bottom bars had.
        let textColor = PageTextStyle.textColor(for: settings.theme)
        let subheadline = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.font = .systemFont(ofSize: subheadline.pointSize, weight: .semibold)
        titleLabel.textColor = textColor
        chapterLabel.font = .preferredFont(forTextStyle: .caption2)
        chapterLabel.textColor = textColor.withAlphaComponent(0.5)
        pageLabel.font = .preferredFont(forTextStyle: .caption1)
        pageLabel.textColor = textColor
        for label in [titleLabel, chapterLabel] {
            label.textAlignment = .center
            label.lineBreakMode = .byTruncatingTail
            addSubview(label)
        }
        addSubview(pageLabel)
        showChrome()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    /// Whether this view already shows `page` as `content` has it, so it can stay on screen instead of being built again.
    func isShowing(_ page: Page, in content: PageContent) -> Bool {
        self.page == page
            && settings == content.settings
            && horizontalMargin == content.horizontalMargin
            && marks == content.marks(on: page)
    }

    /// Brings what changes without a new layout (the labels, where they sit, what a tap does) up to date with `content`.
    func refresh(from content: PageContent, actions: PageActions) {
        chrome = content.chrome(page)
        frames = content.frames
        self.actions = actions
    }

    private func showChrome() {
        titleLabel.text = chrome.title
        chapterLabel.text = chrome.chapterTitle.uppercased()
        pageLabel.text = chrome.pageLabel
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let textBounds = frames.text.isEmpty ? bounds : frames.text
        textView.frame = Viewport.textFrame(in: textBounds, horizontalMargin: horizontalMargin)
        // Title over chapter, centred in the header like the top bar's.
        let header = frames.header
        let titleHeight = titleLabel.intrinsicContentSize.height
        let chapterHeight = chapterLabel.intrinsicContentSize.height
        let titlesTop = header.midY - (titleHeight + Self.titleSpacing + chapterHeight) / 2
        titleLabel.frame = CGRect(x: header.minX, y: titlesTop, width: header.width, height: titleHeight)
        chapterLabel.frame = CGRect(x: header.minX, y: titlesTop + titleHeight + Self.titleSpacing,
                                    width: header.width, height: chapterHeight)
        // At the footer's leading edge, centred in its height like the bottom bar's.
        let footer = frames.footer
        let pageLabelSize = pageLabel.intrinsicContentSize
        pageLabel.frame = CGRect(x: footer.minX, y: footer.midY - pageLabelSize.height / 2,
                                 width: min(pageLabelSize.width, footer.width), height: pageLabelSize.height)
    }

    /// Lays the text out now, so showing the page later costs nothing.
    func prepareLayout() {
        layoutIfNeeded()
        textView.layoutManager.ensureLayout(for: textView.textContainer)
    }

    private func attributedText() -> NSAttributedString {
        let text = PageTextStyle.attributedText(page.text, settings: settings)
        for mark in marks {
            switch mark.kind {
            case .underline:
                text.addAttributes([
                    .underlineStyle: NSUnderlineStyle.single.union(.patternDot).rawValue,
                    .underlineColor: UIColor.secondaryLabel
                ], range: mark.range)
            case .highlight:
                text.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.3), range: mark.range)
            }
        }
        return text
    }

    @objc private func tapped(_ tap: UITapGestureRecognizer) {
        let x = tap.location(in: self).x
        // Underlines first: on an iPhone the margin is under 44pt, so the edge zones reach into the text.
        if let (mark, rect) = underline(at: tap.location(in: textView)) {
            actions.onMarkTapped(mark, textView.convert(rect, to: self))
        } else if x < max(textView.frame.minX, Self.minTapSize) {
            onEdgeTapped(false)
        } else if x > min(textView.frame.maxX, bounds.width - Self.minTapSize) {
            onEdgeTapped(true)
        } else {
            actions.onCenterTapped()
        }
    }

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
                let padding = max(0, (Self.minTapSize - rect.height) / 2)
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
