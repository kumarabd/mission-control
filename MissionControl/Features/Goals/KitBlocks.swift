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

/// What a block can do besides draw: every client-owned action a view's blocks reach.
struct KitActions {
    var checkIn: (Wire.TrackerMetric, Wire.GoalMeasurement?) -> Void
    var step: (Wire.Step) -> Void
    var retry: () -> Void
    /// Record (+1) or take back (-1) one on a day, for a metric that reads a routine's logs.
    var logDay: (Wire.TrackerMetric, Date, Int) -> Void
    /// Record one number for a metric the person logs by hand; returns a message when it could not be saved.
    var record: (Wire.TrackerMetric, Double) async -> String?
}

/// One block of a view. The kit is finite and says nothing about kinds of goal: the same few blocks, composed by the
/// assistant for the goal in front of it, draw a spending limit, a weigh-in or a habit. Each is built to be touched:
/// charts scrub, the bar and the grid answer a tap, a routine's days can be logged where they are drawn, and every
/// motion has a still alternative.
struct KitBlockView: View {
    let block: Wire.ViewBlock
    let view: Wire.GoalView
    let loads: [String: KitLoad]
    let data: ViewKit.Data
    let tracker: Wire.ViewState
    let goal: Wire.Goal
    var interactive: Bool
    var index = 0
    let actions: KitActions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var hero: Bool { block.kind == "sentence" && block.emphasis == "hero" }
    private var compact: Bool { block.emphasis == "compact" }
    private var failure: String? {
        for id in block.metricIDs.sorted() { if case .failed(let message) = loads[id] { return message } }
        return nil
    }
    private var waiting: Bool { block.metricIDs.contains { loads[$0] == .loading } }

    var body: some View {
        content
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 14)
            .onAppear {
                guard !appeared else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86).delay(Double(min(index, 6)) * 0.06)) { appeared = true }
            }
    }

    @ViewBuilder private var content: some View {
        if !view.supports(block) {
            card { Label("Update the app to show this block.", systemImage: "square.grid.2x2").font(.mission(.body)).foregroundStyle(Tok.muted) }
        } else if block.kind == "sentence" || block.kind == "text" {
            VStack(alignment: .leading, spacing: Space.xs) {
                if let title = block.title, !hero { Text(title).font(.mission(.headline, .medium)).accessibilityAddTraits(.isHeader) }
                if block.kind == "text" { Text(block.body ?? "").font(.mission(.body)).foregroundStyle(Tok.muted) }
                else { SentenceBlock(block: block, data: data, waiting: waiting, failure: failure, retry: actions.retry) }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, Space.xs)
        } else {
            card {
                if let failure {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Label(failure, systemImage: "exclamationmark.triangle").font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                        Button("Try again", action: actions.retry).buttonStyle(SecondaryButtonStyle()).frame(minHeight: 44)
                    }
                } else if waiting {
                    Skeleton()
                } else {
                    switch block.kind {
                    case "bar": BarBlock(block: block, data: data)
                    case "series": SeriesBlock(block: block, data: data)
                    case "grid": GridBlock(block: block, data: data, metric: view.metrics.first { $0.id == block.metric }, actions: actions, interactive: interactive)
                    case "steps": StepsBlock(block: block, data: data, goal: goal, interactive: interactive, onStep: actions.step)
                    case "timeline": TimelineBlock(block: block, data: data)
                    case "routines": RoutinesBlock(goal: goal, interactive: interactive)
                    case "log": LogBlock(block: block, view: view, tracker: tracker, interactive: interactive, actions: actions)
                    case "link": LinkBlock(block: block)
                    default: EmptyView()
                    }
                }
            }
        }
    }

    @ViewBuilder private func card<Content: View>(@ViewBuilder _ inner: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: compact ? Space.s : Space.m) {
            if let title = block.title { Text(title).font(.mission(compact ? .subheadline : .headline, .medium)).accessibilityAddTraits(.isHeader) }
            inner()
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(compact ? Space.s : Space.m)
        .background(Tok.surface, in: MissionTheme.cardShape)
        .overlay { MissionTheme.cardShape.strokeBorder(Tok.hairline) }
    }
}

