import Foundation
import SwiftData

@MainActor
final class ListSetupManager: ObservableObject {
    @Published var step: WizardStep = .welcome
    @Published var existingLists: [HardcoverList] = []
    @Published var matchResults: [DJListMatch] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var creationProgress: Int = 0
    @Published var creationTotal: Int = 0

    private let hardcoverService: HardcoverServiceProtocol

    init(hardcoverService: HardcoverServiceProtocol) {
        self.hardcoverService = hardcoverService
    }

    // MARK: - Wizard Flow

    func scanExistingLists() async {
        step = .scanning
        isLoading = true
        errorMessage = nil

        do {
            existingLists = try await hardcoverService.getUserLists()
            matchResults = buildMatchResults()
            step = .matching
        } catch {
            errorMessage = "Could not load your lists: \(error.localizedDescription)"
            step = .welcome
        }

        isLoading = false
    }

    func createMissingLists(context: ModelContext) async {
        let listsToCreate = matchResults.filter { $0.matchedList == nil && $0.selectedListId == nil }
        let listsToMap = matchResults.filter { $0.matchedList != nil || $0.selectedListId != nil }

        step = .creating
        creationTotal = listsToCreate.count
        creationProgress = 0
        errorMessage = nil

        // Save mappings for already-matched lists
        for match in listsToMap {
            let listId: Int
            let listName: String
            if let selectedId = match.selectedListId,
               let existing = existingLists.first(where: { $0.id == selectedId }) {
                listId = existing.id
                listName = existing.name
            } else if let matched = match.matchedList {
                listId = matched.id
                listName = matched.name
            } else {
                continue
            }

            let mapping = ListMapping(
                djListKey: match.djList.key,
                hardcoverListId: listId,
                hardcoverListName: listName
            )
            context.insert(mapping)
        }

        // Create missing lists sequentially with delay
        for match in listsToCreate {
            do {
                let created = try await hardcoverService.createList(name: match.djList.key)
                let mapping = ListMapping(
                    djListKey: match.djList.key,
                    hardcoverListId: created.id,
                    hardcoverListName: created.name
                )
                context.insert(mapping)
                creationProgress += 1

                // Mandatory delay to avoid position conflicts
                try await Task.sleep(for: .seconds(1))
            } catch {
                errorMessage = "Failed to create \(match.djList.displayName): \(error.localizedDescription)"
                // Continue creating remaining lists
            }
        }

        try? context.save()

        // Only mark complete if at least some lists were created/mapped
        let totalMapped = listsToMap.count + creationProgress
        if totalMapped == 0 && !listsToCreate.isEmpty {
            // All creations failed, stay on creating step so user sees the error
            step = .creating
        } else {
            step = .complete
        }
    }

    /// User manually selects a Hardcover list for a DJ list
    func assignList(djListKey: String, hardcoverListId: Int?) {
        if let index = matchResults.firstIndex(where: { $0.djList.key == djListKey }) {
            matchResults[index].selectedListId = hardcoverListId
        }
    }

    // MARK: - Fuzzy Matching

    private func buildMatchResults() -> [DJListMatch] {
        DJList.all.map { djList in
            let bestMatch = findBestMatch(for: djList.key, in: existingLists)
            return DJListMatch(
                djList: djList,
                matchedList: bestMatch?.list,
                matchDistance: bestMatch?.distance ?? Int.max,
                selectedListId: bestMatch?.distance ?? Int.max <= 3 ? bestMatch?.list.id : nil
            )
        }
    }

    private func findBestMatch(for name: String, in lists: [HardcoverList]) -> (list: HardcoverList, distance: Int)? {
        let normalized = name.lowercased()

        var best: (list: HardcoverList, distance: Int)?
        for list in lists {
            let listName = list.name.lowercased()

            // Exact match
            if listName == normalized {
                return (list, 0)
            }

            // Contains match (e.g., user has "Owned Hardback" vs "[DJ] Owned · Hardback")
            if listName.contains(normalized) || normalized.contains(listName) {
                let dist = abs(listName.count - normalized.count)
                if best == nil || dist < best!.distance {
                    best = (list, min(dist, 2))
                }
                continue
            }

            // Levenshtein distance
            let dist = levenshtein(listName, normalized)
            if dist <= 5 && (best == nil || dist < best!.distance) {
                best = (list, dist)
            }
        }

        return best
    }

    private func levenshtein(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }

        return matrix[m][n]
    }
}

// MARK: - Supporting Types

enum WizardStep: Equatable {
    case welcome
    case scanning
    case matching
    case creating
    case complete
}

struct DJListMatch: Identifiable {
    let djList: DJList
    var matchedList: HardcoverList?
    var matchDistance: Int
    var selectedListId: Int?

    var id: String { djList.key }

    var isAutoMatched: Bool {
        matchDistance <= 3 && matchedList != nil
    }

    var isResolved: Bool {
        selectedListId != nil
    }

    var displayMatchName: String? {
        if let selectedId = selectedListId,
           let matched = matchedList, matched.id == selectedId {
            return matched.name
        }
        return matchedList?.name
    }
}
