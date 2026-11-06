import SwiftUI

struct ReaderMenuView: View {
    let readerVM: ReaderVM
    let ratingVM: RatingVM

    var body: some View {
        VStack(spacing: 0) {
            Button {
                readerVM.contentsTapped()
            } label: {
                row("Contents", systemImage: "list.bullet")
            }
            Button {
                readerVM.searchTapped()
            } label: {
                row("Search in Book", systemImage: "magnifyingglass")
            }
            Button {
                readerVM.themeSettingsTapped()
            } label: {
                row("Theme & Settings", systemImage: "textformat")
            }
            Toggle("Share Ratings", isOn: Binding(
                get: { ratingVM.sharesRatings },
                set: { ratingVM.sharingChosen($0) }
            ))
            .padding(.horizontal, 20)
            .frame(minHeight: 44)
            if let account = ratingVM.cloudAccount {
                cloudRow(account)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .frame(maxWidth: 280)
        .presentationCompactAdaptation(.popover)
        .presentationBackground(Color(.systemBackground))
    }

    /// Only the Settings app can sign in, so this just says how iCloud stands.
    private func cloudRow(_ account: CloudAccount) -> some View {
        let (title, detail, systemImage): (String, String?, String) = switch account {
        case .signedIn: ("iCloud On", nil, "icloud")
        case .signedOut: ("iCloud Off", "Sign in in the Settings app to keep underlines on all your devices.", "icloud.slash")
        case .restricted: ("iCloud Not Allowed", "iCloud is turned off for this device.", "icloud.slash")
        case .unknown: ("iCloud Not Reachable", "Underlines are kept on this device for now.", "exclamationmark.icloud")
        }
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
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