/// What a card shows while its numbers are on the way: a quiet pulse in the shape of the content.
private struct Skeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            RoundedRectangle(cornerRadius: 6).fill(Tok.raised).frame(width: 140, height: 14)
            RoundedRectangle(cornerRadius: 12).fill(Tok.raised).frame(maxWidth: .infinity).frame(height: 72)
        }
        .opacity(dim ? 0.55 : 1)
        .onAppear { guard !reduceMotion else { return }; withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true } }
        .accessibilityLabel("Loading")
    }
}

// MARK: Sentence

/// The headline of a goal: words with its figures set apart, and numbers that move to their new value.
private struct SentenceBlock: View {
    let block: Wire.ViewBlock
    let data: ViewKit.Data
    let waiting: Bool
    let failure: String?
    var retry: () -> Void
    private var hero: Bool { block.emphasis == "hero" }

    private var parts: [ViewKit.Part]? { block.text.flatMap { ViewKit.sentenceParts($0, slots: block.slots ?? [:], data) } }

    var body: some View {
        if let parts {
            let line = parts.reduce(Text("")) { text, part in
                text + (part.isFigure
                    ? Text(part.text).foregroundStyle(Tok.accent).fontWeight(.bold)
                    : Text(part.text).foregroundStyle(Tok.text))
            }
            line
                .font(hero ? .mission(.largeTitle, .semibold) : .mission(.title3, .medium))
                .lineSpacing(hero ? 2 : 0).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, Space.xs)
                .contentTransition(.numericText())
                .animation(.snappy, value: parts.map(\.text))
                .accessibilityElement().accessibilityLabel(parts.map(\.text).joined())
                .accessibilityAddTraits(hero ? .isHeader : [])
        } else if let failure {
            VStack(alignment: .leading, spacing: Space.s) {
                Label(failure, systemImage: "exclamationmark.triangle").font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                Button("Try again", action: retry).frame(minHeight: 44)
            }.padding(.horizontal, Space.xs)
        } else {
            Text(waiting ? "Loading…" : "Waiting for the numbers this needs.")
                .font(.mission(.body)).foregroundStyle(Tok.muted).padding(.horizontal, Space.xs)
        }
    }
}

// MARK: Bar

/// How far a value has got along a scale: the fill grows in, marks are named on the bar, and a tap reads it out.
private struct BarBlock: View {
    let block: Wire.ViewBlock
    let data: ViewKit.Data
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false
    @State private var picked = false

    private func number(_ calc: Wire.Calc?) -> Double? { calc.flatMap { ViewKit.evaluate($0, data).number } }
    private func text(_ n: Double) -> String { ViewKit.format(.number(n), format: block.format, unit: block.unit, decimals: block.decimals) ?? "" }

    var body: some View {
        if let value = number(block.value), let full = number(block.of), full > 0 {
            let projection = number(block.projection)
            let marks = (block.markers ?? []).compactMap { m in number(m.at).map { (label: m.label, at: $0) } }
            VStack(alignment: .leading, spacing: Space.s) {
                GeometryReader { proxy in
                    let w = proxy.size.width
                    let x = { (n: Double) -> CGFloat in w * CGFloat(min(max(n / full, 0), 1)) }
                    ZStack(alignment: .topLeading) {
                        Capsule().fill(Tok.raised).frame(height: 18).offset(y: 22)
                        if let projection, projection > value {
                            Capsule().fill(Tok.accent.opacity(0.28)).frame(width: max(grown || reduceMotion ? x(projection) : 0, 18), height: 18).offset(y: 22)
                        }
                        Capsule().fill(Tok.accent).frame(width: max(grown || reduceMotion ? x(value) : 0, value > 0 ? 18 : 0), height: 18).offset(y: 22)
                        ForEach(Array(marks.enumerated()), id: \.offset) { i, mark in
                            VStack(spacing: 2) {
                                Text(mark.label).font(.missionMono(.caption2)).foregroundStyle(Tok.muted).fixedSize()
                                Rectangle().fill(Tok.text).frame(width: 2, height: 26)
                            }
                            .position(x: min(max(x(mark.at), 24), max(w - 24, 24)), y: i % 2 == 0 ? 20 : 20)
                        }
                    }
                }
                .frame(height: 52)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.snappy) { picked.toggle() } }
                .sensoryFeedback(.selection, trigger: picked)
                .accessibilityElement()
                .accessibilityLabel(block.title ?? "Progress")
                .accessibilityValue("\(text(value)) of \(text(full)), \(Int((min(value / full, 1) * 100).rounded())) percent")

                HStack(alignment: .firstTextBaseline) {
                    Text(text(value)).font(.mission(.title3, .semibold)).foregroundStyle(Tok.text).contentTransition(.numericText())
                    Text("of \(text(full))").font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                    Spacer(minLength: 0)
                    Text("\(Int((min(value / full, 9.99) * 100).rounded()))%").font(.missionMono(.subheadline)).foregroundStyle(Tok.muted)
                }
                if picked || projection != nil || !marks.isEmpty {
                    let notes = marks.map { "\($0.label) \(text($0.at))" } + (projection.map { $0 > value ? ["likely \(text($0))"] : [] } ?? [])
                    if !notes.isEmpty { Text(notes.joined(separator: " · ")).font(.missionMono(.caption)).foregroundStyle(Tok.muted) }
                }
            }
            .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.82).delay(0.15)) { grown = true } }
        } else {
            Text("Waiting for the numbers this needs.").font(.mission(.body)).foregroundStyle(Tok.muted)
        }
    }
}

