import SwiftUI

/// A section's title with its symbol, read by VoiceOver as one header.
struct SettingsSectionHeader: View {
    let title: String
    let systemImage: String
    @Environment(\.settingsLayout) private var layout

    var body: some View {
        HStack(spacing: layout.iconGap) {
            Image(systemName: systemImage)
                .frame(width: layout.iconColumn)
                .accessibilityHidden(true)
            Text(title)
                .font(AppTypography.headline(.semibold))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A header with its controls under it.
struct SettingsSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content
    @Environment(\.settingsLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: layout.headerGap) {
            SettingsSectionHeader(title: title, systemImage: systemImage)
            content()
        }
    }
}


struct SettingsSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    let label: String

    var body: some View {
        Group {
            if let step {
                Slider(value: $value, in: range, step: step) { Text(label) }
            } else {
                Slider(value: $value, in: range) { Text(label) }
            }
        }
        // The part you've dragged over is orange on every slider, as in the design.
        .tint(AppColors.actionPrimary)
    }
}

#Preview {
    @Previewable @State var value = 0.4
    SettingsSection(title: "Brightness", systemImage: "sun.max") {
        SettingsSlider(value: $value, range: 0...1, label: "Brightness")
    }
    .padding()
}
