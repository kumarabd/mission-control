import SwiftUI
import Charts

/// The engine chooses modules; this client owns their presentation and supported actions.
struct GoalDetail: View {
    @Environment(Life.self) private var life
    @Environment(ChatModel.self) private var chat
    let goalID: String
    @State private var tracker: Wire.TrackerState?
    @State private var loading = true
    @State private var failure: String?
    @State private var edit: MeasurementSelection?
    @State private var proposal: Wire.TrackerProposal?
    @State private var expanded = false
    @State private var busy = false
    @State private var keys: [String: String] = [:]
    private var catalog: String { TrackerClient.catalog(isPad: UIDevice.current.userInterfaceIdiom == .pad) }
    private var goal: Wire.Goal? { life.goals.first { $0.id == goalID } }

    var body: some View {
        Group {
            if let goal {
                if loading && tracker == nil {
                    ProgressView("Loading tracker…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let tracker, let view = tracker.supportedView(catalog: catalog) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.l) {
                            if !goal.why.isEmpty { Text(goal.why).font(.mission(.body)).foregroundStyle(Tok.muted) }
                            feedback
                            proposalButtons(tracker)
                            LazyVGrid(columns: columns, alignment: .leading, spacing: Space.m) {
                                ForEach(Array(view.sections.prefix(expanded ? 8 : 4))) { section in
                                    TrackerModuleCard(section: section, tracker: tracker, goal: goal, interactive: !busy,
                                        onCheckIn: { metric, measurement in edit = MeasurementSelection(metric: metric, measurement: measurement) },
                                        onStep: { step in Task { await complete(step) } })
                                }
                            }
                            if view.sections.count > 4 {
                                Button(expanded ? "Show less" : "More in this tracker") { expanded.toggle() }
                                    .font(.mission(.body)).frame(minHeight: 44)
                            }
                            Button { ask(goal) } label: { Label("Adjust tracker", systemImage: "bubble.left") }
                                .frame(minHeight: 44)
                        }.padding(Space.m).frame(maxWidth: 1000).frame(maxWidth: .infinity)
                    }
                    .refreshable { await refresh() }
                    .navigationTitle(goal.title).navigationBarTitleDisplayMode(.inline)
                } else {
                    VStack(spacing: 0) {
                        feedback.padding(.horizontal, Space.m)
                        if let tracker { proposalButtons(tracker).padding(.horizontal, Space.m) }
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
                MeasurementSheet(goalID: goalID, revision: tracker.trackerRevision, metric: selection.metric, measurement: selection.measurement)
                    .environment(life)
            }
        }
        .sheet(item: $proposal) { proposed in
            TrackerProposalSheet(proposal: proposed, current: tracker, goal: goal, catalog: catalog,
                accept: { await review(proposed, accept: true) }, discard: { await review(proposed, accept: false) },
                ask: {
                    proposal = nil
                    chat.request(draft: "Revise tracker proposal \(proposed.id) for goal \(goalID). Preserve recorded metrics and other client presentations. My changes: ")
                }).environment(life)
        }
    }
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var columns: [GridItem] {
        // Large text stays in a single readable column, even on iPad.
        UIDevice.current.userInterfaceIdiom == .pad && sizeClass == .regular && !dynamicType.isAccessibilitySize
            ? [GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible())]
    }
    @Environment(\.dynamicTypeSize) private var dynamicType
    @ViewBuilder private var feedback: some View {
        if let failure {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(failure).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                Button("Try again") { Task { await refresh() } }.frame(minHeight: 44)
            }
        }
    }
    @ViewBuilder private func proposalButtons(_ state: Wire.TrackerState) -> some View {
        ForEach(state.proposals) { pending in
            Button { proposal = pending } label: {
                Label("Review proposed tracker", systemImage: "rectangle.stack")
                    .font(.mission(.body)).frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 44)
            }
        }
    }
    private func ask(_ goal: Wire.Goal) {
        chat.request(draft: "Compose a tailored tracker for goal \(goal.id), “\(goal.title)”. Read this client's tracker catalog and the existing goal first. Propose the change for my review, preserve existing measurements and other client views. ")
    }
    private func refresh() async {
        defer { loading = false }
        do {
            let state = try await life.loadTracker(goalID: goalID, catalog: catalog)
            guard !Task.isCancelled, state.goalId == goalID else { return }
            tracker = state; failure = nil
        } catch {
            guard !Task.isCancelled else { return }
            // An older server remains usable, without pretending to have a generated tracker.
            if case LifeError.engine(let code, _) = error, code == "not_found" || code == "unknown" { failure = nil }
            else { failure = Life.trackerMessage(error) }
        }
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
    private func review(_ proposed: Wire.TrackerProposal, accept: Bool) async -> String? {
        do {
            try await life.reviewTracker(proposed, accept: accept, key: key("proposal:\(proposed.id):\(proposed.version):\(accept)"))
            proposal = nil; await refresh(); return nil
        } catch {
            await refresh()
            if let tracker, !tracker.proposals.contains(where: { $0.id == proposed.id }) { proposal = nil }
            return Life.trackerMessage(error)
        }
    }
    private func refreshPreservingFailure() async {
        let previous = failure; await refresh(); if let previous { failure = previous }
    }
}

