import SwiftUI
import Charts

/// Where a metric's live data stands. A block whose data has not arrived says so rather than drawing a guess.
enum KitLoad: Equatable {
    case loading
    case failed(String)
    case ready([ViewKit.Point])
}

extension Wire.Calc {
    /// Every metric this calculation reads.
    var metricIDs: Set<String> { Set([metric].compactMap { $0 }).union((args ?? []).flatMap(\.metricIDs)) }
}
extension Wire.ViewBlock {
    /// Every metric the block depends on, in any of its calculations.
    var metricIDs: Set<String> {
        var ids = Set([metric].compactMap { $0 })
        for calc in [value, of, projection, trendTo, band?.from, band?.to].compactMap({ $0 }) { ids.formUnion(calc.metricIDs) }
        for marker in (markers ?? []) + (lines ?? []) { ids.formUnion(marker.at.metricIDs) }
        for slot in (slots ?? [:]).values { ids.formUnion(slot.calc.metricIDs) }
        return ids
    }
}

/// One block of a view. The kit is finite and says nothing about kinds of goal: the same few blocks, composed by the
/// assistant for the goal in front of it, draw a spending limit, a weigh-in or a habit.
struct KitBlockView: View {
    let block: Wire.ViewBlock
    let view: Wire.GoalView
    let loads: [String: KitLoad]
    let data: ViewKit.Data
    let tracker: Wire.ViewState
    let goal: Wire.Goal
    var interactive: Bool
    var onCheckIn: (Wire.TrackerMetric, Wire.GoalMeasurement?) -> Void
    var onStep: (Wire.Step) -> Void
    var onRetry: () -> Void

    private var hero: Bool { block.kind == "sentence" && block.emphasis == "hero" }
    private var failure: String? {
        for id in block.metricIDs.sorted() { if case .failed(let message) = loads[id] { return message } }
        return nil
    }
    private var waiting: Bool { block.metricIDs.contains { loads[$0] == .loading } }

    var body: some View {
        if !view.supports(block) {
            card { Label("Update the app to show this block.", systemImage: "square.grid.2x2").font(.mission(.body)).foregroundStyle(Tok.muted) }
        } else if hero {
            SentenceBlock(block: block, data: data, waiting: waiting, failure: failure, onRetry: onRetry)
        } else if block.kind == "sentence" || block.kind == "text" {
            VStack(alignment: .leading, spacing: Space.xs) {
                if let title = block.title { Text(title).font(.mission(.headline, .medium)).accessibilityAddTraits(.isHeader) }
                if block.kind == "text" { Text(block.body ?? "").font(.mission(.body)).foregroundStyle(Tok.muted) }
                else { SentenceBlock(block: block, data: data, waiting: waiting, failure: failure, onRetry: onRetry) }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, Space.xs)
        } else {
            card {
                if let failure {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text(failure).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                        Button("Try again", action: onRetry).frame(minHeight: 44)
                    }
                } else if waiting {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    switch block.kind {
                    case "bar": BarBlock(block: block, data: data)
                    case "series": SeriesBlock(block: block, data: data)
                    case "grid": GridBlock(block: block, data: data)
                    case "steps": StepsBlock(block: block, data: data, goal: goal, interactive: interactive, onStep: onStep)
                    case "timeline": TimelineBlock(block: block, data: data)
                    case "log": LogBlock(block: block, view: view, tracker: tracker, interactive: interactive, onCheckIn: onCheckIn)
                    case "link": LinkBlock(block: block)
                    default: EmptyView()
                    }
                }
            }
        }
    }

    @ViewBuilder private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            if let title = block.title { Text(title).font(.mission(.headline, .medium)).accessibilityAddTraits(.isHeader) }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(Space.m)
        .background(Tok.surface, in: MissionTheme.cardShape)
        .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
    }
}

// MARK: Sentence

