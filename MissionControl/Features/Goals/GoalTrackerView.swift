import SwiftUI
import Charts

/// The assistant composes a goal's view from the view kit; this client draws it and owns its supported actions.
struct GoalDetail: View {
    @Environment(Life.self) private var life
    @Environment(ChatModel.self) private var chat
    let goalID: String
    @State private var tracker: Wire.ViewState?
    @State private var loading = true
    @State private var failure: String?
    @State private var edit: MeasurementSelection?
    @State private var loads: [String: KitLoad] = [:]
    @State private var busy = false
    @State private var keys: [String: String] = [:]
    private var catalog: String { TrackerClient.catalog }
    private var goal: Wire.Goal? { life.goals.first { $0.id == goalID } }

    var body: some View {
        Group {
            if let goal {
                if loading && tracker == nil {
                    ProgressView("Loading tracker…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let tracker, let view = tracker.view(catalog: catalog) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.l) {
                            if !goal.why.isEmpty {
                                HStack(alignment: .top, spacing: Space.m) {
                                    MissionIconBadge(symbol: "flag.fill", padding: 10)
                                    Text(goal.why).font(.mission(.body)).foregroundStyle(Tok.muted)
                                }
                            }
                            feedback
                            VStack(alignment: .leading, spacing: Space.m) {
                                ForEach(view.blocks) { block in
                                    KitBlockView(block: block, view: view, loads: loads, data: kitData, tracker: tracker, goal: goal, interactive: !busy,
                                        onCheckIn: { metric, measurement in edit = MeasurementSelection(metric: metric, measurement: measurement) },
                                        onStep: { step in Task { await complete(step) } },
                                        onRetry: { Task { await refresh() } })
                                }
                            }
                            Button { ask(goal) } label: { Label("Change this view", systemImage: "bubble.left") }
                                .buttonStyle(MissionPressStyle()).frame(minHeight: 44)
                        }.padding(Space.m).frame(maxWidth: 1000).frame(maxWidth: .infinity)
                    }
                    .refreshable { await refresh() }
                    .navigationTitle(goal.title).navigationBarTitleDisplayMode(.inline)
                } else {
                    VStack(spacing: 0) {
                        feedback.padding(.horizontal, Space.m)
                        if failure == nil {
                            Button { ask(goal) } label: { Label("Build a tracker for this goal", systemImage: "chart.xyaxis.line") }
                                .font(.mission(.body)).frame(minHeight: 44)
                        }
                        GoalReview(goalID: goalID)
                    }
                }
            } else { ContentUnavailableView("This goal is gone", systemImage: "flag") }
        }
        .screenBackground()
        .navigationTitle(goal?.title ?? "Goal").navigationBarTitleDisplayMode(.inline)
        .task(id: goal?.version) { await refresh() }
        .sheet(item: $edit, onDismiss: { Task { await refresh() } }) { selection in
            if let tracker {
                MeasurementSheet(goalID: goalID, metric: selection.metric, measurement: selection.measurement)
                    .environment(life)
            }
        }
    }
    /// What the view's calculations read: every metric whose data has arrived.
    private var kitData: ViewKit.Data {
        var series: [String: [ViewKit.Point]] = [:]
        for (id, load) in loads { if case .ready(let points) = load { series[id] = points } }
        return ViewKit.Data(series: series)
    }
    @ViewBuilder private var feedback: some View {
        if let failure {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(failure).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                Button("Try again") { Task { await refresh() } }.frame(minHeight: 44)
            }
        }
    }
    private func ask(_ goal: Wire.Goal) {
        chat.request(draft: "Compose a view for my goal \(goal.id), “\(goal.title)”. Read the view kit (tracker_catalog_get) and the goal first, design what suits this goal, then save it with views_create (or views_update if it has one). ")
    }
    private func refresh() async {
        defer { loading = false }
        do {
            let state = try await life.loadView(goalID: goalID, catalog: catalog)
            guard !Task.isCancelled, state.goalId == goalID else { return }
            tracker = state; failure = nil
            if let view = state.view(catalog: catalog) { await loadKit(view, state) }
        } catch {
            guard !Task.isCancelled else { return }
            // An older server remains usable, without pretending to have a generated tracker.
            if case LifeError.engine(let code, _) = error, code == "not_found" || code == "unknown" { failure = nil }
            else { failure = Life.trackerMessage(error) }
        }
    }
    /// Reads each metric's data: the numbers the person logs come with the view; a provider's series and a routine's logs
    /// are read live. A metric that cannot be read says why, and only the blocks that use it show that.
    private func loadKit(_ view: Wire.GoalView, _ state: Wire.ViewState) async {
        var next: [String: KitLoad] = [:]
        for metric in view.metrics {
            if metric.source != nil || metric.routineId != nil { next[metric.id] = loads[metric.id] ?? .loading }
            else { next[metric.id] = .ready(state.observations(for: metric.id).map { ViewKit.Point(date: $0.measuredAt, value: $0.value) }) }
        }
        loads = next
        for metric in view.metrics where metric.source != nil || metric.routineId != nil {
            let load = await fetch(metric)
            guard !Task.isCancelled else { return }
            loads[metric.id] = load
        }
    }
    private func fetch(_ metric: Wire.TrackerMetric) async -> KitLoad {
        if let source = metric.source {
            do {
                let data = try await life.loadSeries(provider: source.provider, series: source.series, granularity: source.granularity ?? "day")
                return .ready(data.points.compactMap { p in TrackerClient.day(p.t).map { ViewKit.Point(date: $0, value: p.value) } })
            } catch {
                if case LifeError.engine(let code, _) = error, code == "not_found" { return .failed("This data source no longer exists.") }
                return .failed(Life.trackerMessage(error))
            }
        }
        if let routine = metric.routineId {
            guard let history = await life.history(for: routine, days: 120) else { return .failed(life.error ?? "Couldn't read this routine.") }
            return .ready(history.days.compactMap { d in d.count > 0 ? TrackerClient.day(d.day).map { ViewKit.Point(date: $0, value: Double(d.count)) } : nil })
        }
        return .ready([])
    }
    private func key(_ intent: String) -> String {
        if let key = keys[intent] { return key }
        let key = UUID().uuidString; keys[intent] = key; return key
    }
    private func complete(_ step: Wire.Step) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { try await life.completeTrackerStep(step, key: key("step:\(step.id):\(step.version)")); failure = nil }
        catch { failure = Life.trackerMessage(error) }
        await refreshPreservingFailure()
    }
    private func refreshPreservingFailure() async {
        let previous = failure; await refresh(); if let previous { failure = previous }
    }
}

