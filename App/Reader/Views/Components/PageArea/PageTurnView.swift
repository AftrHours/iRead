import SwiftUI
import UIKit

/// The Curl style, on UIPageViewController's own page curl. Slide and Fast Fade use `PageSlideView`.
struct PageTurnView: UIViewControllerRepresentable {
    let content: PageContent
    let actions: PageActions

    func makeCoordinator() -> Coordinator {
        Coordinator(pageTurnView: self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal)
        pageViewController.isDoubleSided = false
        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator
        context.coordinator.pageViewController = pageViewController
        return pageViewController
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        context.coordinator.pageTurnView = self
        context.coordinator.showShownPage()
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var pageTurnView: PageTurnView
        weak var pageViewController: UIPageViewController?
        private var isTurning = false
        private var missingPageNumbers: Set<Int> = []

        init(pageTurnView: PageTurnView) {
            self.pageTurnView = pageTurnView
        }

        private var displayedView: PageTextView? {
            pageViewController?.viewControllers?.first?.view as? PageTextView
        }

        private var displayedPage: Page? {
            displayedView?.page
        }

        private var isShownPageDisplayed: Bool {
            let content = pageTurnView.content
            return displayedView?.isShowing(content.shownPage, in: content) ?? false
        }

        func showShownPage() {
            defer {
                if displayedPage == pageTurnView.content.shownPage {
                    displayedView?.focusWhenVisible(pageTurnView.content.readingFocus)
                }
            }
            displayedView?.refresh(from: pageTurnView.content, actions: pageTurnView.actions)
            let hasLoadedMissingPage = pageTurnView.content.pages.contains { missingPageNumbers.contains($0.number) }
            guard !isTurning, !isShownPageDisplayed || hasLoadedMissingPage else { return }
            missingPageNumbers = []
            // UIPageViewController remembers a missing neighbor until it is given a page again.
            pageViewController?.setViewControllers([pageController(for: pageTurnView.content.shownPage)], direction: .forward, animated: false)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerBefore viewController: UIViewController) -> UIViewController? {
            page(next: (viewController.view as? PageTextView)?.page, isForward: false).map(pageController)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerAfter viewController: UIViewController) -> UIViewController? {
            page(next: (viewController.view as? PageTextView)?.page, isForward: true).map(pageController)
        }

        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            pageTurnView.actions.onTurnBegan()
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let displayedPage else { return }
            pageTurnView.actions.onPageChanged(displayedPage)
        }

        /// The loaded page after or before `page`. A page that isn't loaded yet is remembered, to be asked for again once it is.
        private func page(next page: Page?, isForward: Bool) -> Page? {
            guard let page else { return nil }
            let nextPage = pageTurnView.content.neighbor(of: page, isForward: isForward)
            if nextPage == nil {
                missingPageNumbers.insert(page.number + (isForward ? 1 : -1))
            }
            return nextPage
        }

        private func pageController(for page: Page) -> UIViewController {
            let controller = UIViewController()
            controller.view = PageTextView(page: page, content: pageTurnView.content, actions: pageTurnView.actions,
                                           onEdgeTapped: { [weak self] isForward in self?.turnPage(isForward: isForward) })
            return controller
        }

        private func turnPage(isForward: Bool) {
            guard !isTurning, let pageViewController, let page = page(next: displayedPage, isForward: isForward) else { return }
            pageTurnView.actions.onTurnBegan()
            isTurning = true
            let direction: UIPageViewController.NavigationDirection = isForward ? .forward : .reverse
            pageViewController.setViewControllers([pageController(for: page)], direction: direction, animated: true) { [weak self] _ in
                self?.isTurning = false
                self?.pageTurnView.actions.onPageChanged(page)
            }
        }
    }
}

#Preview("Page Curl") {
    PagePreview { readerVM in
        if let content = readerVM.pageContent {
            PageTurnView(content: content, actions: .none)
        }
    }
}
