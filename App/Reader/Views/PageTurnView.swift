import SwiftUI
import UIKit

struct PageTurnView: UIViewControllerRepresentable {
    let pages: [Page]
    let shownPage: Page
    let settings: ReadingSettings
    let marks: [Int: [Mark]]
    let onPageChanged: (Page) -> Void
    let onCenterTapped: () -> Void
    let onMarkTapped: (Mark, CGRect) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(pageTurnView: self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
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
            displayedView.map {
                $0.page == pageTurnView.shownPage
                    && $0.settings == pageTurnView.settings
                    && $0.marks == pageTurnView.marks[pageTurnView.shownPage.number, default: []]
            } ?? false
        }

        func showShownPage() {
            let hasLoadedMissingPage = pageTurnView.pages.contains { missingPageNumbers.contains($0.number) }
            guard !isTurning, !isShownPageDisplayed || hasLoadedMissingPage else { return }
            missingPageNumbers = []
            // UIPageViewController remembers a missing neighbor until it is given a page again.
            pageViewController?.setViewControllers([pageController(for: pageTurnView.shownPage)], direction: .forward, animated: false)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerBefore viewController: UIViewController) -> UIViewController? {
            page(next: (viewController.view as? PageTextView)?.page, by: -1).map(pageController)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerAfter viewController: UIViewController) -> UIViewController? {
            page(next: (viewController.view as? PageTextView)?.page, by: 1).map(pageController)
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let displayedPage else { return }
            pageTurnView.onPageChanged(displayedPage)
        }

        private func page(next page: Page?, by offset: Int) -> Page? {
            guard let page else { return nil }
            let number = page.number + offset
            let nextPage = pageTurnView.pages.first { $0.number == number }
            if nextPage == nil {
                missingPageNumbers.insert(number)
            }
            return nextPage
        }

        private func pageController(for page: Page) -> UIViewController {
            let controller = UIViewController()
            controller.view = PageTextView(
                page: page,
                settings: pageTurnView.settings,
                marks: pageTurnView.marks[page.number, default: []],
                onEdgeTapped: { [weak self] isForward in self?.turnPage(isForward: isForward) },
                onCenterTapped: { [weak self] in self?.pageTurnView.onCenterTapped() },
                onMarkTapped: { [weak self] mark, rect in self?.pageTurnView.onMarkTapped(mark, rect) }
            )
            return controller
        }

        private func turnPage(isForward: Bool) {
            guard !isTurning, let pageViewController, let page = page(next: displayedPage, by: isForward ? 1 : -1) else { return }
            isTurning = true
            pageViewController.setViewControllers([pageController(for: page)], direction: isForward ? .forward : .reverse, animated: true) { [weak self] _ in
                self?.isTurning = false
                self?.pageTurnView.onPageChanged(page)
            }
        }
    }
}
