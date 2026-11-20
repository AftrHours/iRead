import XCTest

/// The reader's main flow, tapped through on the sample books: open a book, turn pages, open a reference, hide references,
/// change the theme, go back. Finds everything by the accessibility labels the app already has.
/// The app starts clean and offline with `-uiTesting` (see AppFolders) and past onboarding with the UserDefaults argument.
final class SmokeTests: XCTestCase {
    private var app: XCUIApplication!

    private static let timeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-hasCompletedHiFiOnboarding", "YES"]
        app.launch()
    }

    // MARK: - Tests

    func testLibraryShowsSampleBooks() {
        XCTAssertTrue(book("Little Women").waitForExistence(timeout: Self.timeout), "Little Women is missing from the library")
        XCTAssertTrue(book("Anne of Green Gables").exists, "Anne of Green Gables is missing from the library")
    }

    func testReadingFlow() throws {
        // Open a book.
        let littleWomen = book("Little Women")
        XCTAssertTrue(littleWomen.waitForExistence(timeout: Self.timeout))
        littleWomen.tap()
        XCTAssertTrue(readingMode.waitForExistence(timeout: Self.timeout), "The reader didn't open")
        XCTAssertTrue(readingMode.hasReadingModeOff, "A book should open with references shown")

        // Turn a page.
        let firstPage = pageText()
        turnPage()
        XCTAssertNotEqual(pageText(), firstPage, "Tapping the right edge didn't turn the page")

        // Find a page with a reference, tap it, and see the earlier passage and the rating buttons.
        try openAReference()
        XCTAssertTrue(app.buttons["Helpful Passage"].exists)
        XCTAssertTrue(app.buttons["Unhelpful Passage"].exists)
        dismissReference()

        // Reading mode hides the references; turning it off shows them and the menu again.
        showReferences()
        readingMode.tap()
        XCTAssertTrue(readingMode.hasReadingModeOn)
        XCTAssertEqual(referenceButtons.count, 0, "References are still shown in reading mode")
        // The menu is faded out and not tappable in reading mode, but XCUITest still lists its button, so it isn't checked here.
        readingMode.tap()
        XCTAssertTrue(readingMenu.waitForExistence(timeout: Self.timeout))

        // Change the reading theme.
        readingMenu.tap()
        app.buttons["Theme & Settings"].tap()
        XCTAssertTrue(app.staticTexts["Reading Theme & Settings"].waitForExistence(timeout: Self.timeout),
                      "Theme & Settings didn't open")
        app.buttons["Close"].tap()
        XCTAssertTrue(readingMenu.waitForExistence(timeout: Self.timeout))

        // Back to the library.
        app.buttons["Back"].tap()
        XCTAssertTrue(book("Little Women").waitForExistence(timeout: Self.timeout), "Back didn't return to the library")
    }

    // MARK: - Finding things

    private func book(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title + ",")).firstMatch
    }

    private var readingMode: XCUIElement { app.buttons["Reading mode"] }
    private var readingMenu: XCUIElement { app.buttons["Reading menu"] }

    private var referenceButtons: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reference:'"))
    }

    private var referenceCard: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Mentioned earlier:'")).firstMatch
    }

    /// All the text on screen, so two pages can be told apart without knowing their words.
    private func pageText() -> String {
        app.staticTexts.allElementsBoundByIndex
            .map { ($0.value as? String) ?? $0.label }
            .joined(separator: "|")
    }

    // MARK: - Doing things

    private func turnPage() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        // Turning a page turns reading mode on; wait for the new page.
        XCTAssertTrue(readingMode.waitForExistence(timeout: Self.timeout))
    }

    private func showReferences() {
        if readingMode.hasReadingModeOn {
            readingMode.tap()
        }
        XCTAssertTrue(readingMode.hasReadingModeOff)
    }

    /// Turns pages until one has a reference, then taps references on it until the card shows.
    private func openAReference() throws {
        for _ in 0..<12 {
            showReferences()
            let count = min(referenceButtons.count, 5)
            for index in 0..<count {
                referenceButtons.element(boundBy: index).tap()
                if referenceCard.waitForExistence(timeout: 2) { return }
            }
            turnPage()
        }
        XCTFail("No reference could be opened in 12 pages")
    }

    private func dismissReference() {
        // Tapping outside the popover closes it. UIKit names the invisible layer that catches that tap.
        let outside = app.otherElements["PopoverDismissRegion"]
        if outside.exists {
            outside.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
        }
        XCTAssertTrue(referenceCard.waitForNonExistence(timeout: Self.timeout), "The reference card didn't close")
    }
}

private extension XCUIElement {
    var hasReadingModeOn: Bool { (value as? String)?.hasPrefix("Reading mode on") == true }
    var hasReadingModeOff: Bool { (value as? String)?.hasPrefix("Reading mode off") == true }
}