private struct MeasurementSelection: Identifiable {
    var metric: Wire.TrackerMetric; var measurement: Wire.GoalMeasurement?
    var id: String { measurement?.id ?? metric.id }
}

private struct MeasurementSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    let goalID: String
    let metric: Wire.TrackerMetric
    let measurement: Wire.GoalMeasurement?
    @State private var value = ""
    @State private var at = Date()
    @State private var notes = ""
    @State private var busy = false
    @State private var failure: String?
    @State private var pending: GoalsService.MeasurementIn?
    @State private var deleteKey = UUID().uuidString
    @State private var deleting = false
    @State private var confirmDelete = false
    private var number: Double? { TrackerClient.number(value) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Value in \(metric.unit)", text: $value).keyboardType(.numbersAndPunctuation)
                        .accessibilityLabel("\(metric.label), in \(metric.unit)")
                    DatePicker("Observed", selection: $at, in: ...Date())
                    TextField("Notes (optional)", text: $notes, axis: .vertical).lineLimit(2...5)
                } header: { Text(metric.label) }
                footer: {
                    Text("\(metric.unit)\(metric.minimum.map { " · Minimum \($0.formatted())" } ?? "")\(metric.maximum.map { " · Maximum \($0.formatted())" } ?? "")")
                }.disabled(busy || pending != nil || deleting)
                if let failure { Section { Text(failure).font(.mission(.body)) } }
                Section {
                    Button(pending == nil ? "Save observation" : "Retry save") { save() }
                        .disabled(busy || deleting || (pending == nil && (number.map { !metric.accepts($0) } ?? true)) || notes.count > 1000)
                    if measurement != nil {
                        Button(deleting ? "Retry removal" : "Remove observation", role: .destructive) {
                            if deleting { remove() } else { confirmDelete = true }
                        }.disabled(busy || pending != nil)
                    }
                }
            }
            .navigationTitle(measurement == nil ? "Check in" : "Edit observation").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(busy) } }
            .interactiveDismissDisabled(busy || pending != nil || deleting)
            .confirmationDialog("Remove this observation?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Remove observation", role: .destructive) { remove() }
            }
            .onAppear {
                if let measurement { value = measurement.value.formatted(.number.precision(.significantDigits(1...17)).grouping(.never)); at = measurement.measuredAt; notes = measurement.notes }
            }
        }
    }
    private func save() {
        guard !busy else { return }
        if pending == nil {
            guard let number, metric.accepts(number) else { return }
            pending = GoalsService.MeasurementIn(idempotencyKey: UUID().uuidString,
                goalId: measurement == nil ? goalID : nil, metricId: measurement == nil ? metric.id : nil,
                id: measurement?.id, expectedVersion: measurement?.version,
                value: number, measuredAt: measurement?.measuredAt == at ? nil : at, notes: notes)
        }
        guard let input = pending else { return }; busy = true
        Task {
            defer { busy = false }
            do { try await life.saveMeasurement(input); dismiss() }
            catch {
                failure = Life.trackerMessage(error)
                // Keep exactly the same request after an uncertain response; editing it would risk a duplicate.
                switch error as? LifeError {
                case .retry, .server: break
                default: pending = nil
                }
            }
        }
    }
    private func remove() {
        guard let measurement, !busy else { return }; busy = true; deleting = true
        Task {
            defer { busy = false }
            do { try await life.deleteMeasurement(measurement, key: deleteKey); dismiss() }
            catch { failure = Life.trackerMessage(error); switch error as? LifeError { case .retry, .server: break; default: deleting = false } }
        }
    }
}
