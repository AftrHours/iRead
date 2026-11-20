import SwiftUI

/// The focused iPhone search row, rendered with native Liquid Glass surfaces.
struct LibraryActiveSearchHeader: View {
    let libVM: LibVM
    let searchFocus: FocusState<Bool>.Binding

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                LibrarySearchBar(libVM: libVM, focus: searchFocus, style: .phoneActive)
                    .frame(maxWidth: .infinity)
                Button(action: libVM.searchDismissed) {
                    Image(systemName: "xmark")
                        .font(AppTypography.title2(.regular))
                        .foregroundStyle(.primary)
                        .libraryIconFrame()
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .libraryControlLabel("Close search", symbol: "xmark")
            }
        }
        .task {
            await Task.yield()
            guard !Task.isCancelled else { return }
            searchFocus.wrappedValue = true
        }
    }
}

private struct ActiveSearchPreview: View {
    @FocusState private var isFocused: Bool
    private let libVM = PreviewFixtures.libraryVM()

    var body: some View {
        LibraryActiveSearchHeader(libVM: libVM, searchFocus: $isFocused)
            .padding(8)
            .background(AppColors.bgPrimary)
    }
}

#Preview("Active iPhone Search — Dark") {
    ActiveSearchPreview()
        .preferredColorScheme(.dark)
}

#Preview("Active iPhone Search — Light") {
    ActiveSearchPreview()
        .preferredColorScheme(.light)
}
