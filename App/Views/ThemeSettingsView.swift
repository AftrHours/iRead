import SwiftUI

struct ThemeSettingsView: View {
    let readerVM: ReaderVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("Text Size", systemImage: "textformat.size") {
                        stepper(minus: "A-", plus: "A+", name: "text size") {
                            readerVM.textSizeDecreased()
                        } onIncrease: {
                            readerVM.textSizeIncreased()
                        }
                    }
                    section("Reading Theme", systemImage: "slider.horizontal.3") {
                        Slider(value: Binding(get: { readerVM.brightness }, set: { readerVM.brightnessChanged($0) })) {
                            Text("Brightness")
                        } minimumValueLabel: {
                            Image(systemName: "sun.min")
                        } maximumValueLabel: {
                            Image(systemName: "sun.max")
                        }
                        .padding(.horizontal, 8)
                        HStack(spacing: 20) {
                            ForEach(0..<ReadingSettings.themeCount, id: \.self) { index in
                                themeTile(index)
                            }
                        }
                    }
                    section("Line Spacing", systemImage: "arrow.up.and.down.text.horizontal") {
                        stepper(minus: "−", plus: "+", name: "line spacing") {
                            readerVM.lineSpacingDecreased()
                        } onIncrease: {
                            readerVM.lineSpacingIncreased()
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

    private func themeTile(_ index: Int) -> some View {
        let isSelected = readerVM.settings.themeIndex == index
        return Button {
            readerVM.themeTapped(index)
        } label: {
            Text("Aa")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(Color(.systemGray5), in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Theme \(index + 1)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
