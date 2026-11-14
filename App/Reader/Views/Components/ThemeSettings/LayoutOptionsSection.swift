import SwiftUI

/// Layout Options: a card of spacing sliders, each with its value as the design writes it ("1.20", "15%").
struct LayoutOptionsSection: View {
    struct Row: Identifiable {
        let title: String
        let systemImage: String
        let value: Binding<Double>
        let range: ClosedRange<Double>
        let valueLabel: String

        var id: String { title }
    }

    let rows: [Row]
    @Environment(\.settingsLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: layout.layoutHeaderGap) {
            SettingsSectionHeader(title: "Layout Options", systemImage: "text.below.photo")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(AppColors.settingsDivider)
                            .frame(height: layout.dividerHeight)
                    }
                    LayoutRow(row: row)
                }.padding(12)
            }
            .background(AppColors.settingsControlBackground, in: .rect(cornerRadius: layout.cardCornerRadius))
        }
    }
}

private struct LayoutRow: View {
    let row: LayoutOptionsSection.Row
    @Environment(\.settingsLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: layout.rowTitleGap) {
            Text(row.title)
                .font(AppTypography.callout())
            HStack(spacing: layout.rowIconGap) {
                Image(systemName: row.systemImage)
                    .frame(width: layout.rowIconWidth)
                    .foregroundStyle(AppColors.settingsSecondaryText)
                    .accessibilityHidden(true)
                SettingsSlider(value: row.value, range: row.range, label: row.title)
                    .accessibilityValue(row.valueLabel)
                Text(row.valueLabel)
                    .font(AppTypography.callout(.medium))
                    .monospacedDigit()
                    .frame(minWidth: layout.valueLabelMinWidth, alignment: .trailing)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview {
    @Previewable @State var lineSpacing = 120.0
    @Previewable @State var wordSpacing = 0.0
    LayoutOptionsSection(rows: [
        .init(title: "Line Spacing", systemImage: "arrow.up.and.down.text.horizontal", value: $lineSpacing,
              range: 80...250, valueLabel: String(format: "%.2f", lineSpacing / 100)),
        .init(title: "Word Spacing", systemImage: "text.word.spacing", value: $wordSpacing,
              range: 0...100, valueLabel: "\(Int(wordSpacing))%")
    ])
    .padding()
}
