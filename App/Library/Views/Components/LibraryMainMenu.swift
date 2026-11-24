import SwiftUI

struct LibraryMainMenu: View {
    let libVM: LibVM
    var iconFont: Font = AppTypography.body(.medium)
    var isGrouped = false

    @AccessibilityFocusState private var isFocused: Bool

    var body: some View {
        Button {
            libVM.isOptionsMenuPresented = true
        } label: {
            if isGrouped {
                menuIcon
            } else {
                // Keep the toolbar hit target in place while its glass is drawn with the panel.
                Color.clear.libraryIconFrame().contentShape(.rect)
            }
        }
        .anchorPreference(key: LibraryMenuAnchor.self, value: .bounds) { bounds in
            isGrouped ? nil : LibraryMenuAnchor.Source(bounds: bounds, font: iconFont)
        }
        .buttonStyle(.plain)
        .libraryControlLabel("Library options", symbol: "ellipsis")
        .accessibilityFocused($isFocused)
        .onChange(of: libVM.isOptionsMenuPresented) { _, presented in
            if !presented && !libVM.isSelectionMode { isFocused = true }
        }
    }

    private var menuIcon: some View {
        Image(systemName: "ellipsis")
            .font(iconFont)
            .foregroundStyle(AppColors.textPrimary)
            .libraryIconFrame()
            .contentShape(.rect)
    }
}

struct LibraryMenuAnchor: PreferenceKey {
    struct Source {
        let bounds: Anchor<CGRect>
        let font: Font
    }

    static var defaultValue: Source? { nil }

    static func reduce(value: inout Source?, nextValue: () -> Source?) {
        if let next = nextValue() { value = next }
    }
}

struct LibraryMenuTransition: View {
    let libVM: LibVM
    let sourceFrame: CGRect?
    let iconFont: Font
    let isPad: Bool
    @Namespace private var glass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if libVM.isOptionsMenuPresented {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(.rect)
                    .onTapGesture { libVM.isOptionsMenuPresented = false }
                    .accessibilityHidden(true)
            }
            GlassEffectContainer {
                ZStack(alignment: .topTrailing) {
                    if libVM.isOptionsMenuPresented {
                        LibraryOptionsPanel(libVM: libVM)
                            .glassEffect(.regular.tint(Color(red: 0.13, green: 0.12, blue: 0.30).opacity(0.78)),
                                         in: .rect(cornerRadius: 32))
                            .glassEffectID("libraryOptions", in: glass)
                            .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
                            .environment(\.colorScheme, .dark)
                            .shadow(color: .black.opacity(0.28), radius: 10, y: 5)
                            .padding(.horizontal, 12)
                            .padding(.top, isPad ? 8 : 0)
                            .padding(.bottom, 8)
                    } else if let sourceFrame {
                        Image(systemName: "ellipsis")
                            .font(iconFont)
                            .dynamicTypeSize(...LibraryLayout.maximumIconSize)
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(width: sourceFrame.width, height: sourceFrame.height)
                            .glassEffect(.regular, in: .circle)
                            .glassEffectID("libraryOptions", in: glass)
                            .glassEffectTransition(reduceMotion ? .identity : .matchedGeometry)
                            .position(x: sourceFrame.midX, y: sourceFrame.midY)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .snappy(duration: 0.38),
                       value: libVM.isOptionsMenuPresented)
        }
    }
}

struct LibraryOptionsPanel: View {
    let libVM: LibVM
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var selectFocused: Bool

    var body: some View {
        ViewThatFits(in: .vertical) {
            actions.fixedSize(horizontal: false, vertical: true)
            ScrollView { actions }
        }
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 320 : 238)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { libVM.isOptionsMenuPresented = false }
        .onKeyPress(.escape) {
            libVM.isOptionsMenuPresented = false
            return .handled
        }
        .onAppear { selectFocused = true }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 0) {
            row("Select", icon: "checkmark.circle", action: libVM.selectionModeTapped)
                .accessibilityFocused($selectFocused)
            divider
            row("Grid", icon: "square.grid.2x2", checked: libVM.menuViewMode == .grid) {
                libVM.menuViewMode = .grid
            }
            row("List", icon: "list.bullet", checked: libVM.menuViewMode == .list) {
                libVM.menuViewMode = .list
            }
            divider
            heading("Sort by")
            ForEach(libVM.menuSortOptions) { option in
                row(option == .latestRead ? "Recent read" : option.title, checked: libVM.menuSortOption == option) {
                    libVM.menuSortOption = option
                }
            }
            divider
            heading("iRead Account")
            row(libVM.accountActionTitle, icon: "person.crop.circle.fill", reservesCheckmark: false,
                action: libVM.accountSettingsTapped)
                .foregroundStyle(libVM.isAccountSignedIn ? Color(red: 1, green: 0.23, blue: 0.34) : .white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .font(AppTypography.body())
        .foregroundStyle(.white)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.14))
            .frame(height: 1)
            .padding(.vertical, 9)
            .accessibilityHidden(true)
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.footnote(.medium))
            .foregroundStyle(.white.opacity(0.65))
            .frame(minHeight: 30)
            .accessibilityAddTraits(.isHeader)
    }

    private func row(_ title: String, icon: String? = nil, checked: Bool = false,
                     reservesCheckmark: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            libVM.isOptionsMenuPresented = false
            action()
        } label: {
            HStack(spacing: 8) {
                if reservesCheckmark {
                    Image(systemName: "checkmark")
                        .frame(width: 20)
                        .opacity(checked ? 1 : 0)
                        .accessibilityHidden(true)
                }
                if let icon {
                    Image(systemName: icon)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(checked ? .isSelected : [])
    }
}

#Preview("Library options") {
    @Previewable @State var model = PreviewFixtures.libraryVM()
    LibView(libVM: model)
        .onAppear { model.isOptionsMenuPresented = true }
}
