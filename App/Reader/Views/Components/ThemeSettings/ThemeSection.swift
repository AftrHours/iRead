import SwiftUI

/// Theme: one tile per reading theme, and the Reading Animation and Reading Mode menus beside the header.
struct ThemeSection: View {
    let selectedTheme: ReadingTheme
    @Binding var pageTurnStyle: PageTurnStyle
    @Binding var readingMode: ReadingMode
    let onThemeTapped: (ReadingTheme) -> Void
    @Environment(\.settingsLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: layout.themeHeaderGap) {
            HStack {
                SettingsSectionHeader(title: "Theme", systemImage: "slider.horizontal.3")
                    .padding(.leading, layout.themeHeaderInset)
                Spacer()
                HStack(spacing: layout.menuGroupGap) {
                    pageTurnMenu
                    readingModeMenu
                }
                // Inside the glass, so the capsule wraps the room too.
                .padding(.horizontal, layout.menuGroupPadding)
                .glassEffect()
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: layout.tileColumnGap), count: layout.tileColumns),
                      spacing: layout.tileRowGap) {
                ForEach(ReadingTheme.allCases, id: \.self) { theme in
                    ThemeTile(theme: theme, isSelected: theme == selectedTheme) { onThemeTapped(theme) }
                }
            }
        }
    }

    private var pageTurnMenu: some View {
        Menu {
            Picker("Reading Animation", selection: $pageTurnStyle) {
                ForEach(PageTurnStyle.allCases) { style in
                    Label(style.title, systemImage: style.systemImage).tag(style)
                }
            }
            .pickerStyle(.inline)
        } label: {
            menuIcon("doc")
        }
        .accessibilityLabel("Reading animation")
    }

    private var readingModeMenu: some View {
        Menu {
            Picker("Reading Mode", selection: $readingMode) {
                ForEach(ReadingMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.inline)
        } label: {
            menuIcon("moon.stars")
        }
        .accessibilityLabel("Reading mode")
    }

    private func menuIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.title3)
            .foregroundStyle(AppColors.settingsText)
            .frame(width: layout.menuIconSize, height: layout.menuIconSize)
            .contentShape(.rect)
    }
}

/// A theme's swatch: "Aa" and its name in the theme's font and colours, outlined when chosen.
struct ThemeTile: View {
    let theme: ReadingTheme
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.settingsLayout) private var layout

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text("Aa")
                    .font(Font(PageTextStyle.font(for: theme, size: 24)))
                Text(theme.title)
                    .font(Font(PageTextStyle.font(for: theme, size: 12)))
            }
            .foregroundStyle(Color(PageTextStyle.textColor(for: theme)))
            .frame(maxWidth: .infinity, minHeight: layout.tileHeight, maxHeight: layout.tileHeight)
            .background(AppColors.settingsThemeTile(for: theme), in: .rect(cornerRadius: layout.tileCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: layout.tileCornerRadius)
                    .strokeBorder(isSelected ? AppColors.settingsTileSelectedBorder : .clear, lineWidth: layout.tileBorderWidth)
            }
            .contentShape(.rect(cornerRadius: layout.tileCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.title) theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var theme = ReadingTheme.original
    @Previewable @State var pageTurnStyle = PageTurnStyle.slide
    @Previewable @State var readingMode = ReadingMode.matchDevice
    ThemeSection(selectedTheme: theme, pageTurnStyle: $pageTurnStyle, readingMode: $readingMode,
                 onThemeTapped: { theme = $0 })
        .padding()
        .foregroundStyle(AppColors.settingsText)
        .background(AppColors.settingsSheetBackground)
}
