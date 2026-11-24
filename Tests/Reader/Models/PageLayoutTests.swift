import Foundation
import Testing
@testable import iRead

@Suite("PageLayout")
struct PageLayoutTests {
    @Test("RD-40 the header, text and footer are placed from the screen and its safe area alone")
    func placement() {
        // An iPhone 17 Pro Max: 440 x 956, with 62 above and 34 below.
        let layout = PageLayout(ScreenGeometry(safeSize: CGSize(width: 440, height: 860), safeAreaTop: 62, safeAreaBottom: 34))
        #expect(layout.header == CGRect(x: 16, y: 62, width: 408, height: 44))
        #expect(layout.footer == CGRect(x: 16, y: 878, width: 408, height: 44))
        // 32 under the header, 16 above the footer, the full width across.
        #expect(layout.text == CGRect(x: 0, y: 138, width: 440, height: 724))
        // 9% of the width on each side.
        #expect(layout.horizontalMargin == 40)
        #expect(layout.viewport == Viewport(size: CGSize(width: 440, height: 724), horizontalMargin: 40))
    }

    @Test("RD-40 the viewport changes only when the text's room does")
    func viewport() {
        let phone = PageLayout(ScreenGeometry(safeSize: CGSize(width: 440, height: 860), safeAreaTop: 62, safeAreaBottom: 34))
        // Same room for the text, whatever the screen it was measured on.
        let same = PageLayout(ScreenGeometry(safeSize: CGSize(width: 440, height: 860), safeAreaTop: 62, safeAreaBottom: 34))
        let rotated = PageLayout(ScreenGeometry(safeSize: CGSize(width: 956, height: 346), safeAreaTop: 0, safeAreaBottom: 34))
        #expect(phone.viewport == same.viewport)
        #expect(phone.viewport != rotated.viewport)
    }
}
