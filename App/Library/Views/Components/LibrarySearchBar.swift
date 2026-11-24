import SwiftUI

struct LibrarySearchBar: View {
    enum Style {
        case phone
        case phoneActive
        case pad

        var height: CGFloat { self == .phone ? 44 : 48 }
        var placeholder: String { self == .phone ? "Search" : "Search Title or Author" }
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
                .libraryIconFrame(style.height, square: false)
                .accessibilityHidden(true)
            TextField(style.placeholder, text: Binding(get: { libVM.searchText }, set: libVM.editQuery),
                      prompt: Text(style.placeholder).foregroundStyle(style.placeholderColor))
                .font(AppTypography.body(style == .phone ? .medium : .regular))
                .foregroundStyle(AppColors.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .padding(.vertical, 4)
                .focused(focus)
                .accessibilityLabel("Search by title or author")
            if libVM.isDictating {
                fieldButton("stop.fill", label: "Stop dictation", action: libVM.stopDictation)
            } else if !libVM.searchText.isEmpty {
                fieldButton("xmark.circle", label: "Clear search") {
                    libVM.editQuery("")
                    focus.wrappedValue = true
                }
            } else {
                fieldButton("mic.fill", label: "Search by voice", action: libVM.voiceSearchTapped)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 2)
    }

    private func fieldButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(AppTypography.body())
                .foregroundStyle(style.iconColor)
                .libraryIconFrame(44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

private struct LibrarySearchPreview: View {
    @FocusState private var isFocused: Bool
    private let libVM = PreviewFixtures.libraryVM()

    var body: some View {
        LibrarySearchBar(libVM: libVM, focus: $isFocused)
            .padding()
            .background(AppColors.bgPrimary)
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