private struct SentenceBlock: View {
    let block: Wire.ViewBlock
    let data: ViewKit.Data
    let waiting: Bool
    let failure: String?
    var onRetry: () -> Void
    var body: some View {
        if let text = block.text, let line = ViewKit.sentence(text, slots: block.slots ?? [:], data) {
            Text(line)
                .font(block.emphasis == "hero" ? .mission(.largeTitle, .bold) : .mission(.title3, .medium))
                .foregroundStyle(Tok.text).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, Space.xs)
                .accessibilityAddTraits(block.emphasis == "hero" ? .isHeader : [])
        } else if let failure {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(failure).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                Button("Try again", action: onRetry).frame(minHeight: 44)
            }.padding(.horizontal, Space.xs)
        } else {
            Text(waiting ? "Loading…" : "Waiting for the numbers this needs.")
                .font(.mission(.body)).foregroundStyle(Tok.muted).padding(.horizontal, Space.xs)
        }
    }
}

// MARK: Bar

private struct BarBlock: View {
    let block: Wire.ViewBlock
    let data: ViewKit.Data
    private func number(_ calc: Wire.Calc?) -> Double? { calc.flatMap { ViewKit.evaluate($0, data).number } }
    private func text(_ n: Double) -> String { ViewKit.format(.number(n), format: block.format, unit: block.unit, decimals: block.decimals) ?? "" }
    var body: some View {
        if let value = number(block.value), let full = number(block.of), full > 0 {
            let projection = number(block.projection)
            VStack(alignment: .leading, spacing: Space.s) {
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let x = { (n: Double) -> CGFloat in w * CGFloat(min(max(n / full, 0), 1)) }
                    ZStack(alignment: .leading) {
                        Capsule().fill(Tok.raised)
                        if let projection, projection > value {
                            Capsule().fill(Tok.accent.opacity(0.28)).frame(width: max(x(projection), 14))
                        }
                        Capsule().fill(Tok.accent).frame(width: max(x(value), value > 0 ? 14 : 0))
                        ForEach(Array((block.markers ?? []).enumerated()), id: \.offset) { _, marker in
                            if let at = number(marker.at) {
                                Rectangle().fill(Tok.text).frame(width: 2, height: 24).offset(x: min(max(x(at) - 1, 0), w - 2))
                            }
                        }
                    }
                }
                .frame(height: 14).padding(.vertical, Space.xs)
                .accessibilityElement().accessibilityLabel("\(text(value)) of \(text(full))")
                // The marks, named, so colour and position are never the only way to read the bar.
                let notes = (block.markers ?? []).compactMap { m in number(m.at).map { "\(m.label) \(text($0))" } }
                    + (projection.map { $0 > value ? ["likely \(text($0))"] : [] } ?? [])
                Text(([text(value) + " of " + text(full)] + notes).joined(separator: " · "))
                    .font(.missionMono(.caption)).foregroundStyle(Tok.muted)
            }
        } else {
            Text("Waiting for the numbers this needs.").font(.mission(.body)).foregroundStyle(Tok.muted)
        }
    }
}

// MARK: Series

