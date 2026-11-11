import SwiftUI
import UIKit

struct PageTurnView: UIViewControllerRepresentable {
    let pages: [Page]
    let shownPage: Page
    let settings: ReadingSettings
    let horizontalMargin: CGFloat
    let marks: [Int: [Mark]]
    let onPageChanged: (Page) -> Void
    let onCenterTapped: () -> Void
    let onMarkTapped: (Mark, CGRect) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(pageTurnView: self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let transitionStyle: UIPageViewController.TransitionStyle = pageTurnStyle == .curl ? .pageCurl : .scroll
        let pageViewController = UIPageViewController(transitionStyle: transitionStyle, navigationOrientation: .horizontal)
        pageViewController.isDoubleSided = false
        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator
        context.coordinator.pageViewController = pageViewController
        context.coordinator.configureFadeSwipe(for: pageTurnStyle)
        return pageViewController
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        context.coordinator.pageTurnView = self
        context.coordinator.showShownPage()
    }

    private var pageTurnStyle: PageTurnStyle { settings.pageTurnStyle }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIGestureRecognizerDelegate {
        var pageTurnView: PageTurnView
        weak var pageViewController: UIPageViewController?
        private var isTurning = false
        private var missingPageNumbers: Set<Int> = []
        private var fadeSwipeRecognizer: UIPanGestureRecognizer?

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
                    && $0.horizontalMargin == pageTurnView.horizontalMargin
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

        func configureFadeSwipe(for style: PageTurnStyle) {
            guard style == .fastFade, let pageViewController else { return }
            pageViewController.gestureRecognizers
                .filter { $0 is UIPanGestureRecognizer }
                .forEach { $0.isEnabled = false }
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(fadeSwipeRecognized(_:)))
            recognizer.delegate = self
            pageViewController.view.addGestureRecognizer(recognizer)
            fadeSwipeRecognizer = recognizer
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let view = pageViewController?.view else { return true }
            let velocity = pan.velocity(in: view)
            return abs(velocity.x) > abs(velocity.y)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        @objc private func fadeSwipeRecognized(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard gestureRecognizer.state == .ended, let view = pageViewController?.view else { return }
            let translation = gestureRecognizer.translation(in: view).x
            let velocity = gestureRecognizer.velocity(in: view).x
            let distance = abs(translation) >= 36 ? translation : (abs(velocity) >= 400 ? velocity : 0)
            guard distance != 0 else { return }
            turnPage(isForward: distance < 0)
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
                horizontalMargin: pageTurnView.horizontalMargin,
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
            let direction: UIPageViewController.NavigationDirection = isForward ? .forward : .reverse
            if pageTurnView.pageTurnStyle == .fastFade {
                UIView.transition(with: pageViewController.view, duration: 0.18, options: [.transitionCrossDissolve, .beginFromCurrentState]) {
                    pageViewController.setViewControllers([self.pageController(for: page)], direction: direction, animated: false)
                } completion: { [weak self] _ in
                    self?.isTurning = false
                    self?.pageTurnView.onPageChanged(page)
                }
            } else {
                pageViewController.setViewControllers([pageController(for: page)], direction: direction, animated: true) { [weak self] _ in
                    self?.isTurning = false
                    self?.pageTurnView.onPageChanged(page)
                }
            }
        }
    }
}