// MARK: Series

/// One metric over time. Drag along it to read any point; it draws in, and the chart says what changed.
private struct SeriesBlock: View {
    let block: Wire.ViewBlock
    let data: ViewKit.Data
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false
    @State private var selection: Date?

    private var points: [ViewKit.Point] {
        ViewKit.bucketed(block.metric ?? "", window: block.window, bucket: block.bucket, aggregate: block.aggregate, data) ?? []
    }
    private var style: String { block.style ?? "line" }
    private var unit: Calendar.Component { block.bucket == "month" ? .month : block.bucket == "week" ? .weekOfYear : .day }
    private func text(_ n: Double) -> String { ViewKit.format(.number(n), format: block.format, unit: block.unit, decimals: block.decimals) ?? "" }

    /// The current rate carried on until it reaches the target, as a dashed line.
    private var trend: [ViewKit.Point]? {
        guard let target = block.trendTo, let metric = block.metric, let last = points.last,
              let t = ViewKit.evaluate(target, data).number,
              let eta = ViewKit.evaluate(Wire.Calc(fn: "eta", metric: metric, args: [target]), data).date else { return nil }
        return [last, ViewKit.Point(date: eta, value: t)]
    }
    /// The point nearest the finger.
    private var picked: ViewKit.Point? {
        guard let selection else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selection)) < abs($1.date.timeIntervalSince(selection)) }
    }

    var body: some View {
        if points.isEmpty {
            Label("Nothing recorded in this range yet.", systemImage: "chart.xyaxis.line").font(.mission(.body)).foregroundStyle(Tok.muted)
        } else {
            VStack(alignment: .leading, spacing: Space.s) {
                summary
                chart
                    .mask(alignment: .leading) { Rectangle().scaleEffect(x: drawn || reduceMotion ? 1 : 0.001, anchor: .leading) }
                    .onAppear { withAnimation(.easeOut(duration: 0.9).delay(0.1)) { drawn = true } }
            }
        }
    }

    /// What the chart says in words: the latest figure and how it moved, or the total for bars.
    @ViewBuilder private var summary: some View {
        let first = points.first, last = points.last
        if let picked {
            HStack(alignment: .firstTextBaseline) {
                Text(text(picked.value)).font(.mission(.title3, .semibold)).foregroundStyle(Tok.text).contentTransition(.numericText())
                Text(picked.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))).font(.missionMono(.caption)).foregroundStyle(Tok.muted)
            }.animation(.snappy, value: picked.date)
        } else if style == "bars" {
            let total = points.reduce(0) { $0 + $1.value }
            HStack(alignment: .firstTextBaseline) {
                Text(text(total)).font(.mission(.title3, .semibold)).foregroundStyle(Tok.text)
                Text("over \(points.count) \(block.bucket ?? "day")\(points.count == 1 ? "" : "s")").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
            }
        } else if let first, let last, points.count > 1 {
            let change = last.value - first.value
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Text(text(last.value)).font(.mission(.title3, .semibold)).foregroundStyle(Tok.text)
                if change != 0 {
                    Label("\(text(abs(change))) since \(first.date.formatted(.dateTime.day().month(.abbreviated)))",
                          systemImage: change < 0 ? "arrow.down.right" : "arrow.up.right")
                        .font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            if let band = block.band, let from = ViewKit.evaluate(band.from, data).number, let to = ViewKit.evaluate(band.to, data).number,
               let first = points.first?.date, let end = (trend?.last?.date ?? points.last?.date) {
                RectangleMark(xStart: .value("From", first), xEnd: .value("To", end), yStart: .value(band.label, from), yEnd: .value(band.label, to))
                    .foregroundStyle(Tok.accent.opacity(0.16))
                    .annotation(position: .overlay, alignment: .bottomLeading) { Text(band.label).font(.missionMono(.caption2)).foregroundStyle(Tok.text).padding(2) }
            }
            ForEach(Array((block.lines ?? []).enumerated()), id: \.offset) { _, line in
                if let y = ViewKit.evaluate(line.at, data).number {
                    RuleMark(y: .value(line.label, y)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundStyle(Tok.text)
                        .annotation(position: .top, alignment: .trailing) { Text(line.label).font(.missionMono(.caption2)).foregroundStyle(Tok.muted) }
                }
            }
            ForEach(points, id: \.date) { p in
                switch style {
                case "bars":
                    BarMark(x: .value("Date", p.date, unit: unit), y: .value("Value", p.value))
                        .foregroundStyle(picked?.date == p.date ? Tok.text : Tok.accent).cornerRadius(3)
                case "dots":
                    PointMark(x: .value("Date", p.date), y: .value("Value", p.value)).foregroundStyle(Tok.accent)
                default:
                    AreaMark(x: .value("Date", p.date), y: .value("Value", p.value)).foregroundStyle(Tok.accent.opacity(0.10)).interpolationMethod(.monotone)
                    LineMark(x: .value("Date", p.date), y: .value("Value", p.value)).foregroundStyle(Tok.accent).interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                }
            }
            if style == "line", let last = points.last {
                PointMark(x: .value("Date", last.date), y: .value("Value", last.value)).foregroundStyle(Tok.accent).symbolSize(80)
            }
            if let trend {
                ForEach(Array(trend.enumerated()), id: \.offset) { _, p in
                    LineMark(x: .value("Date", p.date), y: .value("Value", p.value), series: .value("Series", "trend"))
                        .lineStyle(StrokeStyle(lineWidth: 1.8, dash: [4, 4])).foregroundStyle(Tok.accent)
                }
            }
            if let picked {
                RuleMark(x: .value("Date", picked.date)).foregroundStyle(Tok.text.opacity(0.35)).lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("Date", picked.date), y: .value("Value", picked.value)).foregroundStyle(Tok.text).symbolSize(90)
            }
        }
        .chartXSelection(value: $selection)
        .chartYScale(domain: .automatic(includesZero: style == "bars"))
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { AxisValueLabel().font(.missionMono(.caption2)) } }
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { AxisGridLine().foregroundStyle(Tok.hairline); AxisValueLabel().font(.missionMono(.caption2)) } }
        .frame(height: 170)
        .sensoryFeedback(.selection, trigger: picked?.date)
        .accessibilityElement()
        .accessibilityLabel(block.title ?? "Chart")
        .accessibilityValue(picked.map { "\(text($0.value)) on \($0.date.formatted(.dateTime.day().month()))" } ?? accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let first = points.first, let last = points.last else { return "No data" }
        return "\(points.count) values, from \(text(first.value)) to \(text(last.value))"
    }
}

