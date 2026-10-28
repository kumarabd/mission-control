import SwiftUI
import Charts

private let kitMaxAutoAttempts = 2

/// What a view is of: a goal, a task or an event. A view is its own construct, tied to any of them.
struct ViewSubject: Hashable {
    var kind: String        // goal | task | event
    var id: String
}

/// The assistant composes a subject's view from the view kit; this client draws it and owns its supported actions. What it
/// draws is the same manifest on every client: only the components differ.
struct KitScreen<Fallback: View>: View {
    @Environment(Life.self) private var life
    @Environment(ChatModel.self) private var chat
    let subject: ViewSubject
    let title: String
    let notes: String
    /// What shows while the subject has no view: its plain review.
    @ViewBuilder var fallback: () -> Fallback
    private var goalID: String { subject.id }
    @State private var tracker: Wire.ViewState?
    @State private var loading = true
    @State private var failure: String?
    @State private var edit: MeasurementSelection?
    @State private var loads: [String: KitLoad] = [:]
    @State private var busy = false
    @State private var page = ""
    /// How many times the app has asked the assistant to compose this goal's view, and the chat's finished-turn count when
    /// it last did (the request is still being worked on until a turn finishes).
    @State private var composeAttempts = 0
    @State private var composeBase: Int?
    private var catalog: String { TrackerClient.catalog }
    private var known: Bool {
        switch subject.kind {
        case "goal": life.goals.contains { $0.id == subject.id }
        default: life.item(subject.id) != nil
        }
    }

