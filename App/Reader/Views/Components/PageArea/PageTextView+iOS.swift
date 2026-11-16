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
            if oldValue != highlights { showBackgrounds() }
        }
    }
    private var actions: PageActions
    private let textView = UITextView(usingTextLayoutManager: false)
    private let titleLabel = UILabel()
    private let chapterLabel = UILabel()
    private let pageLabel = UILabel()
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
        titleLabel.font = .systemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: .semibold)
        titleLabel.textColor = textColor
        chapterLabel.font = .preferredFont(forTextStyle: .caption2)
        chapterLabel.textColor = textColor.withAlphaComponent(Self.chapterTitleAlpha)
        pageLabel.font = .preferredFont(forTextStyle: .caption1)
        pageLabel.textColor = textColor
        for label in [titleLabel, chapterLabel] {
            label.textAlignment = .center
            label.lineBreakMode = .byTruncatingTail
            addSubview(label)
        }
        addSubview(pageLabel)
    }

    /// Whether this view already shows `page` as `content` has it, so it can stay on screen instead of being built again.
    func isShowing(_ page: Page, in content: PageContent) -> Bool {
        self.page == page
            && settings == content.settings
            && horizontalMargin == content.horizontalMargin
            && marks == content.marks(on: page)
    }

    /// Brings what changes without a new layout (the labels, where they sit, the highlights, what a tap does) up to date with `content`.
    func refresh(from content: PageContent, actions: PageActions) {
        chrome = content.chrome(of: page)
        layout = content.layout
        highlights = content.highlights(on: page)
        self.actions = actions
    }

    private func showChrome() {
        titleLabel.text = chrome.title
        chapterLabel.text = chrome.chapterTitle
        pageLabel.text = chrome.pageLabel
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = Viewport.textFrame(in: layout.text, horizontalMargin: horizontalMargin)
        // Title over chapter, centred in the header.
        let header = layout.header
        let titleHeight = titleLabel.intrinsicContentSize.height
        let chapterHeight = chapterLabel.intrinsicContentSize.height
        let titlesTop = header.midY - (titleHeight + Self.titleSpacing + chapterHeight) / 2
        titleLabel.frame = CGRect(x: header.minX, y: titlesTop, width: header.width, height: titleHeight)
        chapterLabel.frame = CGRect(x: header.minX, y: titlesTop + titleHeight + Self.titleSpacing,
                                    width: header.width, height: chapterHeight)
        // Level with the text's left edge, centred in the footer's height, level with the ••• button.
        let pageLabelSize = pageLabel.intrinsicContentSize
        pageLabel.frame = CGRect(x: textView.frame.minX, y: layout.footer.midY - pageLabelSize.height / 2,
                                 width: min(pageLabelSize.width, textView.frame.width), height: pageLabelSize.height)
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
