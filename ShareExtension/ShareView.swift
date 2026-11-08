import SwiftUI

/// Looks like the system's own share compose sheet: Cancel, the title, Send.
struct ShareView: View {
    let shareVM: ShareVM
    let link: URL?

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
                .navigationTitle("iRead")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { shareVM.cancelTapped() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send") { shareVM.sendTapped() }
                            .disabled(!shareVM.isSendEnabled)
                    }
                }
        }
        .task { await shareVM.onAppear(link: link) }
    }

    @ViewBuilder private var content: some View {
        switch shareVM.state {
        case .searching:
            VStack(spacing: 12) {
                ProgressView()
                Text(ShareVM.searchingMessage).foregroundStyle(.secondary)
            }
        case .found(let edition):
            VStack(spacing: 8) {
                Image(systemName: "book.closed").font(.system(size: 40)).foregroundStyle(.tint)
                Text(edition.title).font(.headline).multilineTextAlignment(.center)
                Text(edition.author).foregroundStyle(.secondary)
                Text(ShareVM.foundNote).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 40)).foregroundStyle(.orange)
                Text(message).multilineTextAlignment(.center)
            }
        }
    }
}
