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
    @State private var page = ""
    @Environment(\.dismiss) private var dismiss
    /// This goal's own conversation; made the first time it is opened or asked into.
    @State private var goalChat: ChatModel?
    @State private var chatOpen = false
    @State private var confirmDelete = false
    @State private var deleting = false
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
                            if view.pages.count > 1 {
                                Picker("Page", selection: Binding(get: { view.pages.contains { $0.id == page } ? page : view.pages[0].id }, set: { page = $0 })) {
                                    ForEach(view.pages) { Text($0.title ?? "").tag($0.id) }
                                }.pickerStyle(.segmented)
                            }
                            if let current = view.pages.first(where: { $0.id == page }) ?? view.pages.first {
                                VStack(alignment: .leading, spacing: Space.l) {
                                    ForEach(current.sections) { section in
                                        VStack(alignment: .leading, spacing: Space.m) {
                                            VStack(alignment: .leading, spacing: Space.xs) {
                                                Text(section.title).font(.mission(.title3, .semibold)).accessibilityAddTraits(.isHeader)
                                                if let intro = section.intro, !intro.isEmpty {
                                                    Text(intro).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                                                }
                                            }.padding(.horizontal, Space.xs)
                                            ForEach(Array(section.blocks.enumerated()), id: \.element.id) { index, block in
                                                KitBlockView(block: block, view: view, loads: loads, data: kitData, tracker: tracker, goal: goal,
                                                             interactive: !busy, index: index, actions: kitActions)
                                            }
                                        }
                                    }
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
        .toolbar {
            if let goal {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Chat about this goal", systemImage: "bubble.left") { openChat(goal) }.frame(minWidth: 44, minHeight: 44)
                    Menu {
                        Button("Delete goal\u{2026}", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
                        .accessibilityLabel("More")
                }
            }
        }
        .confirmationDialog("Delete this goal?", isPresented: $confirmDelete, titleVisibility: .visible) {
            if let goal { Button("Delete goal and everything for it", role: .destructive) { Task { await delete(goal) } } }
        } message: {
            Text("Its steps, view, measurements, reminders and routines made for it, the notes and journal entries about it, and this goal\u{2019}s chat are deleted. Routines shared with another goal stay.")
        }
        .sheet(isPresented: $chatOpen) {
            if let goal, let goalChat {
                GoalChatView(goal: goal, model: goalChat, onDone: { chatOpen = false }).environment(life)
            }
        }
        .onChange(of: goalChat?.completedTurns) { _, _ in Task { await refresh() } }
        .overlay { if deleting { ProgressView("Deleting\u{2026}").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
        .sheet(item: $edit, onDismiss: { Task { await refresh() } }) { selection in
            if let tracker {
                MeasurementSheet(goalID: goalID, metric: selection.metric, measurement: selection.measurement)
                    .environment(life)
            }
        }
    }
    private var kitActions: KitActions {
        KitActions(
            checkIn: { metric, measurement in edit = MeasurementSelection(metric: metric, measurement: measurement) },
            step: { step in Task { await complete(step) } },
            retry: { Task { await refresh() } },
            logDay: { metric, day, delta in Task { await logDay(metric, day, delta) } },
            record: { metric, value in await record(metric, value) })
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
    private func chatModel(for goal: Wire.Goal) -> ChatModel {
        if let goalChat { return goalChat }
        let model = ChatModel(sessionID: "goal-" + goal.id.lowercased())
        goalChat = model
        return model
    }
    private func openChat(_ goal: Wire.Goal, draft: String? = nil) {
        let model = chatModel(for: goal)
        if let draft { model.request(draft: draft) }
        chatOpen = true
    }
    /// Removes the goal with what is only for it, then erases its conversation. The goal is deleted first: if the chat's
    /// erasing then fails the person is told so, and the goal is not left half there.
    private func delete(_ goal: Wire.Goal) async {
        deleting = true; defer { deleting = false }
        let model = chatModel(for: goal)
        do { try await life.deleteGoalWithRelated(goal) } catch { failure = Life.trackerMessage(error); return }
        model.deleteSession()
        for _ in 0..<40 where !model.deleted { try? await Task.sleep(for: .milliseconds(200)) }
        guard model.deleted else {
            failure = "The goal is deleted, but its conversation could not be erased just now."
            return
        }
        dismiss()
    }
    private func ask(_ goal: Wire.Goal) {
        openChat(goal, draft: "Compose a view for my goal \(goal.id), “\(goal.title)”. Read the view kit (tracker_catalog_get) and the goal first, design what suits this goal, then save it with views_create (or views_update if it has one). ")
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
    /// Records (or takes back) one on a day for a routine-backed metric. The day changes at once; the engine's answer follows.
    private func logDay(_ metric: Wire.TrackerMetric, _ day: Date, _ delta: Int) async {
        guard let routine = metric.routineId, !busy else { return }
        if case .ready(var points)? = loads[metric.id] {
            let cal = Calendar.current, start = cal.startOfDay(for: day)
            if let i = points.firstIndex(where: { cal.startOfDay(for: $0.date) == start }) {
                points[i].value += Double(delta)
                if points[i].value <= 0 { points.remove(at: i) }
            } else if delta > 0 { points.append(ViewKit.Point(date: day, value: Double(delta))) }
            loads[metric.id] = .ready(points)
        }
        let f = DateFormatter()
        f.calendar = .current; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        await life.logRoutine(routine, delta: delta, day: f.string(from: day))
        loads[metric.id] = await fetch(metric)
        if let message = life.error { failure = message }
    }
    /// Saves one number a person typed into a log block; returns a message when it could not.
    private func record(_ metric: Wire.TrackerMetric, _ value: Double) async -> String? {
        do {
            try await life.saveMeasurement(GoalsService.MeasurementIn(idempotencyKey: UUID().uuidString, goalId: goalID, metricId: metric.id, id: nil,
                                                                      expectedVersion: nil, value: value, measuredAt: nil, notes: ""))
            await refresh()
            return nil
        } catch { return Life.trackerMessage(error) }
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
