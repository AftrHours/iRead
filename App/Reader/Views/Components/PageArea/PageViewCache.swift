import UIKit

/// The page views a pager has built, by page number, so a turn never waits for a page to lay out.
/// A view is kept while it still shows its page as the content has it, and rebuilt when it doesn't.
@MainActor
final class PageViewCache {
    private var views: [Int: PageTextView] = [:]

    /// The cached view of `page` when it still fits `content` (brought up to date in place), else a new one.
    func view(for page: Page, content: PageContent, actions: PageActions,
              onEdgeTapped: @escaping (_ isForward: Bool) -> Void) -> PageTextView {
        if let view = views[page.number], view.isShowing(page, in: content) {
            view.refresh(from: content, actions: actions)
            return view
        }
        let view = PageTextView(page: page, content: content, actions: actions, onEdgeTapped: onEdgeTapped)
        views[page.number] = view
        return view
    }

    /// Drops every view except those of the pages in `numbers`.
    func keep(_ numbers: Set<Int>) {
        views = views.filter { numbers.contains($0.key) }
    }
}