private struct SeriesBlock: View {
    let block: Wire.ViewBlock
    let data: ViewKit.Data
    private var points: [ViewKit.Point] {
        ViewKit.bucketed(block.metric ?? "", window: block.window, bucket: block.bucket, aggregate: block.aggregate, data) ?? []
    }
    private var unit: Calendar.Component { block.bucket == "month" ? .month : block.bucket == "week" ? .weekOfYear : .day }
    /// The current rate carried on until it reaches the target, as a dashed line.
    private var trend: [ViewKit.Point]? {
        guard let target = block.trendTo, let metric = block.metric, let last = points.last,
              let t = ViewKit.evaluate(target, data).number,
              let eta = ViewKit.evaluate(Wire.Calc(fn: "eta", metric: metric, args: [target]), data).date else { return nil }
        return [last, ViewKit.Point(date: eta, value: t)]
    }
    var body: some View {
        if points.isEmpty {
            Text("Nothing recorded in this range yet.").font(.mission(.body)).foregroundStyle(Tok.muted)
        } else {
            Chart {
                if let band = block.band, let from = ViewKit.evaluate(band.from, data).number, let to = ViewKit.evaluate(band.to, data).number,
                   let first = points.first?.date, let end = (trend?.last?.date ?? points.last?.date) {
                    RectangleMark(xStart: .value("From", first), xEnd: .value("To", end), yStart: .value(band.label, from), yEnd: .value(band.label, to))
                        .foregroundStyle(Tok.accent.opacity(0.16))
                }
                ForEach(Array((block.lines ?? []).enumerated()), id: \.offset) { _, line in
                    if let y = ViewKit.evaluate(line.at, data).number {
                        RuleMark(y: .value(line.label, y)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundStyle(Tok.text)
                            .annotation(position: .top, alignment: .trailing) { Text(line.label).font(.missionMono(.caption2)).foregroundStyle(Tok.muted) }
                    }
                }
                ForEach(points, id: \.date) { p in
                    switch block.style ?? "line" {
                    case "bars": BarMark(x: .value("Date", p.date, unit: unit), y: .value("Value", p.value)).foregroundStyle(Tok.accent)
                    case "dots": PointMark(x: .value("Date", p.date), y: .value("Value", p.value)).foregroundStyle(Tok.accent)
                    default:
                        LineMark(x: .value("Date", p.date), y: .value("Value", p.value)).foregroundStyle(Tok.accent).interpolationMethod(.monotone)
                    }
                }
                if (block.style ?? "line") == "line", let last = points.last {
                    PointMark(x: .value("Date", last.date), y: .value("Value", last.value)).foregroundStyle(Tok.accent).symbolSize(70)
                        .annotation(position: .top) {
                            Text(ViewKit.format(.number(last.value), format: block.format, unit: block.unit, decimals: block.decimals) ?? "")
                                .font(.missionMono(.caption2)).foregroundStyle(Tok.text)
                        }
                }
                if let trend {
                    ForEach(Array(trend.enumerated()), id: \.offset) { _, p in
                        LineMark(x: .value("Date", p.date), y: .value("Value", p.value), series: .value("Series", "trend"))
                            .lineStyle(StrokeStyle(lineWidth: 1.6, dash: [4, 4])).foregroundStyle(Tok.accent)
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: (block.style ?? "line") == "bars"))
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { AxisValueLabel().font(.missionMono(.caption2)) } }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { AxisGridLine().foregroundStyle(Tok.hairline); AxisValueLabel().font(.missionMono(.caption2)) } }
            .frame(height: 160)
            .accessibilityElement().accessibilityLabel(summary)
        }
    }
    private var summary: String {
        guard let first = points.first, let last = points.last else { return "No data" }
        return "\(block.title ?? "Chart"): \(points.count) values, from \(first.value.formatted()) to \(last.value.formatted())"
    }
}

// MARK: Grid

