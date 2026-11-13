import SwiftUI

/// Renders search input and forwards voice-search events; focus remains a SwiftUI concern.
struct LibrarySearchBar: View {
    enum Style {
        case phone
        case phoneActive
        case pad

        var height: CGFloat { self == .phone ? 44 : 48 }
        var microphoneWidth: CGFloat { self == .phone ? 40 : 32 }
        var trailingInset: CGFloat {
            switch self {
            case .phone: 0
            case .phoneActive: 8
            case .pad: 14
            }
        }
        var placeholder: String { self == .phoneActive ? "Search Title or Author" : "Search" }
        var placeholderColor: Color { self == .pad ? AppColors.textSecondary : AppColors.searchMutedForeground }
        var iconColor: Color {
            switch self {
            case .phone: AppColors.searchMutedForeground
            case .phoneActive: .primary
            case .pad: AppColors.textSecondary
            }
        }
    }

    @Bindable var libVM: LibVM
    let focus: FocusState<Bool>.Binding
    var style: Style = .phone
    var focusesOnContainerTap = true

    var body: some View {
        styledField
            .contentShape(.capsule)
            .simultaneousGesture(TapGesture().onEnded {
                if focusesOnContainerTap { focus.wrappedValue = true }
            })
    }

    @ViewBuilder
    private var styledField: some View {
        switch style {
        case .phone:
            inputContent.background(AppColors.searchBackground, in: .capsule)
        case .phoneActive, .pad:
            inputContent.glassEffect(.regular, in: .capsule)
        }
    }

    private var inputContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.body())
                .foregroundStyle(style.iconColor)
            TextField(style.placeholder, text: $libVM.searchText,
                      prompt: Text(style.placeholder).foregroundStyle(style.placeholderColor))
                .font(AppTypography.body(style == .phone ? .medium : .regular))
                .foregroundStyle(AppColors.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused(focus)
            Button(action: libVM.voiceSearchTapped) {
                Image(systemName: libVM.voiceSearchSymbol)
                    .font(AppTypography.body())
                    .foregroundStyle(libVM.isVoiceSearchActive ? AppColors.actionPrimary : style.iconColor)
                    .frame(width: style.microphoneWidth, height: 40)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(libVM.voiceSearchAccessibilityLabel)
        }
        .padding(.leading, 14)
        .padding(.trailing, style.trailingInset)
        .frame(height: style.height)
    }
}

private struct LibrarySearchPreview: View {
    @FocusState private var isFocused: Bool
    private let libVM = PreviewFixtures.libraryVM()

    var body: some View {
        LibrarySearchBar(libVM: libVM, focus: $isFocused)
            .padding()
            .background(AppColors.backgroundPrimary)
    }
}

#Preview("iPhone Search — Light") {
    LibrarySearchPreview()
        .preferredColorScheme(.light)
}

#Preview("iPhone Search — Dark") {
    LibrarySearchPreview()
        .preferredColorScheme(.dark)
}
