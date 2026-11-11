import SwiftUI

/// Where the earlier passage is, as a small chip: CHAPTER • PAGE.
struct RefLocation: View {
    let location: String

    var body: some View {
        Text(location)
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .lineLimit(1)
            .foregroundStyle(RefPalette.onChip)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(RefPalette.chipFill, in: .rect(cornerRadius: 8))
    }
}

#Preview {
    RefLocation(location: "Chapter 1 • Page 8")
        .padding()
        .background(RefPalette.card)
}
