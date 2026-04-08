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
            // Ownership toggle
            HStack(spacing: 0) {
                ForEach(OwnershipType.allCases) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedOwnership = type
                        }
                    } label: {
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.caption)
                                Text(type.rawValue)
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)

                            // Active indicator line
                            Rectangle()
                                .fill(selectedOwnership == type ? ownershipAccent : .clear)
                                .frame(height: 2)
                        }
                        .foregroundStyle(selectedOwnership == type ? ownershipAccent : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

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
            // Drain pending mutations first, then refresh from server
            await MutationQueue.shared.processQueue()
            await libraryManager.fetchLibrary(refresh: true)
        }
        .task {
            // Only fetch if we don't have data yet — ContentView.task handles initial load
            if libraryManager.books.isEmpty {
                await libraryManager.fetchLibrary()
            }
        }
    }

    private var filteredBooks: [Book] {
        libraryManager.filteredBooks(ownership: selectedOwnership, format: selectedFormat)
    }

    private var ownershipAccent: Color {
        selectedOwnership == .owned ? .green : .blue
    }
}
