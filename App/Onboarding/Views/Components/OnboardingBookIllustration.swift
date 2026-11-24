import SwiftUI

struct OnboardingBookIllustration: View {
    let book: BookRecord
    let image: UIImage?
    let showsDetails: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BookCoverView(image: image)
            if showsDetails {
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(AppColors.progressBarBg).frame(height: 4)
                    Text(book.title).font(AppTypography.footnote(.semibold))
                        .foregroundStyle(AppColors.cardTextPrimary)
                    Text(book.author).font(AppTypography.caption1())
                        .foregroundStyle(AppColors.cardTextSecondary)
                }
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .padding(10)
            }
        }
        .background(AppColors.cardBg)
        .clipShape(.rect(cornerRadius: showsDetails ? 12 : 0))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book.title), \(book.author)")
    }
}

/// Both onboarding carousels advance one book every six seconds.
struct OnboardingBookCarousel<Card: View>: View {
    let books: [BookRecord]
    let spacingBetweenCenters: CGFloat
    let centerIndex: Int
    let isActive: Bool
    @ViewBuilder let card: (BookRecord) -> Card

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var start = Date.now

    var body: some View {
        let playing = isActive && !reduceMotion && scenePhase == .active && books.count > 1
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playing)) { timeline in
            let position = playing ? max(0, timeline.date.timeIntervalSince(start)) / 6 : 0
            let step = Int(position)
            let fraction = CGFloat(position - Double(step))
            ZStack {
                if books.count == 1 {
                    card(books[0])
                } else if !books.isEmpty {
                    // Include the next book just outside either edge for a seamless wrap.
                    ForEach(-3...3, id: \.self) { slot in
                        let index = (step + centerIndex + slot) % books.count
                        card(books[(index + books.count) % books.count])
                            .offset(x: (CGFloat(slot) - fraction) * spacingBetweenCenters)
                    }
                }
            }
        }
        .onChange(of: playing, initial: true) { start = .now }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
