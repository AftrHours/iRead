import SwiftUI

/// Top of the reference card: the quote tile, "Mentioned earlier", and where the passage is.
struct RefHeader: View {
    let location: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "quote.opening")
                .font(.title.weight(.black))
                .foregroundStyle(RefPalette.onTile)
                .frame(width: 56, height: 56)
                .background(RefPalette.tileFill, in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text("Mentioned earlier")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(RefPalette.text)
                RefLocation(location: location)
            }
        }
    }
}

#Preview {
    RefHeader(location: "Chapter 1 • Page 8")
        .padding()
        .background(RefPalette.card)
}