// MARK: Grid

/// Which days something happened. Tap a day of a routine to record it there; press and hold to take one back.
private struct GridBlock: View {
    let block: Wire.ViewBlock
    let data: ViewKit.Data
    let metric: Wire.TrackerMetric?
    let actions: KitActions
    let interactive: Bool
    @State private var picked: Date?
    @State private var tick = 0

    private var values: [Date: Double] {
        var out: [Date: Double] = [:]
        for p in data.series[block.metric ?? ""] ?? [] { out[data.calendar.startOfDay(for: p.date), default: 0] += p.value }
        return out
    }
    private var logs: Bool { interactive && metric?.routineId != nil }
    private var ring: Bool { block.layout == "week_row" }
    private var weekdays: [String] {
        let symbols = data.calendar.veryShortStandaloneWeekdaySymbols, first = data.calendar.firstWeekday - 1
        return (0..<7).map { symbols[(first + $0) % 7] }
    }
    private var days: [Date] {
        let cal = data.calendar, weeks = ring ? 1 : min(max(block.weeks ?? 5, 1), 12)
        let thisWeek = ViewKit.periodStart("week", of: data.today, calendar: cal)
        let start = cal.date(byAdding: .day, value: -7 * (weeks - 1), to: thisWeek) ?? thisWeek
        return (0..<(weeks * 7)).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        let shown = days
        let done = shown.filter { (values[$0] ?? 0) > 0 }.count
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: ring ? 6 : 5) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, d in Text(d).font(.missionMono(.caption2)).foregroundStyle(Tok.muted).frame(maxWidth: .infinity) }
            }.accessibilityHidden(true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: ring ? 6 : 5), count: 7), spacing: ring ? 6 : 5) {
                ForEach(shown, id: \.self) { day in cell(day) }
            }
            footer(done: done, of: shown.filter { $0 <= data.today }.count)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: tick)
    }

    @ViewBuilder private func footer(done: Int, of total: Int) -> some View {
        HStack {
            if let picked {
                let v = values[picked] ?? 0
                Text("\(picked.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))) · \(v > 0 ? (v == v.rounded() ? "\(Int(v))" : "\(v)") : "nothing")")
                    .font(.missionMono(.caption)).foregroundStyle(Tok.text)
            } else {
                Text("\(done) of \(total) days").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
            }
            Spacer(minLength: 0)
            if logs { Text("Tap a day to record it").font(.mission(.caption)).foregroundStyle(Tok.muted) }
        }
        .animation(.snappy, value: picked)
    }

    @ViewBuilder private func cell(_ day: Date) -> some View {
        let value = values[day] ?? 0, isDone = value > 0, future = day > data.today, isToday = day == data.today
        let face = ZStack {
            if ring {
                if isDone { Circle().fill(Tok.accent); Image(systemName: "checkmark").font(.mission(.caption, .bold)).foregroundStyle(Tok.onAccent) }
                else if future { Circle().strokeBorder(Tok.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])) }
                else if isToday { Circle().strokeBorder(Tok.accent, lineWidth: 2) }
                else { Circle().fill(Tok.raised) }
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(isDone ? Tok.accent : (future ? Color.clear : Tok.raised))
                if future { RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Tok.hairline, style: StrokeStyle(lineWidth: 1, dash: [2, 2])) }
                else if isToday && !isDone { RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Tok.accent, lineWidth: 2) }
            }
        }
        .aspectRatio(ring ? 1 : 1.25, contentMode: .fit)
        .animation(.snappy, value: isDone)
        let label = "\(day.formatted(.dateTime.weekday(.wide).day().month())), \(isDone ? "done" : future ? "not yet" : "not done")"
        if let metric, logs, !future {
            Button { tick += 1; picked = day; actions.logDay(metric, day, 1) } label: { face }
                .buttonStyle(MissionPressStyle())
                .contextMenu {
                    Button { picked = day; actions.logDay(metric, day, 1) } label: { Label("Record one", systemImage: "plus.circle") }
                    if isDone { Button(role: .destructive) { picked = day; actions.logDay(metric, day, -1) } label: { Label("Take one back", systemImage: "arrow.uturn.backward") } }
                }
                .accessibilityLabel(label).accessibilityHint("Records one for this day")
                .accessibilityAction(named: "Take one back") { if isDone { actions.logDay(metric, day, -1) } }
        } else {
            face.contentShape(Rectangle()).onTapGesture { if !future { picked = (picked == day ? nil : day) } }
                .accessibilityElement().accessibilityLabel(label)
        }
    }
}