    var body: some View {
        Group {
            if known {
                if loading && tracker == nil {
                    ProgressView("Loading tracker…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let tracker, let view = tracker.view(catalog: catalog) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.l) {
                            if !notes.isEmpty {
                                HStack(alignment: .top, spacing: Space.m) {
                                    MissionIconBadge(symbol: "flag.fill", padding: 10)
                                    Text(notes).font(.mission(.body)).foregroundStyle(Tok.muted)
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
                                                KitBlockView(block: block, view: view, loads: loads, data: kitData, tracker: tracker, subject: subject,
                                                             interactive: !busy, index: index, actions: kitActions)
                                            }
                                        }
                                    }
                                }
                            }
                            Button { ask() } label: { Label("Change this view", systemImage: "bubble.left") }
                                .buttonStyle(MissionPressStyle()).frame(minHeight: 44)
                        }.padding(Space.m).frame(maxWidth: 1000).frame(maxWidth: .infinity)
                    }
                    .refreshable { await refresh() }
                    .navigationTitle(title).inlineNavigationTitle()
                } else {
                    VStack(spacing: 0) {
                        feedback.padding(.horizontal, Space.m)
                        if composing {
                            HStack(spacing: Space.s) {
                                ProgressView()
                                Text("Building this view\u{2026} the assistant is composing it.").font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                            }
                            .padding(Space.m).frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                        } else if failure == nil {
                            Button { composeAttempts = 0; ask() } label: { Label("Build a view", systemImage: "chart.xyaxis.line") }
                                .font(.mission(.body)).frame(minHeight: 44)
                        }
                        fallback()
                    }
                }
            } else { ContentUnavailableView("This is gone", systemImage: "flag") }
        }
        .screenBackground()
        .navigationTitle(title).inlineNavigationTitle()
        .task(id: subject) { loadComposeState(); await refresh() }
        // A goal with no view gets one composed as soon as the assistant is free; when its turn ends, the view is read.
        .onChange(of: chat.transcript.isRunning) { _, running in if !running { composeIfNeeded() } }
        .onChange(of: chat.completedTurns) { _, _ in Task { await refresh() } }
        .sheet(item: $edit, onDismiss: { Task { await refresh() } }) { selection in
            if tracker != nil {
                MeasurementSheet(subject: subject, metric: selection.metric, measurement: selection.measurement)
                    .environment(life)
            }
        }
    }
    private var kitActions: KitActions {
        KitActions(
            checkIn: { metric, measurement in edit = MeasurementSelection(metric: metric, measurement: measurement) },
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
    private func ask() {
        chat.request(draft: composePrompt)
    }
    private var composePrompt: String {
        "Compose a view for my \(subject.kind) \(subject.id), “\(title)”. Read the view kit (tracker_catalog_get) and the \(subject.kind) first, design what suits it, then save it with views_create (or views_update if it has one). "
    }

    // MARK: Composing the view

    /// The app asks for a view this many times before it leaves the rest to the person's own button.
    private var composing: Bool { composeBase == chat.completedTurns }
    private func composeKey(_ name: String) -> String { "view.\(name).\(subject.kind).\(subject.id)" }

    private func loadComposeState() {
        composeAttempts = UserDefaults.standard.integer(forKey: composeKey("attempts"))
    }

    /// Asks the assistant to compose this goal's view, once the goal is known to have none, nothing else the assistant is
    /// doing would be interrupted (a message sent mid-reply interrupts it), and it has not been tried too often.
    private func composeIfNeeded() {
        guard known, failure == nil, tracker != nil, tracker?.view(catalog: catalog) == nil, !composing,
              composeAttempts < kitMaxAutoAttempts, !chat.transcript.isRunning, chat.question == nil else { return }
        composeBase = chat.completedTurns
        composeAttempts += 1
        UserDefaults.standard.set(composeAttempts, forKey: composeKey("attempts"))
        chat.send(composePrompt)
    }
    private func refresh() async {
        defer { loading = false }
        do {
            let state = try await life.loadView(kind: subject.kind, id: subject.id, catalog: catalog)
            guard !Task.isCancelled, state.subjectId == subject.id else { return }
            tracker = state; failure = nil
            if let view = state.view(catalog: catalog) {
                composeBase = nil; composeAttempts = 0
                UserDefaults.standard.removeObject(forKey: composeKey("attempts"))
                await loadKit(view, state)
            } else { composeIfNeeded() }
        } catch {
            guard !Task.isCancelled else { return }
            // An older server remains usable, without pretending to have a generated tracker.
            if case LifeError.engine(let code, _) = error, code == "not_found" || code == "unknown" { failure = nil }
            else { failure = Life.trackerMessage(error) }
        }
    }
    /// Reads each metric's data: the numbers the person logs come with the view; a provider's series and a task's done days
    /// are read live. A metric that cannot be read says why, and only the blocks that use it show that.
    private func loadKit(_ view: Wire.SubjectView, _ state: Wire.ViewState) async {
        var next: [String: KitLoad] = [:]
        for metric in view.metrics {
            if metric.source != nil || metric.taskId != nil { next[metric.id] = loads[metric.id] ?? .loading }
            else { next[metric.id] = .ready(state.observations(for: metric.id).map { ViewKit.Point(date: $0.measuredAt, value: $0.value) }) }
        }
        loads = next
        for metric in view.metrics where metric.source != nil || metric.taskId != nil {
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
        if let task = metric.taskId {
            guard let history = await life.taskHistory(task, days: 90) else { return .failed(life.error ?? "Couldn't read this task.") }
            return .ready(history.days.compactMap { d in d.count > 0 ? TrackerClient.day(d.day).map { ViewKit.Point(date: $0, value: Double(d.count)) } : nil })
        }
        return .ready([])
    }
    /// Records (or takes back) one on a day for a task-backed metric. The day changes at once; the engine's answer follows.
    private func logDay(_ metric: Wire.TrackerMetric, _ day: Date, _ delta: Int) async {
        guard let task = metric.taskId, !busy else { return }
        if case .ready(var points)? = loads[metric.id] {
            let cal = Calendar.current, start = cal.startOfDay(for: day)
            if let i = points.firstIndex(where: { cal.startOfDay(for: $0.date) == start }) {
                points[i].value += Double(delta)
                if points[i].value <= 0 { points.remove(at: i) }
            } else if delta > 0 { points.append(ViewKit.Point(date: day, value: Double(delta))) }
            loads[metric.id] = .ready(points)
        }
        await life.logOccurrence(task, on: day, done: delta > 0)
        loads[metric.id] = await fetch(metric)
        if let message = life.error { failure = message }
    }
    /// Saves one number a person typed into a log block; returns a message when it could not.
    private func record(_ metric: Wire.TrackerMetric, _ value: Double) async -> String? {
        do {
            try await life.saveMeasurement(GoalsService.MeasurementIn(idempotencyKey: UUID().uuidString, subjectKind: subject.kind, subjectId: subject.id,
                                                                      metricId: metric.id, id: nil, expectedVersion: nil, value: value, measuredAt: nil, notes: ""))
            await refresh()
            return nil
        } catch { return Life.trackerMessage(error) }
    }
    private func refreshPreservingFailure() async {
        let previous = failure; await refresh(); if let previous { failure = previous }
    }
}

private struct MeasurementSelection: Identifiable {
    var metric: Wire.TrackerMetric; var measurement: Wire.Measurement?
    var id: String { measurement?.id ?? metric.id }
}

private struct MeasurementSheet: View {
    @Environment(Life.self) private var life
    @Environment(\.dismiss) private var dismiss
    let subject: ViewSubject
    let metric: Wire.TrackerMetric
    let measurement: Wire.Measurement?
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
                    TextField("Value in \(metric.unit)", text: $value).numericKeyboard()
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
            .navigationTitle(measurement == nil ? "Check in" : "Edit observation").inlineNavigationTitle()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(busy) } }
            .dismissLocked(busy || pending != nil || deleting)
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
                subjectKind: measurement == nil ? subject.kind : nil, subjectId: measurement == nil ? subject.id : nil, metricId: measurement == nil ? metric.id : nil,
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
