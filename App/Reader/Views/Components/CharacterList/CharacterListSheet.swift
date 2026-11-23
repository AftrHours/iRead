import SwiftUI
import UIKit

/// "Characters so far", built like `ContentsSheet` and `SearchView`.
struct CharacterListSheet: View {
    let characterVM: CharacterVM
    @Environment(\.dismiss) private var dismiss
    @State private var isSearchPresented = false

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.sheetbg)
                .searchable(
                    text: Binding(get: { characterVM.query }, set: { characterVM.queryChanged($0) }),
                    isPresented: $isSearchPresented,
                    prompt: "Search character"
                )
                .searchPresentationToolbarBehavior(.avoidHidingContent)
                .onSubmit(of: .search) { characterVM.querySubmitted() }
                .navigationTitle("Characters so far")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // While searching, the search field has its own ×.
                    if !isSearchPresented {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(role: .close) {
                                dismiss()
                            }
                            .dynamicTypeSize(...PageLayoutKnobs.maximumIconSize)
                        }
                    }
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AppColors.sheetbg)
        .onDisappear(perform: characterVM.sheetClosed)
    }

    @ViewBuilder
    private var content: some View {
        if !characterVM.hasLoaded {
            ProgressView()
        } else if characterVM.showsEmptyState {
            CharacterEmptyState(illustration: "LibraryEmptyState", title: "No character yet.\nKeep reading!")
        } else if isSearchPresented, characterVM.query.isEmpty, !characterVM.recentSearches.isEmpty {
            recentSearches
        } else if characterVM.showsNotFound {
            CharacterEmptyState(illustration: "SearchEmptyState", title: "Uh oh we can’t find that here...",
                                message: "Make sure you spell the name correctly.")
        } else {
            characterList
        }
    }

    private var characterList: some View {
        List(characterVM.shownCharacters) { character in
            CharacterRow(
                character: character,
                passage: characterVM.passage(of: character),
                isOpen: characterVM.openedID == character.id,
                onTapped: { characterVM.rowTapped(character) },
                onJumpTapped: { characterVM.jumpTapped(character) }
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var recentSearches: some View {
        List {
            HStack {
                Text("Recent Searches")
                    .font(AppTypography.title3(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Clear") {
                    characterVM.clearRecentSearchesTapped()
                }
                .font(AppTypography.body())
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
            }
            .listRowBackground(Color.clear)
            ForEach(characterVM.recentSearches, id: \.self) { query in
                Button {
                    characterVM.recentSearchTapped(query)
                } label: {
                    Label { Text(query) } icon: {
                        Image(systemName: "magnifyingglass")
                            .dynamicTypeSize(...PageLayoutKnobs.maximumIconSize)
                    }
                    .font(AppTypography.body(.medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct CharacterRow: View {
    let character: BookCharacter
    let passage: String
    let isOpen: Bool
    let onTapped: () -> Void
    let onJumpTapped: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { onTapped() }
            } label: {
                HStack {
                    Text(character.name)
                        .font(AppTypography.body(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .dynamicTypeSize(...PageLayoutKnobs.maximumIconSize)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 54)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint(isOpen ? "Hides the passage." : "Shows the passage that describes them.")

            if isOpen {
                Text(passage)
                    .font(AppTypography.callout())
                    .foregroundStyle(AppColors.popoverPassageText)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.popoverPassageBg, in: .rect(cornerRadius: 8))
                if character.underlineID != nil {
                    jumpButton
                }
            }
        }
        .padding(.bottom, isOpen ? 16 : 0)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    /// The reference card's Jump to Passage. An HStack, as a Label in a List puts its icon far from the text.
    private var jumpButton: some View {
        Button(action: onJumpTapped) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.left")
                    .dynamicTypeSize(...PageLayoutKnobs.maximumIconSize)
                Text("Jump to Passage")
            }
            .font(AppTypography.footnote(.medium))
            .lineLimit(1)
            .foregroundStyle(AppColors.actionPrimaryText)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(AppColors.actionPrimary, in: .capsule)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Laid out like the library's empty search.
private struct CharacterEmptyState: View {
    /// A PNG in Resources/Illustrations.
    let illustration: String
    let title: String
    var message: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                if let image = UIImage(named: illustration) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 200)
                        .accessibilityHidden(true)
                }
                VStack(spacing: 8) {
                    Text(title)
                        .font(AppTypography.title3(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let message {
                        Text(message)
                            .font(AppTypography.subheadline(.medium))
                            .foregroundStyle(AppColors.searchEmptyMessageText)
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.top, 120)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

#Preview("Characters") {
    Color.gray.opacity(0.2)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            CharacterListSheet(characterVM: PreviewFixtures.characterVM())
        }
}