// MARK: Steps

/// The goal's own one-off steps, or a ladder of thresholds a value climbs.
private struct StepsBlock: View {
    let block: Wire.ViewBlock
    let data: ViewKit.Data
    let goal: Wire.Goal
    var interactive: Bool
    var onStep: (Wire.Step) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false
    var body: some View {
        if block.source == "goal_steps" { goalSteps } else { ladder }
    }
    @ViewBuilder private var ladder: some View {
        let marks = block.thresholds ?? []
        if let value = block.value.flatMap({ ViewKit.evaluate($0, data).number }), marks.count >= 2 {
            let next = marks.first { $0 > value }
            let text = { (n: Double) in ViewKit.format(.number(n), format: block.format, unit: block.unit, decimals: block.decimals) ?? "" }
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(marks.enumerated()), id: \.offset) { i, upper in
                        let lower = i == 0 ? 0 : marks[i - 1]
                        let fraction = upper > lower ? min(max((value - lower) / (upper - lower), 0), 1) : 0
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text(text(upper)).font(.mission(.footnote, .semibold)).foregroundStyle(fraction >= 1 ? Tok.text : Tok.muted).minimumScaleFactor(0.7).lineLimit(1)
                            GeometryReader { p in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Tok.raised)
                                    Capsule().fill(Tok.accent).frame(width: grown || reduceMotion ? p.size.width * CGFloat(fraction) : 0)
                                }
                            }.frame(height: 12)
                        }.frame(maxWidth: .infinity)
                    }
                }
                Text(next.map { "\(text($0 - value)) to the next step" } ?? "Every step reached")
                    .font(.missionMono(.caption)).foregroundStyle(Tok.muted)
            }
            .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.15)) { grown = true } }
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
                        ZStack {
                            Circle().strokeBorder(isDone ? Color.clear : Tok.muted, lineWidth: 1.5)
                            Circle().fill(Tok.accent).scaleEffect(isDone ? 1 : 0.3).opacity(isDone ? 1 : 0)
                            Image(systemName: "checkmark").font(.mission(.caption, .bold)).foregroundStyle(Tok.onAccent).scaleEffect(isDone ? 1 : 0.3).opacity(isDone ? 1 : 0)
                        }
                        .frame(width: 26, height: 26)
                        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6), value: isDone)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false
    @State private var pulse = false
    private var marks: [(label: String, date: Date)] {
        (block.markers ?? []).compactMap { m in ViewKit.evaluate(m.at, data).date.map { (m.label, $0) } }.sorted { $0.date < $1.date }
    }
    var body: some View {
        if let last = marks.last?.date {
            let span = max(last.timeIntervalSince(data.today), 1)
            VStack(alignment: .leading, spacing: Space.m) {
                GeometryReader { p in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Tok.raised).frame(height: 10)
                        Capsule().fill(Tok.accent.opacity(0.35)).frame(width: grown || reduceMotion ? p.size.width : 0, height: 10)
                        ForEach(Array(marks.enumerated()), id: \.offset) { _, m in
                            let x = p.size.width * CGFloat(min(max(m.date.timeIntervalSince(data.today) / span, 0), 1))
                            Rectangle().fill(Tok.text).frame(width: 2, height: 22).offset(x: min(max(x - 1, 0), p.size.width - 2))
                        }
                        Circle().fill(Tok.accent).frame(width: 16, height: 16)
                            .overlay { Circle().stroke(Tok.accent.opacity(pulse ? 0 : 0.5), lineWidth: 6).scaleEffect(pulse ? 1.9 : 1) }
                    }.frame(maxHeight: .infinity, alignment: .center)
                }.frame(height: 26)
                ForEach(Array(marks.enumerated()), id: \.offset) { _, m in
                    let days = data.calendar.dateComponents([.day], from: data.today, to: data.calendar.startOfDay(for: m.date)).day ?? 0
                    HStack {
                        Text(m.label).font(.mission(.body))
                        Spacer(minLength: 0)
                        Text("\(m.date.formatted(.dateTime.day().month(.abbreviated))) · \(days) day\(days == 1 ? "" : "s")").font(.missionMono(.caption)).foregroundStyle(Tok.muted)
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.1)) { grown = true }
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
            }
            .accessibilityElement(children: .combine)
        } else {
            Text("Waiting for the numbers this needs.").font(.mission(.body)).foregroundStyle(Tok.muted)
        }
    }
}

