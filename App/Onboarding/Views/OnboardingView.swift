import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @Bindable var onboardingVM: OnboardingVM
    let onFinish: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 28)
                .padding(.top, 8)

            TabView(selection: $onboardingVM.page) {
                uploadPage.tag(0)
                referencePage.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: onboardingVM.page)

            pageControls
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
        }
        .background(LibraryPalette.page.ignoresSafeArea())
        .fileImporter(
            isPresented: $onboardingVM.isPickingBook,
            allowedContentTypes: [.epub],
            allowsMultipleSelection: true,
            onCompletion: onboardingVM.importPickerCompleted
        )
        .alert("Couldn’t add book", isPresented: $onboardingVM.isImportAlertPresented) {
            Button("OK", role: .cancel) { onboardingVM.dismissImportError() }
        } message: {
            Text(onboardingVM.importError ?? "Please choose an EPUB file.")
        }
        .onChange(of: onboardingVM.shouldFinish) { _, shouldFinish in
            if shouldFinish { onFinish() }
        }
    }

    private var topBar: some View {
        HStack {
            Text("GETTING STARTED")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(LibraryPalette.secondaryText)
            Spacer(minLength: 8)
            Button("Skip", action: onboardingVM.skipTapped)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LibraryPalette.primaryText)
                .padding(.horizontal, 18)
                .frame(minHeight: 38)
                .background(LibraryPalette.controlFill.opacity(0.7), in: .capsule)
        }
        .frame(minHeight: 48)
    }

    private var uploadPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("BRING YOUR BOOKS")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(LibraryPalette.secondaryText)

                Text("Your next story starts in your Library")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(LibraryPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Add an EPUB to build your collection. Your books and reading progress stay on this iPad.")
                    .font(.body)
                    .foregroundStyle(LibraryPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onboardingVM.importTapped) {
                    HStack(spacing: 16) {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(LibraryPalette.addButton, in: .circle)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Choose an EPUB file")
                                .font(.headline)
                                .foregroundStyle(LibraryPalette.primaryText)
                            Text("Browse files on your device")
                                .font(.subheadline)
                                .foregroundStyle(LibraryPalette.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(LibraryPalette.secondaryText)
                    }
                    .padding(18)
                    .background(LibraryPalette.card, in: .rect(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the Apple document picker filtered to EPUB files")

                HStack(spacing: 12) {
                    OnboardingBookIllustration(symbol: "book.closed.fill", tint: LibraryPalette.addButton, rotation: -8)
                    OnboardingBookIllustration(symbol: "text.book.closed.fill", tint: LibraryPalette.secondaryText, rotation: 7)
                    OnboardingBookIllustration(symbol: "book.closed.fill", tint: LibraryPalette.controlFill, rotation: -3)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .accessibilityHidden(true)
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(.horizontal, 36)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
    }

    private var referencePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("FOLLOW A CONNECTION")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(LibraryPalette.secondaryText)

                Text("Tap an underlined phrase to revisit an earlier passage")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(LibraryPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("See where that detail first appeared, in the author’s own words.")
                    .font(.body)
                    .foregroundStyle(LibraryPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                OnboardingReferencePreview()
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(.horizontal, 36)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
    }

    private var pageControls: some View {
        Group {
          if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 16) {
                pageIndicator
                primaryButton
            }
          } else {
            HStack(spacing: 16) {
                pageIndicator
                Spacer()
                primaryButton
            }
          }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 7) {
            ForEach(0..<2) { index in
                Capsule()
                    .fill(onboardingVM.isPageSelected(index) ? LibraryPalette.secondaryText : LibraryPalette.divider)
                    .frame(width: onboardingVM.isPageSelected(index) ? 22 : 7, height: 7)
            }
        }
        .accessibilityLabel(onboardingVM.pageIndicatorLabel)
    }

    private var primaryButton: some View {
        Button(action: onboardingVM.primaryActionTapped) {
            HStack(spacing: 8) {
                Text(onboardingVM.primaryActionTitle)
                Image(systemName: onboardingVM.primaryActionSymbol)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(minHeight: 48)
            .background(LibraryPalette.secondaryText, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}
