import SwiftUI

/// Brightness: the screen's brightness, from 0 to 1, between a small and a large sun.
struct BrightnessSection: View {
    @Binding var value: Double
    @Environment(\.settingsLayout) private var layout

    var body: some View {
        SettingsSection(title: "Brightness", systemImage: "sun.max") {
            HStack(spacing: layout.iconGap) {
                Image(systemName: "sun.min")
                    .foregroundStyle(AppColors.settingsSecondaryText)
                    .frame(width: layout.iconColumn)
                    .accessibilityHidden(true)
                SettingsSlider(value: $value, range: 0...1, label: "Brightness")
                Image(systemName: "sun.min.fill")
                    .font(.title3)
                    .foregroundStyle(AppColors.settingsSecondaryText)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview {
    @Previewable @State var value = 0.5
    BrightnessSection(value: $value)
        .padding()
}
