import SwiftUI
import Charts

/// The engine chooses modules; this client owns their presentation and supported actions.
struct GoalDetail: View {
    @Environment(Life.self) private var life
    @Environment(ChatModel.self) private var chat
    let goalID: String
    @State private var tracker: Wire.ViewState?
    @State private var loading = true
    @State private var failure: String?
    @State private var edit: MeasurementSelection?
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
                            LazyVGrid(columns: columns, alignment: .leading, spacing: Space.m) {
                                ForEach(Array(view.blocks.prefix(expanded ? 8 : 4).enumerated()), id: \.element.id) { index, block in
                                    TrackerModuleCard(block: block, view: view, tracker: tracker, goal: goal, interactive: !busy, index: index,
                                        onCheckIn: { metric, measurement in edit = MeasurementSelection(metric: metric, measurement: measurement) },
                                        onStep: { step in Task { await complete(step) } })
                                }
                            }
                            if view.blocks.count > 4 {
                                Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { expanded.toggle() } } label: {
                                    Label(expanded ? "Show less" : "More in this tracker", systemImage: expanded ? "chevron.up" : "chevron.down")
                                        .contentTransition(.symbolEffect(.replace))
                                }
                                .buttonStyle(MissionPressStyle()).font(.mission(.body)).frame(minHeight: 44)
                            }
                            Button { ask(goal) } label: { Label("Adjust tracker", systemImage: "bubble.left") }
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
    private func ask(_ goal: Wire.Goal) {
        chat.request(draft: "Add a tracker view to my goal \(goal.id), “\(goal.title)”. Read the tracker catalog and the goal first, then create the view with views_create. ")
    }
    private func refresh() async {
        defer { loading = false }
        do {
            let state = try await life.loadView(goalID: goalID, catalog: catalog)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let block: Wire.ViewBlock
    let view: Wire.GoalView
    let tracker: Wire.ViewState
    let goal: Wire.Goal
    var interactive: Bool
    var index = 0
    var onCheckIn: (Wire.TrackerMetric, Wire.GoalMeasurement?) -> Void
    var onStep: (Wire.Step) -> Void
    @State private var showHistory = false
    @State private var routineFailure: String?
    @State private var appeared = false
    @State private var reveal: CGFloat = 0
    @State private var series: SeriesLoad = .loading
    @State private var seriesAttempt = 0
    private var metric: Wire.TrackerMetric? { view.metrics.first { $0.id == block.metricId } }

    /// What a trend draws: a recorded observation, or one point of a provider's series.
    private struct Reading: Identifiable { var id: String; var at: Date; var value: Double }
    private enum SeriesLoad { case loading, failed(String, gone: Bool), loaded([Reading]) }

    private var symbol: String {
        switch block.type {
        case "metric_trend": "chart.line.uptrend.xyaxis"
        case "check_in": "gauge.with.dots.needle.50percent"
        case "milestones": "flag.checkered"
        case "routine_consistency": "repeat"
        case "link": "arrow.up.right.square"
        default: "square.grid.2x2"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                MissionIconBadge(symbol: symbol, padding: 8)
                Text(block.title).font(.mission(.headline, .medium)).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
            }
            if !view.supports(block) {
                Label("Update the app to show this block.", systemImage: "square.grid.2x2").font(.mission(.body)).foregroundStyle(Tok.muted)
            } else {
                switch block.type {
                case "metric_trend":
                    if let metric {
                        if metric.source != nil { boundTrend(metric) }
                        else { trend(metric, readings: tracker.observations(for: metric.id).map { Reading(id: $0.id, at: $0.measuredAt, value: $0.value) }) }
                    }
                case "check_in": if let metric { checkIn(metric) }
                case "milestones": milestones
                case "routine_consistency": routines
                case "link": linkBlock
                default: EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(Space.m)
        .background(Tok.surface, in: MissionTheme.cardShape)
        .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
        .opacity(appeared || reduceMotion ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 14)
        .onAppear {
            guard !appeared else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.86).delay(Double(min(index, 5)) * 0.07)) { appeared = true }
        }
    }

    // MARK: Trend

    @ViewBuilder private func trend(_ metric: Wire.TrackerMetric, readings observations: [Reading], sourceNote: String? = nil, emptyText: String? = nil) -> some View {
        if let latest = observations.last {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Text(latest.value.formatted()).font(.missionMono(.title, .medium)).contentTransition(.numericText(value: latest.value))
                Text(metric.unit).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                Spacer(minLength: 0)
                if observations.count > 1 { delta(from: observations[observations.count - 2].value, to: latest.value, unit: metric.unit) }
            }
            .animation(reduceMotion ? nil : .smooth, value: latest.value)
            Text((sourceNote.map { "\($0) · " } ?? "") + latest.at.formatted(date: .abbreviated, time: .shortened)).font(.mission(.caption)).foregroundStyle(Tok.muted)
            chart(metric, observations, bound: sourceNote != nil)
            if let target = metric.target { targetGauge(latest: latest.value, target: target, unit: metric.unit, start: observations.first?.value ?? latest.value) }
        } else {
            VStack(spacing: Space.s) {
                Image(systemName: "chart.xyaxis.line").font(.mission(.title2)).foregroundStyle(Tok.muted).symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                Text("No observations yet").font(.mission(.body, .medium))
                Text(emptyText ?? "Your recorded \(metric.label.lowercased()) will appear here.").font(.mission(.subheadline)).foregroundStyle(Tok.muted).multilineTextAlignment(.center)
                if let target = metric.target { Text("Target: \(target.formatted()) \(metric.unit)").font(.mission(.subheadline)).foregroundStyle(Tok.muted) }
            }.frame(maxWidth: .infinity).padding(.vertical, Space.m)
        }
    }

    /// Direction is shown by shape and words, not colour: a lower weight is not "bad".
    private func delta(from previous: Double, to latest: Double, unit: String) -> some View {
        let change = latest - previous
        let symbol = change == 0 ? "equal" : change > 0 ? "arrow.up.right" : "arrow.down.right"
        let text = change == 0 ? "No change" : "\(abs(change).formatted(.number.precision(.fractionLength(0...2)))) \(unit)"
        return Label(text, systemImage: symbol)
            .font(.missionMono(.caption, .medium)).foregroundStyle(Tok.text)
            .padding(.horizontal, Space.s).padding(.vertical, Space.xs)
            .background(Tok.raised, in: Capsule())
            .accessibilityLabel(change == 0 ? "No change since the last observation" : "\(change > 0 ? "Up" : "Down") \(text) since the last observation")
    }

    private func chart(_ metric: Wire.TrackerMetric, _ observations: [Reading], bound: Bool = false) -> some View {
        Chart {
            ForEach(observations) { o in
                AreaMark(x: .value("Date", o.at), y: .value(metric.label, o.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Tok.accent.opacity(0.28), Tok.accent.opacity(0)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", o.at), y: .value(metric.label, o.value))
                    .interpolationMethod(.catmullRom).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round)).foregroundStyle(Tok.accent)
            }
            if let last = observations.last {
                PointMark(x: .value("Date", last.at), y: .value(metric.label, last.value))
                    .symbolSize(90).foregroundStyle(Tok.accent)
            }
            if let target = metric.target {
                RuleMark(y: .value("Target", target)).foregroundStyle(Tok.muted).lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(position: .top, alignment: .trailing) { Text("Target").font(.missionMono(.caption2)).foregroundStyle(Tok.muted) }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis(.hidden)
        .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in AxisGridLine().foregroundStyle(Tok.hairline); AxisValueLabel().font(.missionMono(.caption2)) } }
        .frame(height: 170)
        // Draw-in: the plot is revealed left to right once.
        .mask(alignment: .leading) { GeometryReader { geo in Rectangle().frame(width: geo.size.width * (reduceMotion ? 1 : reveal)) } }
        .onAppear { if !reduceMotion { withAnimation(.easeOut(duration: 0.9).delay(0.25)) { reveal = 1 } } }
        .accessibilityLabel("\(metric.label), latest \(observations.last?.value.formatted() ?? "") \(metric.unit). \(observations.count) \(bound ? "data points" : "recorded observations").")
    }

    @ViewBuilder private func targetGauge(latest: Double, target: Double, unit: String, start: Double) -> some View {
        let span = target - start
        let fraction = span == 0 ? 1 : (latest - start) / span
        MissionProgressBar(fraction: fraction, label: span == 0 || fraction >= 1
            ? "Target of \(target.formatted()) \(unit) reached"
            : "\(abs(target - latest).formatted(.number.precision(.fractionLength(0...2)))) \(unit) to \(target.formatted()) \(unit)")
            .animation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.85), value: fraction)
    }

    // MARK: Bound to a data provider

    /// A metric whose values a data provider holds: read live, with its own loading, empty and error states.
    @ViewBuilder private func boundTrend(_ metric: Wire.TrackerMetric) -> some View {
        let provider = TrackerClient.providerLabel(metric.source?.provider ?? "")
        Group {
            switch series {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            case .failed(let message, let gone):
                VStack(alignment: .leading, spacing: Space.s) {
                    Text(gone ? "\(provider) no longer has this data" : "Couldn’t load \(metric.label.lowercased()) from \(provider)").font(.mission(.body, .medium))
                    Text(gone ? "Ask your assistant to link this to something else, or to record it by hand." : message)
                        .font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                    if !gone { Button("Try again") { seriesAttempt += 1 }.frame(minHeight: 44) }
                }
            case .loaded(let readings):
                trend(metric, readings: readings, sourceNote: "From \(provider)", emptyText: "\(provider) has nothing to show for \(metric.label.lowercased()) yet.")
            }
        }
        .task(id: "\(metric.source?.provider ?? "")/\(metric.source?.series ?? "")/\(seriesAttempt)") { await loadSeries(metric) }
    }

    private func loadSeries(_ metric: Wire.TrackerMetric) async {
        guard let source = metric.source else { return }
        series = .loading
        do {
            let data = try await life.loadSeries(provider: source.provider, series: source.series)
            guard !Task.isCancelled else { return }
            series = .loaded(data.points.compactMap { point in TrackerClient.day(point.t).map { Reading(id: point.t, at: $0, value: point.value) } })
        } catch {
            guard !Task.isCancelled else { return }
            if case LifeError.engine(let code, _) = error, code == "not_found" { series = .failed("", gone: true) }
            else { series = .failed(Life.trackerMessage(error), gone: false) }
        }
    }

    @ViewBuilder private var linkBlock: some View {
        if let url = TrackerClient.link(block.url) {
            Link(destination: url) { Label("Open \(url.host() ?? "link")", systemImage: "arrow.up.right.square").frame(minHeight: 44) }
        }
    }

    // MARK: Check in

    @ViewBuilder private func checkIn(_ metric: Wire.TrackerMetric) -> some View {
        if let source = metric.source {
            Text("\(metric.label) comes from \(TrackerClient.providerLabel(source.provider)) on its own. There is nothing to record here.")
                .font(.mission(.body)).foregroundStyle(Tok.muted)
        } else {
        Button { onCheckIn(metric, nil) } label: {
            Label("Record \(metric.label.lowercased())", systemImage: "square.and.pencil")
                .frame(maxWidth: .infinity).frame(minHeight: 44)
        }
        .buttonStyle(SecondaryButtonStyle()).disabled(!interactive)
        let observations = tracker.observations(for: metric.id)
        if !observations.isEmpty {
            DisclosureGroup(isExpanded: $showHistory) {
                Text("Most recent 120 observations").font(.mission(.caption)).foregroundStyle(Tok.muted)
                ForEach(Array(observations.reversed())) { observation in
                    Button { onCheckIn(metric, observation) } label: {
                        HStack(spacing: Space.m) {
                            Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(Tok.accent)
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text("\(observation.value.formatted()) \(observation.unit)").font(.missionMono(.body))
                                Text(observation.measuredAt.formatted(date: .abbreviated, time: .shortened)).font(.mission(.caption)).foregroundStyle(Tok.muted)
                                if !observation.notes.isEmpty { Text(observation.notes).font(.mission(.caption)).foregroundStyle(Tok.muted) }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.mission(.caption)).foregroundStyle(Tok.muted)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(MissionPressStyle()).disabled(!interactive).accessibilityHint("Edit or remove this observation")
                }
            } label: { Label("Recent observations (\(observations.count))", systemImage: "clock.arrow.circlepath") }
                .font(.mission(.subheadline))
        }
        }
    }

    // MARK: Milestones

    @ViewBuilder private var milestones: some View {
        if goal.steps.isEmpty {
            Label("No milestones yet", systemImage: "flag").font(.mission(.body)).foregroundStyle(Tok.muted)
        } else {
            let done = goal.steps.filter { $0.doneAt != nil }.count
            MissionProgressBar(fraction: Double(done) / Double(goal.steps.count), label: "\(done) of \(goal.steps.count) milestones reached")
                .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.85), value: done)
        }
        ForEach(goal.steps) { step in
            let isDone = step.doneAt != nil
            Button { onStep(step) } label: {
                HStack(alignment: .center, spacing: Space.m) {
                    ZStack {
                        Circle().strokeBorder(isDone ? Color.clear : Tok.muted, lineWidth: 1.5)
                        Circle().fill(Tok.accent).scaleEffect(isDone ? 1 : 0.3).opacity(isDone ? 1 : 0)
                        Image(systemName: "checkmark").font(.mission(.caption, .bold)).foregroundStyle(Tok.onAccent)
                            .scaleEffect(isDone ? 1 : 0.3).opacity(isDone ? 1 : 0)
                    }
                    .frame(width: 26, height: 26)
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6), value: isDone)
                    Text(step.title).font(.mission(.body)).foregroundStyle(isDone ? Tok.muted : Tok.text)
                        .strikethrough(isDone, color: Tok.muted).animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: isDone)
                    Spacer(minLength: 0)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(MissionPressStyle()).disabled(!interactive || isDone)
            .sensoryFeedback(.success, trigger: isDone) { old, new in !old && new }
            .accessibilityLabel("\(step.title), \(isDone ? "done" : "mark done")")
        }
    }

    // MARK: Routines

    @ViewBuilder private var routines: some View {
        let linked = life.routines.filter { (goal.routineIds ?? []).contains($0.id) }
        if linked.isEmpty { Label("No linked routines yet", systemImage: "repeat").font(.mission(.body)).foregroundStyle(Tok.muted) }
        if let consistency = goal.consistency, consistency.last30.scheduled > 0 {
            let fraction = Double(consistency.last30.done) / Double(consistency.last30.scheduled)
            MissionProgressBar(fraction: fraction, label: "\(consistency.last30.done) of \(consistency.last30.scheduled) routine days kept")
                .animation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.85), value: fraction)
        }
        ForEach(linked) { routine in
            HStack(spacing: Space.m) {
                NavigationLink { RoutineDetailView(id: routine.id) } label: {
                    HStack {
                        Text(routine.routine.title).font(.mission(.body))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.mission(.caption)).foregroundStyle(Tok.muted)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.disabled(!interactive)
                Button { Task { await life.logRoutine(routine.id); routineFailure = life.error } } label: {
                    Image(systemName: routine.done ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.mission(.title2)).foregroundStyle(routine.done ? Tok.accent : Tok.muted)
                        .contentTransition(.symbolEffect(.replace)).frame(width: 44, height: 44)
                }
                .buttonStyle(MissionPressStyle()).disabled(!interactive || routine.done || life.busyRoutines.contains(routine.id))
                .sensoryFeedback(.success, trigger: routine.done) { old, new in !old && new }
                .accessibilityLabel("Record \(routine.routine.title)")
            }
        }
        if let routineFailure { Text(routineFailure).font(.mission(.subheadline)).foregroundStyle(Tok.critical) }
        Text("Supporting habits, not a measure of the outcome.").font(.mission(.caption)).foregroundStyle(Tok.muted)
    }
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