// MARK: Routines

/// The goal's own routines: tap a ring to record one for today; open one for its history.
private struct RoutinesBlock: View {
    @Environment(Life.self) private var life
    let goal: Wire.Goal
    var interactive: Bool
    var body: some View {
        let linked = life.routines.filter { (goal.routineIds ?? []).contains($0.id) }
        if linked.isEmpty {
            Label("No routines serve this goal yet", systemImage: "repeat").font(.mission(.body)).foregroundStyle(Tok.muted)
        } else {
            VStack(spacing: Space.xs) {
                ForEach(linked) { status in
                    HStack(spacing: Space.m) {
                        NavigationLink { RoutineDetailView(id: status.id) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(status.routine.title).font(.mission(.body, .medium)).foregroundStyle(Tok.text)
                                Text(caption(status)).font(.mission(.caption)).foregroundStyle(Tok.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 44).contentShape(Rectangle())
                        }.disabled(!interactive)
                        LogRing(status: status, size: 44, interactive: interactive)
                    }
                }
            }
        }
    }
    private func caption(_ s: Wire.RoutineStatus) -> String {
        if !s.scheduled { return "Not today" }
        let today = s.target > 1 ? "\(s.count) of \(s.target) today" : (s.done ? "Done today" : "Not yet today")
        return s.streak > 1 ? "\(today) · \(s.streak)-day streak" : today
    }
}

