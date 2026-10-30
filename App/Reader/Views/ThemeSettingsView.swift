import SwiftUI

struct ThemeSettingsView: View {
    private static let sliderTint = Color(red: 0xAC / 255, green: 0x7F / 255, blue: 0x5E / 255)

    let readerSettingsVM: ReaderSettingsVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("Text Size", systemImage: "textformat.size") {
                        Slider(
                            value: Binding(get: { Double(readerSettingsVM.settings.textSizeIndex) }, set: { readerSettingsVM.textSizeChanged($0) }),
                            in: 0...Double(ReadingSettings.textSizes.count - 1),
                            step: 1
                        ) {
                            Text("Text Size")
                        } minimumValueLabel: {
                            Text("A")
                                .font(.footnote)
                        } maximumValueLabel: {
                            Text("A")
                                .font(.title)
                        }
                        .foregroundStyle(.secondary)
                        .tint(Self.sliderTint)
                        .padding(.horizontal, 8)
                    }
                    section("Reading Theme", systemImage: "slider.horizontal.3") {
                        Slider(value: Binding(get: { readerSettingsVM.brightness }, set: { readerSettingsVM.brightnessChanged($0) })) {
                            Text("Brightness")
                        } minimumValueLabel: {
                            Image(systemName: "sun.min")
                        } maximumValueLabel: {
                            Image(systemName: "sun.max")
                        }
                        .foregroundStyle(.secondary)
                        .tint(Self.sliderTint)
                        .padding(.horizontal, 8)
                        HStack(spacing: 20) {
                            ForEach(ReadingTheme.allCases, id: \.self) { theme in
                                themeTile(theme)
                            }
                        }
                    }
                    section("Line Spacing", systemImage: "arrow.up.and.down.text.horizontal") {
                        stepper(minus: "−", plus: "+", name: "line spacing") {
                            readerSettingsVM.lineSpacingDecreased()
                        } onIncrease: {
                            readerSettingsVM.lineSpacingIncreased()
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Theme & Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
    }

    private func section(_ title: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
    }

    private func stepper(minus: String, plus: String, name: String,
                         onDecrease: @escaping () -> Void, onIncrease: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            stepButton(minus, label: "Decrease \(name)", action: onDecrease)
            Divider()
                .frame(height: 20)
            stepButton(plus, label: "Increase \(name)", action: onIncrease)
        }
        .background(Color(.secondarySystemFill), in: .capsule)
    }

    private func stepButton(_ title: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func themeTile(_ theme: ReadingTheme) -> some View {
        let isSelected = readerSettingsVM.settings.theme == theme
        let background = theme == .original ? UIColor.systemGray6 : PageTextStyle.backgroundColor(for: theme)
        return Button {
            readerSettingsVM.themeTapped(theme)
        } label: {
            VStack(spacing: 2) {
                Text("Aa")
                    .font(Font(PageTextStyle.font(for: theme, size: 24)))
                Text(theme.title)
                    .font(Font(PageTextStyle.font(for: theme, size: 12)))
            }
            .foregroundStyle(Color(PageTextStyle.textColor(for: theme)))
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color(background), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.primary : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.title) theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
