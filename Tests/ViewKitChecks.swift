import Foundation

/// The view kit's calculations, pinned to the figures of the design mock: a spending limit, a weigh-in, a habit.
@main struct ViewKitChecks {
    static func main() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!; cal.firstWeekday = 2
        let en = Locale(identifier: "en_US")
        func day(_ s: String) -> Date { ViewKit.parse(s, calendar: cal)! }
        let now = cal.date(bySettingHour: 15, minute: 0, second: 0, of: day("2026-10-19"))!
        func pts(_ rows: [(String, Double)]) -> [ViewKit.Point] { rows.map { ViewKit.Point(date: day($0.0), value: $0.1) } }
        func calc(_ json: String) -> Wire.Calc { try! JSONDecoder().decode(Wire.Calc.self, from: Data(json.utf8)) }
        func near(_ v: ViewKit.Value, _ x: Double, _ eps: Double = 0.01, _ line: Int = #line) {
            guard let n = v.number, abs(n - x) <= eps else { fatalError("line \(line): wanted \(x), got \(v)") }
        }

        // A spending limit: $98 spent by the 19th of a 31-day month.
        let spend = pts([("2026-09-20", 40), ("2026-10-02", 12), ("2026-10-05", 31), ("2026-10-07", 8), ("2026-10-11", 24), ("2026-10-13", 6), ("2026-10-16", 17)])
        let d = ViewKit.Data(series: ["spend": spend], now: now, calendar: cal)
        let thisMonth = #"{"fn":"sum","metric":"spend","window":{"period":"month"}}"#
        near(ViewKit.evaluate(calc(thisMonth), d), 98)
        near(ViewKit.evaluate(calc(#"{"fn":"sub","args":[{"fn":"const","value":200},\#(thisMonth)]}"#), d), 102)
        near(ViewKit.evaluate(calc(#"{"fn":"days_left","period":"month"}"#), d), 12)
        near(ViewKit.evaluate(calc(#"{"fn":"elapsed","period":"month"}"#), d), 19.0 / 31.0, 0.0001)
        near(ViewKit.evaluate(calc(#"{"fn":"mul","args":[{"fn":"const","value":200},{"fn":"elapsed","period":"month"}]}"#), d), 122.58)
        near(ViewKit.evaluate(calc(#"{"fn":"project","metric":"spend","period":"month"}"#), d), 159.89)
        let slots: [String: Wire.Slot] = [
            "left": Wire.Slot(calc: calc(#"{"fn":"sub","args":[{"fn":"const","value":200},\#(thisMonth)]}"#), format: "money", unit: "USD", decimals: nil),
            "days": Wire.Slot(calc: calc(#"{"fn":"days_left","period":"month"}"#), format: "number", unit: nil, decimals: nil),
        ]
        precondition(ViewKit.sentence("{left} left, {days} days to go", slots: slots, d, locale: en) == "$102 left, 12 days to go")
        let months = ViewKit.bucketed("spend", window: Wire.Window(period: nil, days: 120), bucket: "month", aggregate: "sum", d)!
        precondition(months.map(\.value) == [40, 98])

        // A weigh-in: 83.0 on 5 Oct down to 81.8 on 19 Oct, heading for 78.
        let w = ViewKit.Data(series: ["weight": pts([("2026-10-05", 83.0), ("2026-10-12", 82.4), ("2026-10-19", 81.8)])], now: now, calendar: cal)
        near(ViewKit.evaluate(calc(#"{"fn":"sub","args":[{"fn":"first","metric":"weight"},{"fn":"latest","metric":"weight"}]}"#), w), 1.2)
        near(ViewKit.evaluate(calc(#"{"fn":"rate","metric":"weight","per":"week"}"#), w), -0.6)
        let eta = ViewKit.evaluate(calc(#"{"fn":"eta","metric":"weight","args":[{"fn":"const","value":78}]}"#), w).date
        precondition(eta == cal.date(byAdding: .day, value: 45, to: cal.startOfDay(for: now)))
        // Heading away from the target gives no date, rather than a wrong one.
        precondition(ViewKit.evaluate(calc(#"{"fn":"eta","metric":"weight","args":[{"fn":"const","value":90}]}"#), w) == .unknown)

        // A habit: logged on some mornings, none yet today.
        let stretch = pts([("2026-10-13", 1), ("2026-10-14", 1), ("2026-10-15", 1), ("2026-10-17", 1), ("2026-10-18", 1)])
        let h = ViewKit.Data(series: ["stretch": stretch], now: now, calendar: cal)
        near(ViewKit.evaluate(calc(#"{"fn":"count","metric":"stretch","window":{"days":6}}"#), h), 4)
        near(ViewKit.evaluate(calc(#"{"fn":"streak","metric":"stretch"}"#), h), 2) // 18th and 17th; the 16th was missed

        // Missing data is unknown, never zero or a guess.
        let none = ViewKit.Data(series: [:], now: now, calendar: cal)
        precondition(ViewKit.evaluate(calc(thisMonth), none) == .unknown)
        precondition(ViewKit.sentence("{left} left", slots: ["left": slots["left"]!], none, locale: en) == nil)
        let empty = ViewKit.Data(series: ["spend": []], now: now, calendar: cal)
        near(ViewKit.evaluate(calc(thisMonth), empty), 0)
        precondition(ViewKit.evaluate(calc(#"{"fn":"mean","metric":"spend"}"#), empty) == .unknown)
        precondition(ViewKit.evaluate(calc(#"{"fn":"div","args":[{"fn":"const","value":1},{"fn":"const","value":0}]}"#), d) == .unknown)
        precondition(ViewKit.evaluate(calc(#"{"fn":"mystery"}"#), d) == .unknown)

        // The manifests the engine accepts decode here, and each block kind is known.
        let dir = URL(fileURLWithPath: CommandLine.arguments[1])
        for name in ["dining_limit", "weight_target", "habit_days", "savings_deadline"] {
            let raw = try Data(contentsOf: dir.appendingPathComponent(name + ".json"))
            struct Manifest: Decodable { var metrics: [Wire.TrackerMetric]; var blocks: [Wire.ViewBlock] }
            let m = try Wire.decoder.decode(Manifest.self, from: raw)
            let view = Wire.GoalView(id: "v", subjectKind: "goal", subjectId: "g", catalogId: TrackerClient.catalog(isPad: false),
                                     metrics: m.metrics, blocks: m.blocks, version: 1)
            precondition(!m.blocks.isEmpty && m.blocks.allSatisfy { view.supports($0) }, name)
        }
        print("view kit checks passed")
    }
}
