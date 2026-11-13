import SwiftUI

/// Reading Theme & Settings: the one view here that holds the VM. It lays out the sections and hands each one its values;
/// the sections themselves only show what they're given.
struct ThemeSettingsView: View {
    @Bindable var readerSettingsVM: ReaderSettingsVM
    let onClose: () -> Void
    @State private var width: CGFloat = 0
    @State private var barHeight: CGFloat = 0

    private var layout: SettingsLayout { .forWidth(width) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: layout.sectionGap) {
                    TextSizeSection(value: $readerSettingsVM.textSizeSlider, range: ReaderSettingsVM.textSizeSliderRange)
                    BrightnessSection(value: $readerSettingsVM.brightnessSlider)
                    ThemeSection(
                        selectedTheme: readerSettingsVM.settings.theme,
                        pageTurnStyle: $readerSettingsVM.selectedPageTurnStyle,
                        readingMode: $readerSettingsVM.selectedReadingMode,
                        onThemeTapped: readerSettingsVM.themeTapped
                    )
                    LayoutOptionsSection(rows: layoutRows)
                    resetButton
                }
                .padding(.horizontal, layout.sideMargin)
                .padding(.top, max(0, layout.topGap - barHeight))
                .environment(\.settingsLayout, layout)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            }
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { barHeight = $0 }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppColors.settingsSheetBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close, action: onClose)
                }
                ToolbarItem(placement: .principal) {
                    Text("Reading Theme & Settings")
                        .font(AppTypography.headline(.semibold))
                        .foregroundStyle(AppColors.settingsText)
                }
            }
        }
        .foregroundStyle(AppColors.settingsText)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppColors.settingsSheetBackground)
    }

    private var layoutRows: [LayoutOptionsSection.Row] {
        [
            .init(title: "Line Spacing", systemImage: "arrow.up.and.down.text.horizontal",
                  value: $readerSettingsVM.lineSpacingSlider, range: ReaderSettingsVM.lineSpacingSliderRange,
                  valueLabel: readerSettingsVM.lineSpacingLabel),
            .init(title: "Character Spacing", systemImage: "textformat.characters.arrow.left.and.right",
                  value: $readerSettingsVM.characterSpacingSlider, range: ReaderSettingsVM.characterSpacingSliderRange,
                  valueLabel: readerSettingsVM.characterSpacingLabel),
            .init(title: "Word Spacing", systemImage: "text.word.spacing",
                  value: $readerSettingsVM.wordSpacingSlider, range: ReaderSettingsVM.wordSpacingSliderRange,
                  valueLabel: readerSettingsVM.wordSpacingLabel)
        ]
    }

    private var resetButton: some View {
        Button(action: readerSettingsVM.resetTapped) {
            Text("Reset to Default")
                .font(AppTypography.subheadline(.medium))
                .foregroundStyle(AppColors.settingsResetText)
                .padding(.horizontal, layout.resetHorizontalPadding)
                .frame(minHeight: layout.resetMinHeight)
                .background(AppColors.settingsResetFill, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Theme & Settings") {
    @Previewable @State var readerSettingsVM = PreviewFixtures.readerSettingsVM()
    Color.black
        .sheet(isPresented: .constant(true)) {
            ThemeSettingsView(readerSettingsVM: readerSettingsVM, onClose: {})
        }
}
