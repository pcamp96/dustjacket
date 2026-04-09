import SwiftUI

enum ProgressMode: String, CaseIterable {
    case pages = "Pages"
    case time = "Time"
    case percent = "Percent"
}

/// The result of a progress update — one of three types
enum ProgressUpdate {
    case pages(Int)
    case percent(Double)
    case seconds(Int)
}

struct ProgressUpdateSheet: View {
    let bookTitle: String
    let totalPages: Int?
    let isAudiobook: Bool
    let initialPages: Int
    let initialPercent: Double
    let initialSeconds: Int
    var onSave: (ProgressUpdate) -> Void
    var onMarkFinished: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var mode: ProgressMode
    @State private var currentPage: Int
    @State private var currentPercent: Double
    @State private var hours: Int
    @State private var minutes: Int

    /// Available modes based on whether this is an audiobook
    var availableModes: [ProgressMode] {
        if isAudiobook {
            return [.time, .percent]
        } else {
            return [.pages, .percent]
        }
    }

    init(
        bookTitle: String,
        totalPages: Int?,
        isAudiobook: Bool = false,
        currentPage: Int = 0,
        currentPercent: Double = 0,
        currentSeconds: Int = 0,
        onSave: @escaping (ProgressUpdate) -> Void,
        onMarkFinished: (() -> Void)? = nil
    ) {
        self.bookTitle = bookTitle
        self.totalPages = totalPages
        self.isAudiobook = isAudiobook
        self.initialPages = currentPage
        self.initialPercent = currentPercent
        self.initialSeconds = currentSeconds
        self.onSave = onSave
        self.onMarkFinished = onMarkFinished

        // Default mode based on format
        let defaultMode: ProgressMode
        if isAudiobook {
            defaultMode = currentSeconds > 0 ? .time : .percent
        } else {
            if currentPage > 0 && totalPages != nil {
                defaultMode = .pages
            } else if currentPercent > 0 {
                defaultMode = .percent
            } else if totalPages != nil {
                defaultMode = .pages
            } else {
                defaultMode = .percent
            }
        }

        _mode = State(initialValue: defaultMode)
        _currentPage = State(initialValue: currentPage)
        _currentPercent = State(initialValue: currentPercent > 0 ? currentPercent : 0)
        _hours = State(initialValue: currentSeconds / 3600)
        _minutes = State(initialValue: (currentSeconds % 3600) / 60)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Mode picker
                    Picker("Progress Type", selection: $mode) {
                        ForEach(availableModes, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 8)

                    // Progress display
                    progressHeader

                    // Input for selected mode
                    switch mode {
                    case .pages:
                        pagesInput
                    case .time:
                        timeInput
                    case .percent:
                        percentInput
                    }

                    Spacer(minLength: 24)

                    // Actions
                    VStack(spacing: 12) {
                        Button {
                            onSave(currentUpdate)
                            dismiss()
                        } label: {
                            Text("Save Progress")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        if let onMarkFinished {
                            Button {
                                onMarkFinished()
                                dismiss()
                            } label: {
                                Label("Mark as Finished", systemImage: "checkmark.circle")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Progress Header

    @ViewBuilder
    private var progressHeader: some View {
        VStack(spacing: 8) {
            if let fraction = displayFraction {
                ProgressView(value: fraction)
                    .tint(.accentColor)
                Text("\(Int(fraction * 100))%")
                    .font(.title2.bold())
            }

            Text(displayLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top)
    }

    // MARK: - Pages Input

    private var pagesInput: some View {
        VStack(spacing: 12) {
            Text("Current Page")
                .font(.subheadline.bold())

            HStack(spacing: 16) {
                Button {
                    currentPage = max(0, currentPage - 10)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                }
                .disabled(currentPage <= 0)

                TextField("Page", value: $currentPage, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)

                Button {
                    let max = totalPages ?? 10000
                    currentPage = min(max, currentPage + 10)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }

            // Quick jump buttons
            if let total = totalPages, total > 0 {
                HStack(spacing: 8) {
                    ForEach([25, 50, 75, 100], id: \.self) { pct in
                        Button("\(pct)%") {
                            currentPage = Int(Double(total) * Double(pct) / 100.0)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Time Input

    private var timeInput: some View {
        VStack(spacing: 12) {
            Text("Time Listened")
                .font(.subheadline.bold())

            HStack(spacing: 4) {
                HStack(spacing: 16) {
                    Button {
                        if hours > 0 { hours -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(hours <= 0)

                    VStack(spacing: 2) {
                        TextField("0", value: $hours, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                        Text("hours")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        hours += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }

                Text(":")
                    .font(.title2)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 14)

                HStack(spacing: 16) {
                    Button {
                        if minutes >= 5 {
                            minutes -= 5
                        } else if hours > 0 {
                            hours -= 1
                            minutes = 55
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(hours == 0 && minutes < 5)

                    VStack(spacing: 2) {
                        TextField("0", value: $minutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                        Text("min")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        if minutes < 55 {
                            minutes += 5
                        } else {
                            minutes = 0
                            hours += 1
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
        }
    }

    // MARK: - Percent Input

    private var percentInput: some View {
        VStack(spacing: 12) {
            Text("Percentage Complete")
                .font(.subheadline.bold())

            HStack(spacing: 16) {
                Button {
                    currentPercent = max(0, currentPercent - 5)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                }
                .disabled(currentPercent <= 0)

                TextField("0", value: $currentPercent, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)

                Button {
                    currentPercent = min(100, currentPercent + 5)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }

            // Quick jump buttons
            HStack(spacing: 8) {
                ForEach([25, 50, 75, 100], id: \.self) { pct in
                    Button("\(pct)%") {
                        currentPercent = Double(pct)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Computed

    private var currentUpdate: ProgressUpdate {
        switch mode {
        case .pages:
            return .pages(currentPage)
        case .time:
            return .seconds(hours * 3600 + minutes * 60)
        case .percent:
            return .percent(currentPercent)
        }
    }

    private var displayFraction: Double? {
        switch mode {
        case .pages:
            guard let total = totalPages, total > 0 else { return nil }
            return Double(currentPage) / Double(total)
        case .time:
            return nil // No total duration known
        case .percent:
            return currentPercent / 100.0
        }
    }

    private var displayLabel: String {
        switch mode {
        case .pages:
            if let total = totalPages {
                return "\(currentPage) of \(total) pages"
            }
            return "Page \(currentPage)"
        case .time:
            return "\(hours)h \(minutes)m listened"
        case .percent:
            return "\(Int(currentPercent))% complete"
        }
    }
}