// MARK: Log

/// A quick way to record one number: type it here, or open a record to correct it.
private struct LogBlock: View {
    let block: Wire.ViewBlock
    let view: Wire.GoalView
    let tracker: Wire.ViewState
    var interactive: Bool
    let actions: KitActions
    @State private var text = ""
    @State private var saving = false
    @State private var problem: String?
    @State private var saved = 0
    @State private var showHistory = false
    @FocusState private var focused: Bool

    var body: some View {
        if let metric = view.metrics.first(where: { $0.id == block.metric }) {
            let observations = tracker.observations(for: metric.id)
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: Space.s) {
                    TextField(observations.last.map { $0.value.formatted() } ?? "0", text: $text)
                        .keyboardType(.decimalPad).focused($focused).font(.missionMono(.title3))
                        .padding(.horizontal, Space.m).frame(minHeight: 48)
                        .background(Tok.raised, in: MissionTheme.compactShape)
                        .accessibilityLabel("\(metric.label) in \(metric.unit)")
                    Text(metric.unit).font(.mission(.body)).foregroundStyle(Tok.muted)
                    Button { Task { await save(metric) } } label: {
                        Text("Save").frame(minWidth: 56).frame(minHeight: 48)
                    }
                    .buttonStyle(PrimaryButtonStyle()).disabled(!interactive || saving || TrackerClient.number(text) == nil)
                }
                if let problem { Text(problem).font(.mission(.subheadline)).foregroundStyle(Tok.critical) }
                if !observations.isEmpty {
                    DisclosureGroup(isExpanded: $showHistory) {
                        ForEach(Array(observations.reversed().prefix(60))) { observation in
                            Button { actions.checkIn(metric, observation) } label: {
                                HStack(spacing: Space.m) {
                                    VStack(alignment: .leading, spacing: Space.xs) {
                                        Text("\(observation.value.formatted()) \(observation.unit)").font(.missionMono(.body))
                                        Text(observation.measuredAt.formatted(date: .abbreviated, time: .shortened)).font(.mission(.caption)).foregroundStyle(Tok.muted)
                                        if !observation.notes.isEmpty { Text(observation.notes).font(.mission(.caption)).foregroundStyle(Tok.muted) }
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.mission(.caption)).foregroundStyle(Tok.muted)
                                }.frame(minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(MissionPressStyle()).disabled(!interactive).accessibilityHint("Edit or remove this record")
                        }
                    } label: { Label("Recent records (\(observations.count))", systemImage: "clock.arrow.circlepath") }.font(.mission(.subheadline))
                }
            }
            .sensoryFeedback(.success, trigger: saved)
        }
    }

    private func save(_ metric: Wire.TrackerMetric) async {
        guard let value = TrackerClient.number(text), metric.accepts(value) else { problem = "That is outside the range this can take."; return }
        saving = true; defer { saving = false }
        if let message = await actions.record(metric, value) { problem = message; return }
        problem = nil; text = ""; focused = false; saved += 1
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