private struct MeasurementSelection: Identifiable {
    var metric: Wire.TrackerMetric; var measurement: Wire.GoalMeasurement?
    var id: String { measurement?.id ?? metric.id }
}

private struct TrackerModuleCard: View {
    @Environment(Life.self) private var life
    let section: Wire.TrackerSection
    let tracker: Wire.TrackerState
    let goal: Wire.Goal
    var interactive: Bool
    var onCheckIn: (Wire.TrackerMetric, Wire.GoalMeasurement?) -> Void
    var onStep: (Wire.Step) -> Void
    @State private var showHistory = false
    @State private var routineFailure: String?
    private var metric: Wire.TrackerMetric? { tracker.metricDefinitions.first { $0.id == section.metricId } }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(section.title).font(.mission(.headline, .medium)).accessibilityAddTraits(.isHeader)
            switch section.type {
            case "metric_trend": if let metric { trend(metric) }
            case "check_in": if let metric { checkIn(metric) }
            case "milestones": milestones
            case "routine_consistency": routines
            default: Text("Update the app to show this section.").font(.mission(.body))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(Space.m)
        .background(Tok.surface, in: MissionTheme.cardShape)
        .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
    }
    @ViewBuilder private func trend(_ metric: Wire.TrackerMetric) -> some View {
        let observations = tracker.observations(for: metric.id)
        if let latest = observations.last {
            Text("\(latest.value.formatted()) \(metric.unit)").font(.mission(.title2, .medium))
            Text(latest.measuredAt.formatted(date: .abbreviated, time: .shortened)).font(.mission(.caption)).foregroundStyle(Tok.muted)
            Chart {
                ForEach(observations) { observation in
                    LineMark(x: .value("Date", observation.measuredAt), y: .value(metric.label, observation.value)).foregroundStyle(Tok.accent)
                    PointMark(x: .value("Date", observation.measuredAt), y: .value(metric.label, observation.value)).foregroundStyle(Tok.accent)
                }
                if let target = metric.target { RuleMark(y: .value("Target", target)).foregroundStyle(Tok.muted).lineStyle(StrokeStyle(lineWidth: 1, dash: [4])) }
            }
            .frame(height: 160)
            .accessibilityLabel("\(metric.label), latest \(latest.value.formatted()) \(metric.unit). \(observations.count) recorded observations.")
        } else {
            Text("No observations yet").font(.mission(.body))
            Text("Your recorded \(metric.label.lowercased()) will appear here.").font(.mission(.subheadline)).foregroundStyle(Tok.muted)
        }
        if let target = metric.target { Text("Target: \(target.formatted()) \(metric.unit)").font(.mission(.subheadline)).foregroundStyle(Tok.muted) }
    }
    @ViewBuilder private func checkIn(_ metric: Wire.TrackerMetric) -> some View {
        Button { onCheckIn(metric, nil) } label: { Label("Record \(metric.label.lowercased())", systemImage: "square.and.pencil") }
            .font(.mission(.body)).frame(minHeight: 44).disabled(!interactive)
        let observations = tracker.observations(for: metric.id)
        if !observations.isEmpty {
            DisclosureGroup("Recent observations", isExpanded: $showHistory) {
                Text("Most recent 120 observations").font(.mission(.caption)).foregroundStyle(Tok.muted)
                ForEach(Array(observations.reversed())) { observation in
                    Button { onCheckIn(metric, observation) } label: {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("\(observation.value.formatted()) \(observation.unit)").font(.mission(.body))
                            Text(observation.measuredAt.formatted(date: .abbreviated, time: .shortened)).font(.mission(.caption)).foregroundStyle(Tok.muted)
                            if !observation.notes.isEmpty { Text(observation.notes).font(.mission(.caption)).foregroundStyle(Tok.muted) }
                        }.frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 44)
                    }.disabled(!interactive).accessibilityHint("Edit or remove this observation")
                }
            }.font(.mission(.subheadline))
        }
    }
    @ViewBuilder private var milestones: some View {
        if goal.steps.isEmpty { Text("No milestones yet").font(.mission(.body)).foregroundStyle(Tok.muted) }
        ForEach(goal.steps) { step in
            Button { onStep(step) } label: {
                HStack(alignment: .top, spacing: Space.s) {
                    Image(systemName: step.doneAt == nil ? "circle" : "checkmark.circle.fill").foregroundStyle(Tok.accent)
                    Text(step.title).font(.mission(.body)).foregroundStyle(step.doneAt == nil ? Tok.text : Tok.muted)
                    Spacer(minLength: 0)
                }.frame(minHeight: 44)
            }.disabled(!interactive || step.doneAt != nil)
                .accessibilityLabel("\(step.title), \(step.doneAt == nil ? "mark done" : "done")")
        }
    }
    @ViewBuilder private var routines: some View {
        let linked = life.routines.filter { (goal.routineIds ?? []).contains($0.id) }
        if linked.isEmpty { Text("No linked routines yet").font(.mission(.body)).foregroundStyle(Tok.muted) }
        if let consistency = goal.consistency, consistency.last30.scheduled > 0 {
            MissionProgressBar(fraction: Double(consistency.last30.done) / Double(consistency.last30.scheduled), label: "\(consistency.last30.done) of \(consistency.last30.scheduled) routine days kept")
        }
        ForEach(linked) { routine in
            NavigationLink { RoutineDetailView(id: routine.id) } label: {
                Text(routine.routine.title).font(.mission(.body)).frame(minHeight: 44)
            }.disabled(!interactive)
            Button { Task { await life.logRoutine(routine.id); routineFailure = life.error } } label: { Label("Record \(routine.routine.title)", systemImage: "checkmark") }
                .font(.mission(.subheadline)).frame(minHeight: 44).disabled(!interactive || routine.done || life.busyRoutines.contains(routine.id))
        }
        if let routineFailure { Text(routineFailure).font(.mission(.subheadline)).foregroundStyle(Tok.critical) }
        Text("Supporting habits, not a measure of the outcome.").font(.mission(.caption)).foregroundStyle(Tok.muted)
    }
}

