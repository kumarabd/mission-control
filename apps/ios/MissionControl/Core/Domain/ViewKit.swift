import Foundation

/// Evaluates the view kit's calculations on live data. A view's numbers are never written by the model: a block names a
/// metric and a function from the engine's catalogue, and this turns them into a figure. Foundation only, so the
/// same checks run without the UI (Tests/ViewKitChecks.swift).
enum ViewKit {
    struct Point: Equatable { var date: Date; var value: Double }

    enum Value: Equatable {
        case number(Double), date(Date), unknown
        var number: Double? { if case .number(let n) = self { n } else { nil } }
        var date: Date? { if case .date(let d) = self { d } else { nil } }
    }

    /// What the calculations read. `series[metric]` is nil when that metric's data has not arrived, which makes every
    /// calculation over it unknown; an empty array means it arrived and has no records.
    struct Data {
        var series: [String: [Point]]
        var now: Date
        var calendar: Calendar
        init(series: [String: [Point]], now: Date = Date(), calendar: Calendar = .current) {
            self.series = series.mapValues { $0.sorted { $0.date < $1.date } }
            self.now = now; self.calendar = calendar
        }
        var today: Date { calendar.startOfDay(for: now) }
    }

    // MARK: Dates

    static func parse(_ text: String, calendar: Calendar) -> Date? {
        let f = DateFormatter()
        f.calendar = calendar; f.timeZone = calendar.timeZone; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: text).flatMap { calendar.date(bySettingHour: 12, minute: 0, second: 0, of: $0) }
    }

    private static func component(_ period: String) -> Calendar.Component { period == "week" ? .weekOfYear : .month }

    /// The first day of the calendar week or month that holds `date`.
    static func periodStart(_ period: String, of date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: component(period), for: date)?.start ?? calendar.startOfDay(for: date)
    }
    /// The first day after that week or month.
    static func periodEnd(_ period: String, of date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: component(period), for: date)?.end ?? calendar.startOfDay(for: date)
    }
    private static func days(from a: Date, to b: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: a), to: calendar.startOfDay(for: b)).day ?? 0
    }

    // MARK: Windows

    static func points(_ metric: String, in window: Wire.Window?, _ data: Data) -> [Point]? {
        guard let all = data.series[metric] else { return nil }
        guard let window else { return all }
        let cal = data.calendar
        if let period = window.period {
            let start = periodStart(period, of: data.now, calendar: cal), end = periodEnd(period, of: data.now, calendar: cal)
            return all.filter { $0.date >= start && $0.date < end }
        }
        if let n = window.days {
            let from = cal.date(byAdding: .day, value: -(max(n, 1) - 1), to: data.today) ?? data.today
            return all.filter { $0.date >= from && $0.date < (cal.date(byAdding: .day, value: 1, to: data.today) ?? data.now) }
        }
        return all
    }

    // MARK: Evaluation

    static func evaluate(_ c: Wire.Calc, _ data: Data) -> Value {
        let cal = data.calendar
        func args() -> [Double]? {
            let values = (c.args ?? []).map { evaluate($0, data).number }
            return values.contains(where: { $0 == nil }) ? nil : values.compactMap { $0 }
        }
        func number(_ n: Double?) -> Value { n.flatMap { $0.isFinite ? $0 : nil }.map(Value.number) ?? .unknown }
        switch c.fn {
        case "const": return number(c.value)
        case "date": return c.date.flatMap { parse($0, calendar: cal) }.map(Value.date) ?? .unknown
        case "latest": return number(data.series[c.metric ?? ""]?.last?.value)
        case "first": return number(data.series[c.metric ?? ""]?.first?.value)
        case "sum":
            guard let p = points(c.metric ?? "", in: c.window, data) else { return .unknown }
            return .number(p.reduce(0) { $0 + $1.value })
        case "mean":
            guard let p = points(c.metric ?? "", in: c.window, data), !p.isEmpty else { return .unknown }
            return number(p.reduce(0) { $0 + $1.value } / Double(p.count))
        case "count":
            guard let p = points(c.metric ?? "", in: c.window, data) else { return .unknown }
            return .number(Double(Set(p.filter { $0.value > 0 }.map { cal.startOfDay(for: $0.date) }).count))
        case "add": return args().map { $0.reduce(0, +) }.map(Value.number) ?? .unknown
        case "mul": return args().map { $0.reduce(1, *) }.map(Value.number) ?? .unknown
        case "min": return args()?.min().map(Value.number) ?? .unknown
        case "max": return args()?.max().map(Value.number) ?? .unknown
        case "sub": if let a = args(), a.count == 2 { return number(a[0] - a[1]) }; return .unknown
        case "div": if let a = args(), a.count == 2, a[1] != 0 { return number(a[0] / a[1]) }; return .unknown
        case "days_left":
            if let period = c.period {
                let last = cal.date(byAdding: .day, value: -1, to: periodEnd(period, of: data.now, calendar: cal)) ?? data.today
                return .number(Double(max(0, days(from: data.today, to: last, calendar: cal))))
            }
            guard let text = c.date, let target = parse(text, calendar: cal) else { return .unknown }
            return .number(Double(max(0, days(from: data.today, to: target, calendar: cal))))
        case "elapsed":
            guard let period = c.period else { return .unknown }
            let start = periodStart(period, of: data.now, calendar: cal), end = periodEnd(period, of: data.now, calendar: cal)
            let total = days(from: start, to: end, calendar: cal)
            return total > 0 ? .number(Double(days(from: start, to: data.today, calendar: cal) + 1) / Double(total)) : .unknown
        case "project":
            guard let metric = c.metric, let period = c.period,
                  let sum = evaluate(Wire.Calc(fn: "sum", metric: metric, window: Wire.Window(period: period, days: nil)), data).number,
                  let elapsed = evaluate(Wire.Calc(fn: "elapsed", period: period), data).number, elapsed > 0 else { return .unknown }
            return number(sum / elapsed)
        case "rate":
            guard let perDays = ["day": 1.0, "week": 7.0, "month": 365.25 / 12][c.per ?? ""], let r = dailyRate(c.metric ?? "", data) else { return .unknown }
            return number(r * perDays)
        case "eta":
            guard let metric = c.metric, let target = args()?.first, let latest = data.series[metric]?.last?.value,
                  let r = dailyRate(metric, data), r != 0 else { return .unknown }
            let daysAway = (target - latest) / r
            guard daysAway.isFinite, daysAway >= 0, daysAway < 36500 else { return .unknown }
            return cal.date(byAdding: .day, value: Int(daysAway.rounded(.up)), to: data.today).map(Value.date) ?? .unknown
        case "streak":
            guard let p = data.series[c.metric ?? ""] else { return .unknown }
            let done = Set(p.filter { $0.value > 0 }.map { cal.startOfDay(for: $0.date) })
            var day = done.contains(data.today) ? data.today : (cal.date(byAdding: .day, value: -1, to: data.today) ?? data.today)
            var n = 0
            while done.contains(day) { n += 1; day = cal.date(byAdding: .day, value: -1, to: day) ?? day.addingTimeInterval(-86_400) }
            return .number(Double(n))
        default: return .unknown
        }
    }

    /// Change per day from the first to the latest value; nil with fewer than two days of data.
    private static func dailyRate(_ metric: String, _ data: Data) -> Double? {
        guard let p = data.series[metric], let first = p.first, let last = p.last else { return nil }
        let d = days(from: first.date, to: last.date, calendar: data.calendar)
        return d > 0 ? (last.value - first.value) / Double(d) : nil
    }

    // MARK: Series

    /// A series as drawn: the window applied, then grouped by day, week or month when asked.
    static func bucketed(_ metric: String, window: Wire.Window?, bucket: String?, aggregate: String?, _ data: Data) -> [Point]? {
        guard let p = points(metric, in: window, data) else { return nil }
        guard let bucket else { return p }
        let cal = data.calendar
        var groups: [Date: [Double]] = [:]
        for point in p {
            let key = bucket == "day" ? cal.startOfDay(for: point.date) : periodStart(bucket, of: point.date, calendar: cal)
            groups[key, default: []].append(point.value)
        }
        return groups.keys.sorted().map { key in
            let v = groups[key] ?? []
            switch aggregate ?? "sum" {
            case "mean": return Point(date: key, value: v.reduce(0, +) / Double(v.count))
            case "last": return Point(date: key, value: v.last ?? 0)
            default: return Point(date: key, value: v.reduce(0, +))
            }
        }
    }

    // MARK: Formatting

    static func format(_ value: Value, format: String?, unit: String?, decimals: Int?, locale: Locale = .current) -> String? {
        switch value {
        case .unknown: return nil
        case .date(let d): return d.formatted(.dateTime.day().month(.abbreviated).locale(locale))
        case .number(let n):
            switch format ?? "number" {
            case "money":
                let digits = decimals ?? (abs(n) >= 100 || n == n.rounded() ? 0 : 2)
                return n.formatted(.currency(code: unit ?? "USD").precision(.fractionLength(digits)).locale(locale))
            case "percent":
                return (n).formatted(.percent.precision(.fractionLength(decimals ?? 0)).locale(locale))
            case "days":
                let d = Int(n.rounded()); return d == 1 ? "1 day" : "\(d) days"
            case "date":
                return nil
            default:
                let digits = decimals ?? (n == n.rounded() || abs(n) >= 100 ? 0 : 1)
                let text = n.formatted(.number.precision(.fractionLength(digits)).locale(locale))
                return unit.map { text + " " + $0 } ?? text
            }
        }
    }

    /// A piece of a sentence: plain words, or a figure the calculations filled in.
    struct Part: Equatable { var text: String; var isFigure: Bool }

    private static let slotName = try! NSRegularExpression(pattern: #"\{([a-z][a-z0-9_]{0,31})\}"#)

    /// A sentence as pieces, so a client can set its figures apart from its words; nil while any figure it needs is unknown.
    static func sentenceParts(_ text: String, slots: [String: Wire.Slot], _ data: Data, locale: Locale = .current) -> [Part]? {
        let whole = NSRange(text.startIndex..., in: text)
        var parts: [Part] = [], cursor = text.startIndex
        for match in slotName.matches(in: text, range: whole) {
            guard let all = Range(match.range, in: text), let name = Range(match.range(at: 1), in: text) else { continue }
            if all.lowerBound > cursor { parts.append(Part(text: String(text[cursor..<all.lowerBound]), isFigure: false)) }
            guard let slot = slots[String(text[name])],
                  let printed = format(evaluate(slot.calc, data), format: slot.format, unit: slot.unit, decimals: slot.decimals, locale: locale) else { return nil }
            parts.append(Part(text: printed, isFigure: true))
            cursor = all.upperBound
        }
        if cursor < text.endIndex { parts.append(Part(text: String(text[cursor...]), isFigure: false)) }
        return parts
    }

    /// A sentence with every {name} filled in, or nil while any figure it needs is unknown.
    static func sentence(_ text: String, slots: [String: Wire.Slot], _ data: Data, locale: Locale = .current) -> String? {
        sentenceParts(text, slots: slots, data, locale: locale)?.map(\.text).joined()
    }
}
