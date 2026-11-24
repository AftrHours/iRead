import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @Bindable var onboardingVM: OnboardingVM
    let onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isImportedBookRevealed = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $onboardingVM.page) {
                ForEach(0..<4) { index in
                    page(index).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .disabled(onboardingVM.isImporting)

            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    Circle().fill(AppColors.textPrimary.opacity(index == onboardingVM.page ? 1 : 0.45))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
            .accessibilityLabel("Page \(onboardingVM.page + 1) of 4")
            .accessibilityAdjustableAction { direction in
                guard !onboardingVM.isImporting else { return }
                switch direction {
                case .increment: onboardingVM.page = min(3, onboardingVM.page + 1)
                case .decrement: onboardingVM.page = max(0, onboardingVM.page - 1)
                @unknown default: break
                }
            }
            .padding(.bottom, 12)
        }
        .background(AppColors.bgPrimary.ignoresSafeArea())
        .task { await onboardingVM.library.prepareOnboardingBooks() }
        .fileImporter(isPresented: $onboardingVM.isPickingBook, allowedContentTypes: [.epub],
                      allowsMultipleSelection: false, onCompletion: onboardingVM.importPickerCompleted,
                      onCancellation: onboardingVM.importPickerCancelled)
        .alert("Couldn’t add book", isPresented: Binding(get: { onboardingVM.importError != nil },
                                                        set: { if !$0 { onboardingVM.importError = nil } })) {
            Button("OK") { onboardingVM.importError = nil }
        } message: { Text(onboardingVM.importError ?? "") }
    }

    private func page(_ index: Int) -> some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width, 530)
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 16) {
                        Text(onboardingVM.heading(for: index))
                            .font(AppTypography.largeTitle()).foregroundStyle(AppColors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text(onboardingVM.subtitle(for: index))
                            .font(AppTypography.title3())
                            .foregroundStyle(Color("OnboardingSubtitle"))
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: width * 0.83)
                    Spacer(minLength: 24)
                    artwork(index, width: width)
                    Spacer(minLength: 24)
                    Group {
                        if index == 0 {
                            if onboardingVM.isImporting {
                                ProgressView("Importing book")
                            } else {
                                AddBookButton(size: 50, symbolWeight: .medium, action: onboardingVM.importTapped)
                            }
                        } else if index == 3 {
                            Button(action: onFinish) {
                                Text("See my Library")
                                    .font(AppTypography.body(.medium)).padding(.horizontal, 20)
                                    .frame(minHeight: 50).contentShape(Capsule())
                            }
                                .glassEffect(.regular.tint(AppColors.actionPrimary).interactive(), in: Capsule())
                        } else {
                            Color.clear.frame(height: 50).accessibilityHidden(true)
                        }
                    }
                    .foregroundStyle(.black)
                    .buttonStyle(.plain)
                }
                .padding(.top, min(54, geometry.size.height * 0.07))
                .padding(.bottom, min(56, geometry.size.height * 0.075))
                .frame(width: geometry.size.width)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    @ViewBuilder
    private func artwork(_ index: Int, width: CGFloat) -> some View {
        switch index {
        case 0:
            let coverWidth = width * 0.33
            let coverHeight = coverWidth / BookCoverView.aspectRatio
            OnboardingBookCarousel(
                books: onboardingVM.samples, spacingBetweenCenters: coverWidth + width * 0.025, centerIndex: 1,
                isActive: onboardingVM.page == 0 && !onboardingVM.isPickingBook && !onboardingVM.isImporting
            ) { book in
                BookCoverView(image: onboardingVM.library.covers[book.id])
                    .frame(width: coverWidth, height: coverHeight)
                    .border(.white, width: 1.5)
            }
            .rotationEffect(.degrees(5))
            .offset(x: -width * 0.03)
            .frame(width: width, height: coverHeight + width * 0.12)
            .clipped()
            .frame(height: coverHeight)
        case 1:
            if let book = onboardingVM.importedBook {
                illustration(book, details: true)
                    .frame(width: width * 0.43)
                    .shadow(color: .white.opacity(0.5), radius: 10)
                    .scaleEffect(reduceMotion || isImportedBookRevealed ? 1 : 0.55)
                    .opacity(reduceMotion || isImportedBookRevealed ? 1 : 0.35)
                    .onChange(of: onboardingVM.page == 1, initial: true) { _, isVisible in
                        withAnimation(isVisible && !reduceMotion ? .easeOut(duration: 0.8) : nil) {
                            isImportedBookRevealed = isVisible
                        }
                    }
                    .onDisappear { isImportedBookRevealed = false }
            } else {
                sampleShelf(width: width)
            }
        case 2:
            OnboardingReferencePreview(isActive: onboardingVM.page == 2)
                .frame(width: width * 0.90)
        default:
            Image("OnboardingShelf").resizable().scaledToFit()
                .frame(width: width * 0.625).accessibilityHidden(true)
        }
    }

    private func sampleShelf(width: CGFloat) -> some View {
        let cardWidth = width * 0.206
        let cardScale = cardWidth / 171
        let shelfHeight = width * 0.585
        return Image("OnboardingSampleShelf")
            .resizable()
            .frame(width: shelfHeight * 1069 / 481, height: shelfHeight)
            .overlay {
                OnboardingBookCarousel(
                    books: onboardingVM.samples, spacingBetweenCenters: cardWidth + width * 0.018,
                    centerIndex: onboardingVM.samples.count / 2, isActive: onboardingVM.page == 1
                ) { book in
                    illustration(book, details: true)
                        .frame(width: 171, height: 340, alignment: .top)
                        .background(AppColors.cardBg, in: .rect(cornerRadius: 16))
                        .clipShape(.rect(cornerRadius: 16))
                        .scaleEffect(cardScale)
                        .frame(width: cardWidth, height: 340 * cardScale)
                }
                .dynamicTypeSize(.large)
                .offset(y: -width * 0.014)
            }
            .frame(width: width)
            .clipped()
            .accessibilityHidden(true)
    }

    private func illustration(_ book: BookRecord, details: Bool) -> some View {
        OnboardingBookIllustration(book: book, image: onboardingVM.library.covers[book.id], showsDetails: details)
    }
}

#Preview("First launch") {
    OnboardingView(onboardingVM: PreviewFixtures.onboardingVM(), onFinish: {})
}