private struct GridBlock: View {
    let block: Wire.ViewBlock
    let data: ViewKit.Data
    private var done: Set<Date> {
        Set((data.series[block.metric ?? ""] ?? []).filter { $0.value > 0 }.map { data.calendar.startOfDay(for: $0.date) })
    }
    private var weekdays: [String] {
        let symbols = data.calendar.veryShortStandaloneWeekdaySymbols, first = data.calendar.firstWeekday - 1
        return (0..<7).map { symbols[(first + $0) % 7] }
    }
    private func cells(weeks: Int) -> [Date] {
        let cal = data.calendar
        let thisWeek = ViewKit.periodStart("week", of: data.today, calendar: cal)
        let start = cal.date(byAdding: .day, value: -7 * (weeks - 1), to: thisWeek) ?? thisWeek
        return (0..<(weeks * 7)).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }
    var body: some View {
        let weekRow = block.layout == "week_row"
        let days = cells(weeks: weekRow ? 1 : min(max(block.weeks ?? 5, 1), 12))
        VStack(spacing: Space.s) {
            HStack(spacing: weekRow ? 6 : 5) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, d in
                    Text(d).font(.missionMono(.caption2)).foregroundStyle(Tok.muted).frame(maxWidth: .infinity)
                }
            }.accessibilityHidden(true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: weekRow ? 6 : 5), count: 7), spacing: weekRow ? 6 : 5) {
                ForEach(days, id: \.self) { day in cell(day, ring: weekRow) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days.filter { done.contains($0) }.count) of \(days.filter { $0 <= data.today }.count) days done")
    }
    @ViewBuilder private func cell(_ day: Date, ring: Bool) -> some View {
        let isDone = done.contains(day), isToday = day == data.today, future = day > data.today
        if ring {
            ZStack {
                if isDone { Circle().fill(Tok.accent); Image(systemName: "checkmark").font(.mission(.caption, .bold)).foregroundStyle(Tok.onAccent) }
                else if future { Circle().strokeBorder(Tok.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])) }
                else if isToday { Circle().strokeBorder(Tok.accent, lineWidth: 2) }
                else { Circle().fill(Tok.raised) }
            }.aspectRatio(1, contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isDone ? Tok.accent : (future ? Color.clear : Tok.raised))
                .overlay { if future { RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Tok.hairline, style: StrokeStyle(lineWidth: 1, dash: [2, 2])) }
                           else if isToday && !isDone { RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Tok.accent, lineWidth: 2) } }
                .aspectRatio(1.6, contentMode: .fit)
        }
    }
}

// MARK: Steps

private struct StepsBlock: View {
    let block: Wire.ViewBlock
    let data: ViewKit.Data
    let goal: Wire.Goal
    var interactive: Bool
    var onStep: (Wire.Step) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if block.source == "goal_steps" { goalSteps } else { ladder }
    }
    @ViewBuilder private var ladder: some View {
        let marks = block.thresholds ?? []
        if let value = block.value.flatMap({ ViewKit.evaluate($0, data).number }), marks.count >= 2 {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(marks.enumerated()), id: \.offset) { i, upper in
                    let lower = i == 0 ? 0 : marks[i - 1]
                    let fraction = upper > lower ? min(max((value - lower) / (upper - lower), 0), 1) : 0
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(ViewKit.format(.number(upper), format: block.format, unit: block.unit, decimals: block.decimals) ?? "")
                            .font(.mission(.footnote, .semibold)).foregroundStyle(fraction >= 1 ? Tok.text : Tok.muted)
                            .minimumScaleFactor(0.7).lineLimit(1)
                        GeometryReader { p in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Tok.raised)
                                Capsule().fill(Tok.accent).frame(width: p.size.width * CGFloat(fraction))
                            }
                        }.frame(height: 10)
                    }.frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement().accessibilityLabel("\(marks.filter { value >= $0 }.count) of \(marks.count) steps reached")
        } else {
            Text("Waiting for the numbers this needs.").font(.mission(.body)).foregroundStyle(Tok.muted)
        }
    }
    @ViewBuilder private var goalSteps: some View {
        if goal.steps.isEmpty {
            Label("No steps yet", systemImage: "flag").font(.mission(.body)).foregroundStyle(Tok.muted)
        } else {
            let done = goal.steps.filter { $0.doneAt != nil }.count
            MissionProgressBar(fraction: Double(done) / Double(goal.steps.count), label: "\(done) of \(goal.steps.count) steps done")
                .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.85), value: done)
            ForEach(goal.steps) { step in
                let isDone = step.doneAt != nil
                Button { onStep(step) } label: {
                    HStack(spacing: Space.m) {
                        Image(systemName: isDone ? "checkmark.circle.fill" : "circle").font(.mission(.title3))
                            .foregroundStyle(isDone ? Tok.accent : Tok.muted).frame(width: 26)
                        Text(step.title).font(.mission(.body)).foregroundStyle(isDone ? Tok.muted : Tok.text).strikethrough(isDone, color: Tok.muted)
                        Spacer(minLength: 0)
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(MissionPressStyle()).disabled(!interactive || isDone)
                .sensoryFeedback(.success, trigger: isDone) { old, new in !old && new }
                .accessibilityLabel("\(step.title), \(isDone ? "done" : "mark done")")
            }
        }
    }
}

