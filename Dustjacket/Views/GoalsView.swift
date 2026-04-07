import SwiftUI

struct GoalsView: View {
    @StateObject private var goalManager = GoalManager.shared
    @State private var showCreateSheet = false

    var body: some View {
        Group {
            if goalManager.isLoading && goalManager.goals.isEmpty {
                ProgressView("Loading goals...")
            } else if goalManager.goals.isEmpty {
                VStack(spacing: 20) {
                    ContentUnavailableView(
                        "No Reading Goals",
                        systemImage: "target",
                        description: Text("Set a reading goal to track your progress.")
                    )
                    Button("Create Goal") {
                        showCreateSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    if !goalManager.activeGoals.isEmpty {
                        Section("Active") {
                            ForEach(goalManager.activeGoals) { goal in
                                goalRow(goal)
                            }
                            .onDelete { indexSet in
                                let goalsToDelete = indexSet.map { goalManager.activeGoals[$0] }
                                for goal in goalsToDelete {
                                    Task { await goalManager.deleteGoal(id: goal.id) }
                                }
                            }
                        }
                    }

                    if !goalManager.completedGoals.isEmpty {
                        Section("Completed") {
                            ForEach(goalManager.completedGoals) { goal in
                                goalRow(goal)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            GoalEditorSheet { metric, target, startDate, endDate, description in
                Task {
                    await goalManager.createGoal(
                        metric: metric, target: target,
                        startDate: startDate, endDate: endDate,
                        description: description
                    )
                }
            }
        }
        .task {
            await goalManager.fetchGoals()
        }
        .refreshable {
            await goalManager.fetchGoals()
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        HStack(spacing: 12) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: goal.progressPercent)
                    .stroke(goal.isCompleted ? .green : .accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(goal.progressPercent * 100))%")
                    .font(.caption2.bold())
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.description ?? "Reading Goal")
                    .font(.subheadline.bold())
                    .lineLimit(1)

                Text("\(Int(goal.progress ?? 0)) / \(goal.target) \(goal.metricLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let start = goal.startDate, let end = goal.endDate {
                    Text("\(start) → \(end)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Goal Editor Sheet

struct GoalEditorSheet: View {
    var onCreate: (String, Int, String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var metric = "books"
    @State private var target = 12
    @State private var description = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("What") {
                    Picker("Metric", selection: $metric) {
                        Text("Books").tag("books")
                        Text("Pages").tag("pages")
                    }

                    Stepper("Target: \(target)", value: $target, in: 1...1000)

                    TextField("Description (optional)", text: $description)
                }

                Section("When") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let desc = description.isEmpty ? "Read \(target) \(metric)" : description
                        onCreate(
                            metric, target,
                            dateFormatter.string(from: startDate),
                            dateFormatter.string(from: endDate),
                            desc
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}
