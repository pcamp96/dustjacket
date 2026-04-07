import SwiftUI

struct LibraryView: View {
    @ObservedObject var libraryManager: LibraryManager
    @State private var selectedOwnership: OwnershipType = .owned
    @State private var selectedFormat: BookFormat?

    private let columns = [
        GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Ownership segmented control
            Picker("Ownership", selection: $selectedOwnership) {
                ForEach(OwnershipType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Format filter pills
            FormatFilterBar(selectedFormat: $selectedFormat)
                .padding(.bottom, 8)

            // Book grid
            if libraryManager.isLoading && libraryManager.books.isEmpty {
                Spacer()
                ProgressView("Loading your library...")
                Spacer()
            } else if filteredBooks.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Books Yet",
                    systemImage: "book.closed",
                    description: Text("Scan a barcode or search to add books.")
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredBooks) { book in
                            NavigationLink(value: book) {
                                BookCardView(book: book)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                Task {
                                    await libraryManager.loadMoreIfNeeded(currentBook: book)
                                }
                            }
                        }
                    }
                    .padding()

                    if libraryManager.isLoadingMore {
                        ProgressView()
                            .padding()
                    }
                }
            }
        }
        .navigationDestination(for: Book.self) { book in
            BookDetailView(book: book)
        }
        .refreshable {
            await libraryManager.fetchLibrary(refresh: true)
        }
        .task {
            if libraryManager.books.isEmpty {
                await libraryManager.fetchLibrary()
            }
        }
    }

    private var filteredBooks: [Book] {
        libraryManager.filteredBooks(ownership: selectedOwnership, format: selectedFormat)
    }
}
