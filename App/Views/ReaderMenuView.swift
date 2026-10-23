import SwiftUI

struct ReaderMenuView: View {
    let readerVM: ReaderVM

    var body: some View {
        VStack(spacing: 0) {
            Button {
                readerVM.contentsTapped()
            } label: {
                row("Contents", systemImage: "list.bullet")
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .frame(width: 280)
        .presentationCompactAdaptation(.popover)
        .presentationBackground(Color(.systemBackground))
    }

    private func row(_ title: String, systemImage: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: systemImage)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 44)
        .contentShape(.rect)
    }
}
