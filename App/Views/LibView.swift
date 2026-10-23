import SwiftUI

struct LibView: View {
    let libVM: LibVM
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBarView
                .padding(.horizontal)
                .padding(.bottom, 24)
            
            headerView
                .padding(.horizontal)
                .padding(.bottom, 24)
            
            if libVM.continueBooks.isEmpty && libVM.allBooks.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        if !libVM.continueBooks.isEmpty {
                            bookSection(title: "Continue", books: libVM.continueBooks)
                        }
                        
                        if !libVM.allBooks.isEmpty {
                            bookSection(title: "All Books", books: libVM.allBooks)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            await libVM.onAppear()
        }
    }
    
    private var topBarView: some View {
        HStack {
            Spacer()
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Search Book")
                    .foregroundColor(.gray)
                Spacer()
                Image(systemName: "mic")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().stroke(Color.gray.opacity(0.3)))
            .frame(width: 200)
            .onTapGesture { libVM.searchTapped() }
            
            Button(action: { libVM.addTapped() }) {
                Image(systemName: "plus")
                    .padding(12)
                    .background(Circle().fill(Color.gray.opacity(0.2)))
                    .foregroundColor(.black)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Library")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: { libVM.viewModeChanged(.grid) }) {
                    Image(systemName: "square.grid.2x2")
                        .padding(8)
                        .background(Circle().stroke(libVM.viewMode == .grid ? Color.gray : Color.clear))
                        .foregroundColor(.black)
                }

                Button(action: { libVM.viewModeChanged(.list) }) {
                    Image(systemName: "line.3.horizontal")
                        .padding(8)
                        .background(Circle().stroke(libVM.viewMode == .list ? Color.gray : Color.clear))
                        .foregroundColor(.black)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text("No book")
                .font(.headline)
            Text("Tap the \"+\" button to add\nyour first book")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private func bookSection(title: String, books: [BookRecord]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            
            if libVM.viewMode == .grid {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(books) { book in
                        BookGridView(book: book)
                            .onTapGesture { libVM.bookTapped(book) }
                    }
                }
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(books) { book in
                        BookRowView(book: book)
                            .onTapGesture { libVM.bookTapped(book) }
                        Divider()
                    }
                }
            }
        }
    }
}

#Preview("Library View") {
    LibView(libVM: LibVM(libCtrl: LibCtrlLive(libRepo: LibRepoSample()), nav: AppNav()))
}
