import UIKit

final class PageTextView: UIView {
    let page: Page
    private let textView = UITextView(usingTextLayoutManager: false)
    private let onEdgeTapped: (_ isForward: Bool) -> Void

    private static let minEdgeWidth: CGFloat = 44

    init(page: Page, settings: ReadingSettings, bodyFontSize: CGFloat, onEdgeTapped: @escaping (_ isForward: Bool) -> Void) {
        self.page = page
        self.onEdgeTapped = onEdgeTapped
        super.init(frame: .zero)
        backgroundColor = .systemBackground
        textView.attributedText = NSAttributedString(
            string: page.text,
            attributes: PageTextStyle.attributes(settings: settings, bodyFontSize: bodyFontSize)
        )
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
        textView.frame = PageTextStyle.textFrame(in: bounds)
    }

    @objc private func tapped(_ tap: UITapGestureRecognizer) {
        let x = tap.location(in: self).x
        if x < max(textView.frame.minX, Self.minEdgeWidth) {
            onEdgeTapped(false)
        } else if x > min(textView.frame.maxX, bounds.width - Self.minEdgeWidth) {
            onEdgeTapped(true)
        }
    }
}