// MARK: Timeline

private struct TimelineBlock: View {
    let block: Wire.ViewBlock
    let data: ViewKit.Data
    private var marks: [(label: String, date: Date)] {
        (block.markers ?? []).compactMap { m in ViewKit.evaluate(m.at, data).date.map { (m.label, $0) } }.sorted { $0.date < $1.date }
    }
    var body: some View {
        if let last = marks.last?.date {
            let span = max(last.timeIntervalSince(data.today), 1)
            VStack(alignment: .leading, spacing: Space.s) {
                GeometryReader { p in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Tok.raised).frame(height: 10)
                        Capsule().fill(Tok.accent.opacity(0.35)).frame(width: p.size.width, height: 10)
                        Circle().fill(Tok.accent).frame(width: 16, height: 16)
                        ForEach(Array(marks.enumerated()), id: \.offset) { _, m in
                            let x = p.size.width * CGFloat(min(max(m.date.timeIntervalSince(data.today) / span, 0), 1))
                            Rectangle().fill(Tok.text).frame(width: 2, height: 22).offset(x: min(max(x - 1, 0), p.size.width - 2))
                        }
                    }.frame(maxHeight: .infinity, alignment: .center)
                }.frame(height: 24)
                ForEach(Array(marks.enumerated()), id: \.offset) { _, m in
                    let days = data.calendar.dateComponents([.day], from: data.today, to: data.calendar.startOfDay(for: m.date)).day ?? 0
                    HStack {
                        Text(m.label).font(.mission(.subheadline))
                        Spacer(minLength: 0)
                        Text("\(m.date.formatted(.dateTime.day().month(.abbreviated))) · \(days) days").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                    }
                }
            }.accessibilityElement(children: .combine)
        } else {
            Text("Waiting for the numbers this needs.").font(.mission(.body)).foregroundStyle(Tok.muted)
        }
    }
}

// MARK: Log

private struct LogBlock: View {
    let block: Wire.ViewBlock
    let view: Wire.GoalView
    let tracker: Wire.ViewState
    var interactive: Bool
    var onCheckIn: (Wire.TrackerMetric, Wire.GoalMeasurement?) -> Void
    @State private var showHistory = false
    var body: some View {
        if let metric = view.metrics.first(where: { $0.id == block.metric }) {
            Button { onCheckIn(metric, nil) } label: {
                Label("Record \(metric.label.lowercased())", systemImage: "square.and.pencil").frame(maxWidth: .infinity).frame(minHeight: 44)
            }.buttonStyle(SecondaryButtonStyle()).disabled(!interactive)
            let observations = tracker.observations(for: metric.id)
            if !observations.isEmpty {
                DisclosureGroup(isExpanded: $showHistory) {
                    ForEach(Array(observations.reversed())) { observation in
                        Button { onCheckIn(metric, observation) } label: {
                            HStack(spacing: Space.m) {
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
                } label: { Label("Recent records (\(observations.count))", systemImage: "clock.arrow.circlepath") }.font(.mission(.subheadline))
            }
        }
    }
}

// MARK: Link

private struct LinkBlock: View {
    let block: Wire.ViewBlock
    var body: some View {
        if let url = TrackerClient.link(block.url) {
            Link(destination: url) { Label("Open \(url.host() ?? "link")", systemImage: "arrow.up.right.square").frame(minHeight: 44) }
        }
    }
}
