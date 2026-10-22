// VM/LibVM.swift
import SwiftUI

@MainActor
class LibVM: ObservableObject {
    @Published var continueBooks: [BookRecord] = []
    @Published var allBooks: [BookRecord] = []
    @Published var isGridView: Bool = true
    
    private let libCtrl: any LibCtrl
    
    init(libCtrl: any LibCtrl) {
        self.libCtrl = libCtrl
    }
    
    func onAppear() async {
        do {
            let books = try await libCtrl.loadLibrary()
            continueBooks = books.filter { $0.isContinueReading }
            allBooks = books.filter { !$0.isContinueReading }
        } catch {
            print("Error loading books: \(error)")
        }
    }
    
    func gridTapped() {
        isGridView = true
    }
    
    func rowTapped() {
        isGridView = false
    }
    
    func addTapped() {
        // Handle add intent
    }
    
    func searchTapped() {
        // Handle search intent
    }
    
    func bookTapped(_ book: BookRecord) {
        // Handle book selection
    }
}