private struct TrackerProposalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let proposal: Wire.TrackerProposal
    let current: Wire.TrackerState?
    let goal: Wire.Goal?
    let catalog: String
    var accept: () async -> String?
    var discard: () async -> String?
    var ask: () -> Void
    @State private var busy = false
    @State private var failure: String?
    private var proposedView: Wire.TrackerView? { proposal.definition.views.first { $0.isSupported(catalog: catalog, metrics: proposal.definition.metrics ?? []) } }
    private var stale: Bool { current.map { $0.goalVersion != proposal.baseGoalVersion || $0.trackerRevision != proposal.baseTrackerRevision } ?? true }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.m) {
                    Text(proposal.reason).font(.mission(.body))
                    if stale { Text("The goal changed since this proposal. Ask for an updated proposal.").font(.mission(.body)).foregroundStyle(Tok.muted) }
                    if let view = proposedView, let goal {
                        let preview = Wire.TrackerState(goalId: goal.id, goalVersion: goal.version, trackerRevision: current?.trackerRevision ?? 0, catalogId: catalog, view: view, metrics: proposal.definition.metrics, measurements: current?.measurements ?? [], proposals: [])
                        ForEach(view.sections) { section in
                            TrackerModuleCard(section: section, tracker: preview, goal: goal, interactive: false, onCheckIn: { _, _ in }, onStep: { _ in })
                        }
                        ForEach(proposal.definition.metrics ?? []) { metric in
                            Text("\(metric.label) · \(metric.unit)\(metric.target.map { " · Target \($0.formatted())" } ?? "")").font(.mission(.subheadline))
                        }
                    } else { Text("This proposal needs a supported tracker for this device.").font(.mission(.body)) }
                    if let failure { Text(failure).font(.mission(.body)).foregroundStyle(Tok.muted) }
                    Button("Use this tracker") { run(accept) }.buttonStyle(.borderedProminent).disabled(busy || stale || proposedView == nil)
                    Button("Ask for changes", action: ask).disabled(busy).frame(minHeight: 44)
                    Button("Decline proposal", role: .destructive) { run(discard) }.disabled(busy).frame(minHeight: 44)
                }.padding(Space.m)
            }.screenBackground().navigationTitle("Proposed tracker").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(busy) } }
                .interactiveDismissDisabled(busy)
        }
    }
    private func run(_ action: @escaping () async -> String?) {
        busy = true
        Task { failure = await action(); busy = false }
    }
}

private struct MeasurementSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    let goalID: String
    let revision: Int
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
                expectedTrackerRevision: measurement == nil ? revision : nil, id: measurement?.id, expectedVersion: measurement?.version,
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
