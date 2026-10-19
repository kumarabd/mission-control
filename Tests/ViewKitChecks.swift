import Foundation

/// The view kit's calculations, run against the vectors every client's evaluator must pass
/// (Tests/Fixtures/views/viewkit-vectors.json, from the engine), and the engine's example manifests.
@main struct ViewKitChecks {
    static func main() throws {
        let dir = URL(fileURLWithPath: CommandLine.arguments[1])
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!; cal.firstWeekday = 2
        let en = Locale(identifier: "en_US")
        let iso = ISO8601DateFormatter()
        let dayFormat = DateFormatter()
        dayFormat.calendar = cal; dayFormat.timeZone = cal.timeZone; dayFormat.locale = Locale(identifier: "en_US_POSIX"); dayFormat.dateFormat = "yyyy-MM-dd"

        let vectors = try JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("viewkit-vectors.json"))) as! [String: Any]
        let now = iso.date(from: vectors["now"] as! String)!
        func data(_ name: String) -> ViewKit.Data {
            let sets = (vectors["datasets"] as! [String: Any])[name] as! [String: [[Any]]]
            return ViewKit.Data(series: sets.mapValues { rows in
                rows.map { ViewKit.Point(date: ViewKit.parse($0[0] as! String, calendar: cal)!, value: ($0[1] as! NSNumber).doubleValue) }
            }, now: now, calendar: cal)
        }
        func decode<T: Decodable>(_ any: Any, _ type: T.Type) -> T { try! JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: any, options: .fragmentsAllowed)) }

        for c in vectors["cases"] as! [[String: Any]] {
            let name = c["name"] as! String
            let got = ViewKit.evaluate(decode(c["calc"]!, Wire.Calc.self), data(c["data"] as! String))
            switch c["expect"]! {
            case let word as String where word == "unknown": precondition(got == .unknown, "\(name): got \(got)")
            case let day as String: precondition(got.date.map(dayFormat.string) == day, "\(name): wanted \(day), got \(got)")
            case let n as NSNumber:
                let eps = (c["eps"] as? NSNumber)?.doubleValue ?? 0.01
                precondition(got.number.map { abs($0 - n.doubleValue) <= eps } == true, "\(name): wanted \(n), got \(got)")
            default: preconditionFailure(name)
            }
        }
        for s in vectors["sentences"] as! [[String: Any]] {
            let slots = decode(s["slots"]!, [String: Wire.Slot].self)
            let got = ViewKit.sentence(s["text"] as! String, slots: slots, data(s["data"] as! String), locale: en)
            precondition(got == (s["expect"] as? String), "\(s["name"]!): got \(String(describing: got))")
        }
        for b in vectors["buckets"] as! [[String: Any]] {
            let window = b["window"].map { decode($0, Wire.Window.self) }
            let got = ViewKit.bucketed(b["metric"] as! String, window: window, bucket: b["bucket"] as? String, aggregate: b["aggregate"] as? String, data(b["data"] as! String))
            precondition(got?.map(\.value) == (b["expect"] as! [NSNumber]).map(\.doubleValue), "\(b["name"]!)")
        }

        // The manifests the engine accepts decode here, and each block kind is known.
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
