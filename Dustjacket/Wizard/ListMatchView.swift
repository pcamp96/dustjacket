import SwiftUI

struct ListMatchView: View {
    @Binding var matches: [DJListMatch]
    let existingLists: [HardcoverList]
    var onAssign: (String, Int?) -> Void
    var onConfirm: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("We found your existing lists. Confirm or adjust the mappings below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                ForEach(OwnershipType.allCases) { ownership in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(ownership.rawValue)
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(matches.filter { $0.djList.ownership == ownership }) { match in
                            ListMatchRow(
                                match: match,
                                existingLists: existingLists,
                                onSelect: { listId in
                                    onAssign(match.djList.key, listId)
                                }
                            )
                        }
                    }
                }

                Button {
                    onConfirm()
                } label: {
                    Text("Confirm & Create Missing Lists")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Match Row

private struct ListMatchRow: View {
    let match: DJListMatch
    let existingLists: [HardcoverList]
    var onSelect: (Int?) -> Void

    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: match.djList.icon)
                    .frame(width: 24)
                Text(match.djList.format.rawValue)
                    .font(.subheadline.bold())

                Spacer()

                statusBadge
            }

            if let matchName = match.displayMatchName {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(matchName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Will be created")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if showPicker {
                Picker("Choose a list", selection: Binding(
                    get: { match.selectedListId },
                    set: { onSelect($0) }
                )) {
                    Text("Create new").tag(nil as Int?)
                    ForEach(existingLists, id: \.id) { list in
                        Text(list.name).tag(list.id as Int?)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .onTapGesture {
            withAnimation { showPicker.toggle() }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if match.isAutoMatched {
            Label("Matched", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else if match.isResolved {
            Label("Assigned", systemImage: "hand.point.right.fill")
                .font(.caption)
                .foregroundStyle(.blue)
        } else {
            Label("New", systemImage: "plus.circle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
