import SwiftUI

/// Every margin, gap and size in Reading Theme & Settings, in one place. ThemeSettingsView picks the set that fits the
/// sheet's width and shares it with the sections through the environment, so no section carries numbers of its own.
/// Change a number here and every section follows.
struct SettingsLayout: Equatable, Sendable {
    // MARK: The sheet

    /// Gap between the sheet's side edges and its content.
    var sideMargin: CGFloat = 16
    /// Where the first section starts, counted from the sheet's top edge. The system's own bar already takes part of it.
    var topGap: CGFloat = 64
    /// Gap between one section and the next.
    var sectionGap: CGFloat = 36

    // MARK: Section headers and their sliders

    /// Gap between a section's header and its controls.
    var headerGap: CGFloat = 30
    /// The symbol column. A header's symbol and a slider's small end icon both sit centred in it.
    var iconColumn: CGFloat = 24
    /// The header's text and the slider both start this far after the symbol column, so they share one left edge.
    var iconGap: CGFloat = 14

    // MARK: Theme
    // Measured from the hi-fi Theme section (an iPhone-width frame).

    /// Gap between the Theme header and the tiles.
    var themeHeaderGap: CGFloat = 13
    /// The Theme header sits this much further in than the tiles. The menus stay flush with the tiles' right edge.
    var themeHeaderInset: CGFloat = 8
    /// Gap between the two menu buttons beside the Theme header.
    var menuGroupGap: CGFloat = 6
    /// Room inside the glass capsule, left and right of the two menu buttons.
    var menuGroupPadding: CGFloat = 9
    var menuIconSize: CGFloat = 44
    /// Tiles in a row. A tile is as wide as its column, so the row always fills the sheet.
    var tileColumns = 3
    var tileColumnGap: CGFloat = 8
    var tileRowGap: CGFloat = 7
    var tileHeight: CGFloat = 54
    var tileCornerRadius: CGFloat = 8
    var tileBorderWidth: CGFloat = 2

    // MARK: Layout Options

    /// Gap between the Layout Options header and its card.
    var layoutHeaderGap: CGFloat = 16
    var cardCornerRadius: CGFloat = 24
    var dividerHeight: CGFloat = 1
    /// Gap between a row's title and its slider.
    var rowTitleGap: CGFloat = 18
    var rowIconWidth: CGFloat = 28
    var rowIconGap: CGFloat = 16
    /// Keeps the value labels ("1.20", "15%") from nudging the slider as they change.
    var valueLabelMinWidth: CGFloat = 44

    // MARK: Reset

    // Measured from the hi-fi Reset button: a capsule about 148 × 40 around the 15pt label.
    var resetMinHeight: CGFloat = 40
    var resetHorizontalPadding: CGFloat = 18

    /// An iPhone-width sheet: three tiles to a row.
    static let compact = SettingsLayout()
    /// An iPad-width sheet: six tiles to a row, with more room between them.
    static let wide = SettingsLayout(tileColumns: 6, tileColumnGap: 18)

    /// From this sheet width on, `wide` is used.
    static let wideBreakpoint: CGFloat = 600

    static func forWidth(_ width: CGFloat) -> SettingsLayout {
        width >= wideBreakpoint ? .wide : .compact
    }
}

extension EnvironmentValues {
    @Entry var settingsLayout = SettingsLayout.compact
}
