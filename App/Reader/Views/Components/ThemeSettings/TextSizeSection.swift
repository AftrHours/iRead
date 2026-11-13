import SwiftUI

/// Text Size: a stepped slider between a small and a large "A", one dot per size.
struct TextSizeSection: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @Environment(\.settingsLayout) private var layout

    var body: some View {
        SettingsSection(title: "Text Size", systemImage: "textformat.size") {
            HStack(spacing: layout.iconGap) {
                Text("A")
                    .font(AppTypography.footnote(.medium))
                    .foregroundStyle(AppColors.settingsSecondaryText)
                    .frame(width: layout.iconColumn)
                    .accessibilityHidden(true)
                SettingsSlider(value: $value, range: range, step: 1, label: "Text Size")
                Text("A")
                    .font(AppTypography.title1(.medium))
                    .foregroundStyle(AppColors.settingsText)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview {
    @Previewable @State var value = 3.0
    TextSizeSection(value: $value, range: 0...10)
        .padding()
}
