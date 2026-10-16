import Foundation

extension Wire {
    struct TrackerMetric: Codable, Equatable, Identifiable {
        var id: String; var label: String; var unit: String
        var target: Double?; var minimum: Double?; var maximum: Double?
        func accepts(_ value: Double) -> Bool {
            value.isFinite && (minimum.map { value >= $0 } ?? true) && (maximum.map { value <= $0 } ?? true)
        }
    }
    struct TrackerSection: Codable, Equatable, Identifiable {
        var id: String; var type: String; var title: String; var metricId: String?
    }
    struct TrackerView: Codable, Equatable {
        var catalogId: String; var sections: [TrackerSection]
        func isSupported(catalog: String, metrics: [TrackerMetric]) -> Bool {
            guard catalogId == catalog, (1...8).contains(sections.count), Set(sections.map(\.id)).count == sections.count else { return false }
            return sections.allSatisfy { section in
                switch section.type {
                case "metric_trend", "check_in": return metrics.contains { $0.id == section.metricId }
                case "milestones", "routine_consistency": return section.metricId == nil
                default: return false
                }
            }
        }
    }
    struct TrackerDefinition: Codable, Equatable {
        var metrics: [TrackerMetric]? // Nil is also valid for a milestones-only tracker.
        var views: [TrackerView]
    }
    struct TrackerProposal: Codable, Equatable, Identifiable {
        var id: String; var goalId: String; var baseGoalVersion: Int; var baseTrackerRevision: Int
        var definition: TrackerDefinition; var reason: String; var state: String; var version: Int
        var createdAt: Date; var updatedAt: Date
    }
    struct GoalMeasurement: Codable, Equatable, Identifiable {
        var id: String; var goalId: String; var metricId: String; var unit: String; var value: Double
        var measuredAt: Date; var notes: String; var version: Int
        var deletedAt: Date?; var createdAt: Date; var updatedAt: Date
    }
    struct TrackerState: Codable, Equatable {
        var goalId: String; var goalVersion: Int; var trackerRevision: Int; var catalogId: String
        var view: TrackerView?; var metrics: [TrackerMetric]?; var measurements: [GoalMeasurement]; var proposals: [TrackerProposal]
        var metricDefinitions: [TrackerMetric] { metrics ?? [] }
        func supportedView(catalog: String) -> TrackerView? {
            guard catalogId == catalog, let view, view.isSupported(catalog: catalog, metrics: metricDefinitions) else { return nil }
            return view
        }
        func observations(for metric: String) -> [GoalMeasurement] {
            measurements.filter { $0.metricId == metric && $0.deletedAt == nil }.sorted { $0.measuredAt < $1.measuredAt }
        }
    }
}

/// One app/platform identity for native rendering.
enum TrackerClient {
    static func catalog(isPad: Bool) -> String { "mission-control.\(isPad ? "ipados" : "ios").goal-tracker.v1" }
    static func number(_ text: String, locale: Locale = .current) -> Double? {
        let scanner = Scanner(string: text.trimmingCharacters(in: .whitespacesAndNewlines))
        scanner.locale = locale
        guard let value = scanner.scanDouble(), scanner.isAtEnd, value.isFinite else { return nil }
        return value
    }
}
