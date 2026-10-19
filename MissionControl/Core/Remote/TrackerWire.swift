import Foundation

extension Wire {
    struct TrackerMetric: Codable, Equatable, Identifiable {
        var id: String; var label: String; var unit: String
        var target: Double?; var minimum: Double?; var maximum: Double?
        /// Where the values come from: a provider's series, or a routine's logs. Neither: the person records them.
        var source: MetricSource?
        var routineId: String?
        func accepts(_ value: Double) -> Bool {
            value.isFinite && (minimum.map { value >= $0 } ?? true) && (maximum.map { value <= $0 } ?? true)
        }
    }
    /// A data provider's series, read live: `provider` is the engine's router prefix (for example `finance`).
    struct MetricSource: Codable, Equatable, Hashable { var provider: String; var series: String; var granularity: String? }

    /// The view kit. A view is composed from a finite set of blocks and calculations; none of it names a kind of goal.
    /// The engine validates a manifest and this client evaluates the calculations on live data, so no figure in a view
    /// was ever written by the model (docs: the engine's tracker_catalog_get).
    struct Window: Codable, Equatable { var period: String?; var days: Int? }
    struct Calc: Codable, Equatable {
        var fn: String
        var metric: String?; var value: Double?; var date: String?
        var window: Window?; var period: String?; var per: String?
        var args: [Calc]?
    }
    struct Slot: Codable, Equatable { var calc: Calc; var format: String; var unit: String?; var decimals: Int? }
    struct Marker: Codable, Equatable { var at: Calc; var label: String }
    struct Band: Codable, Equatable { var from: Calc; var to: Calc; var label: String }
    /// One block of a view. A flat shape: which fields a kind uses is the engine's catalogue.
    struct ViewBlock: Codable, Equatable, Identifiable {
        var id: String; var kind: String; var title: String?; var emphasis: String?
        var text: String?; var slots: [String: Slot]?
        var value: Calc?; var of: Calc?; var markers: [Marker]?; var projection: Calc?
        var metric: String?; var style: String?; var window: Window?; var bucket: String?; var aggregate: String?
        var lines: [Marker]?; var band: Band?; var trendTo: Calc?; var layout: String?; var weeks: Int?
        var source: String?; var thresholds: [Double]?
        var format: String?; var unit: String?; var decimals: Int?
        var body: String?; var url: String?
    }
    /// A goal's view for one client catalogue: a manifest of blocks that refer to the goal and to metrics.
    struct GoalView: Codable, Equatable, Identifiable {
        var id: String; var subjectKind: String; var subjectId: String; var catalogId: String
        var metrics: [TrackerMetric]; var blocks: [ViewBlock]; var version: Int
        var createdAt: Date?; var updatedAt: Date?
        /// A block this client can show. An unknown one is shown as unsupported on its own; it never hides the rest.
        func supports(_ block: ViewBlock) -> Bool {
            let known = Set(["sentence", "bar", "series", "grid", "steps", "timeline", "log", "text", "link"])
            guard known.contains(block.kind) else { return false }
            switch block.kind {
            case "series", "grid", "log": return metrics.contains { $0.id == block.metric }
            case "link": return TrackerClient.link(block.url) != nil
            default: return true
            }
        }
    }
    struct GoalMeasurement: Codable, Equatable, Identifiable {
        var id: String; var goalId: String; var metricId: String; var unit: String; var value: Double
        var measuredAt: Date; var notes: String; var version: Int
        var deletedAt: Date?; var createdAt: Date; var updatedAt: Date
    }
    struct ViewState: Codable, Equatable {
        var goalId: String; var catalogId: String
        var view: GoalView?; var measurements: [GoalMeasurement]
        var metricDefinitions: [TrackerMetric] { view?.metrics ?? [] }
        /// The view for this catalogue, or nil: another app's view is never substituted.
        func view(catalog: String) -> GoalView? {
            guard catalogId == catalog, let view, view.catalogId == catalog, !view.blocks.isEmpty else { return nil }
            return view
        }
        func observations(for metric: String) -> [GoalMeasurement] {
            measurements.filter { $0.metricId == metric && $0.deletedAt == nil }.sorted { $0.measuredAt < $1.measuredAt }
        }
    }
    struct SeriesPoint: Codable, Equatable { var t: String; var value: Double }
    /// Only periods that have records, oldest first. A missing period is a gap, not zero.
    struct SeriesData: Codable, Equatable {
        var provider: String; var series: String; var unit: String; var granularity: String; var points: [SeriesPoint]
    }
}

/// One app/platform identity for native rendering.
enum TrackerClient {
    /// The view kit this client draws. One manifest per goal serves every client; each draws it with its own components.
    static let catalog = "view-kit.v1"
    static func number(_ text: String, locale: Locale = .current) -> Double? {
        let scanner = Scanner(string: text.trimmingCharacters(in: .whitespacesAndNewlines))
        scanner.locale = locale
        guard let value = scanner.scanDouble(), scanner.isAtEnd, value.isFinite else { return nil }
        return value
    }
    /// Only http and https addresses are opened; anything else a stored view carries is ignored.
    static func link(_ text: String?) -> URL? {
        guard let text, let url = URL(string: text), let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http", url.host != nil else { return nil }
        return url
    }
    /// A provider id is a router prefix a stored view names. It becomes part of a URL, so it is checked first.
    static func isProviderID(_ id: String) -> Bool { id.range(of: "^[a-z][a-z0-9_]{0,63}$", options: .regularExpression) != nil }
    /// `finance` -> `Finance`, for display only.
    static func providerLabel(_ id: String) -> String { id.prefix(1).uppercased() + id.dropFirst().replacingOccurrences(of: "_", with: " ") }

    private static func formatter(_ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar; f.timeZone = calendar.timeZone; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return f
    }
    /// The window a bound metric is drawn over: the last `days` days, ending today, as calendar dates.
    static func seriesRange(days: Int = 90, now: Date = Date(), calendar: Calendar = .current) -> (from: String, to: String) {
        let f = formatter(calendar)
        let start = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        return (f.string(from: start), f.string(from: now))
    }
    /// A series point's date, at local noon so a daylight-saving shift cannot move it to another day.
    static func day(_ text: String, calendar: Calendar = .current) -> Date? {
        formatter(calendar).date(from: text).flatMap { calendar.date(bySettingHour: 12, minute: 0, second: 0, of: $0) }
    }
}
