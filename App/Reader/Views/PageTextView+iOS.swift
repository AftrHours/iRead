import UIKit

final class PageTextView: UIView {
    let page: Page
    let settings: ReadingSettings
    let marks: [Mark]
    private let textView = UITextView(usingTextLayoutManager: false)
    private let onEdgeTapped: (_ isForward: Bool) -> Void
    private let onCenterTapped: () -> Void
    private let onMarkTapped: (Mark, CGRect) -> Void
    private var symbolButtons: [(mark: Mark, button: UIButton)] = []

    private static let minTapSize: CGFloat = 44
    private static let symbolGap: CGFloat = 0.5
    private static let symbolScale: CGFloat = 0.3

    init(page: Page, settings: ReadingSettings, marks: [Mark], onEdgeTapped: @escaping (_ isForward: Bool) -> Void,
         onCenterTapped: @escaping () -> Void, onMarkTapped: @escaping (Mark, CGRect) -> Void) {
        self.page = page
        self.settings = settings
        self.marks = marks
        self.onEdgeTapped = onEdgeTapped
        self.onCenterTapped = onCenterTapped
        self.onMarkTapped = onMarkTapped
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
        addSymbolButtons()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = PageTextStyle.textFrame(in: bounds)
        for (mark, button) in symbolButtons {
            button.frame = symbolFrame(for: mark)
        }
    }

    private func addSymbolButtons() {
        let symbolSize = PageTextStyle.font(settings: settings).pointSize * Self.symbolScale
        for mark in marks {
            guard case .symbol(let style, let entityName) = mark.kind else { continue }
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: style.systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: symbolSize)), for: .normal)
            button.tintColor = SymbolPalette.color(at: style.colorIndex)
            button.accessibilityLabel = entityName
            button.addAction(UIAction { [weak self, weak button] _ in
                guard let self, let button else { return }
                onMarkTapped(mark, button.frame)
            }, for: .primaryActionTriggered)
            addSubview(button)
            symbolButtons.append((mark, button))
        }
    }

    private func symbolFrame(for mark: Mark) -> CGRect {
        let font = PageTextStyle.font(settings: settings)
        let symbolSize = font.pointSize * Self.symbolScale
        let layoutManager = textView.layoutManager
        let glyph = layoutManager.glyphIndexForCharacter(at: mark.range.location)
        let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let glyphLocation = layoutManager.location(forGlyphAt: glyph)
        // Raised above the capitals into the gap between lines, so it never covers the previous word.
        let center = CGPoint(
            x: textView.frame.minX + line.minX + glyphLocation.x - Self.symbolGap - symbolSize / 2,
            y: textView.frame.minY + line.minY + glyphLocation.y - font.capHeight - Self.symbolGap - symbolSize / 2
        )
        return CGRect(x: center.x - Self.minTapSize / 2, y: center.y - Self.minTapSize / 2, width: Self.minTapSize, height: Self.minTapSize)
    }

    private func attributedText() -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: page.text,
            attributes: PageTextStyle.attributes(settings: settings)
        )
        for mark in marks {
            switch mark.kind {
            case .underline:
                text.addAttributes([
                    .underlineStyle: NSUnderlineStyle.single.union(.patternDot).rawValue,
                    .underlineColor: UIColor.secondaryLabel
                ], range: mark.range)
            case .highlight:
                text.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.3), range: mark.range)
            case .symbol:
                break
            }
        }
        return text
    }

    @objc private func tapped(_ tap: UITapGestureRecognizer) {
        let x = tap.location(in: self).x
        if x < max(textView.frame.minX, Self.minTapSize) {
            onEdgeTapped(false)
        } else if x > min(textView.frame.maxX, bounds.width - Self.minTapSize) {
            onEdgeTapped(true)
        } else if let (mark, rect) = underline(at: tap.location(in: textView)) {
            onMarkTapped(mark, textView.convert(rect, to: self))
        } else {
            onCenterTapped()
        }
    }

    private func underline(at point: CGPoint) -> (Mark, CGRect)? {
        let layoutManager = textView.layoutManager
        for mark in marks where mark.kind == .underline {
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
