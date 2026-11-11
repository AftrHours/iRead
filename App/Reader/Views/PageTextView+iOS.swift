import SwiftUI
import UIKit

final class PageTextView: UIView {
    let page: Page
    let settings: ReadingSettings
    let marks: [Mark]
    private let textView = UITextView(usingTextLayoutManager: false)
    private let onEdgeTapped: (_ isForward: Bool) -> Void
    private let onCenterTapped: () -> Void
    private let onMarkTapped: (Mark, CGRect) -> Void

    private static let minTapSize: CGFloat = 44

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
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = PageTextStyle.textFrame(in: bounds, settings: settings)
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

private struct PageTextPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> PageTextView {
        PageTextView(
            page: Page(number: 12, chapterIndex: 0, range: NSRange(location: 0, length: 190),
                       text: "Elizabeth had just begun to read again when the carriage stopped before the old house. She looked up from the letter, listening for the sound of footsteps on the path."),
            settings: ReadingSettings(),
            marks: [],
            onEdgeTapped: { _ in },
            onCenterTapped: {},
            onMarkTapped: { _, _ in }
        )
    }

    func updateUIView(_ uiView: PageTextView, context: Context) {}
}

#Preview("Reader Page Text") {
    PageTextPreview()
}
