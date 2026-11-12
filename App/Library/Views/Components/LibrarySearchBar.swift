import SwiftUI

/// Renders search input and forwards voice-search events; focus remains a SwiftUI concern.
struct LibrarySearchBar: View {
    @Bindable var libVM: LibVM
    let focus: FocusState<Bool>.Binding
    var focusesOnContainerTap = true

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.textSecondary)
            TextField("Search Title or Author", text: $libVM.searchText)
                .font(AppTypography.body())
                .foregroundStyle(AppColors.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused(focus)
            Button(action: libVM.voiceSearchTapped) {
                Image(systemName: libVM.voiceSearchSymbol)
                    .font(AppTypography.callout())
                    .foregroundStyle(libVM.isVoiceSearchActive ? AppColors.actionPrimary : AppColors.textSecondary)
                    .frame(width: 32, height: 40)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(libVM.voiceSearchAccessibilityLabel)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .glassEffect(.regular, in: .capsule)
        .contentShape(.capsule)
        .simultaneousGesture(TapGesture().onEnded {
            if focusesOnContainerTap { focus.wrappedValue = true }
        })
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

#Preview("Library Search") {
    LibrarySearchPreview()
}
