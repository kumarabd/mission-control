import HealthKit
import SwiftUI

/// Read-only Apple Health summary. Health records remain on the device and are
/// deliberately kept outside the assistant gateway and conversation history.
struct HealthSpaceView: View {
    @StateObject private var health = AppleHealthSummaryStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Apple Health summary")
                .font(.mission(.title3, .bold))
            Text("Mission Control reads only the health data you choose. It stays on this device and is never sent to your assistant or gateway.")
                .font(.mission(.subheadline))
                .foregroundStyle(MissionTheme.quietText)

            switch health.access {
            case .notRequested:
                accessPrompt
            case .requesting:
                ProgressView("Connecting Apple Health…")
                    .frame(maxWidth: .infinity, minHeight: 120)
            case .available:
                summary
            case .unavailable:
                ContentUnavailableView(
                    "Apple Health isn’t available",
                    systemImage: "heart.slash",
                    description: Text("Health data can be viewed only on a device with Apple Health available.")
                )
            case .failed:
                ContentUnavailableView(
                    "Health data couldn’t load",
                    systemImage: "exclamationmark.heart",
                    description: Text("Check your Apple Health permissions, then try again.")
                )
                refreshButton
            }
        }
        .task { await health.restoreAndRefresh() }
    }

    private var accessPrompt: some View {
        MissionCard(tint: MissionTheme.health.opacity(0.10)) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Connect Apple Health", systemImage: "heart.text.square")
                    .font(.mission(.headline))
                    .foregroundStyle(MissionTheme.health)
                Text("Choose whether Mission Control can read today’s steps, active energy, exercise minutes, and your most recent resting heart rate. You can change this in Apple Health at any time.")
                    .font(.mission(.subheadline))
                    .foregroundStyle(MissionTheme.quietText)
                Button("Connect Apple Health") {
                    Task { await health.requestAccess() }
                }
                .buttonStyle(.borderedProminent)
                .tint(MissionTheme.health)
                .frame(minHeight: 44)
                .accessibilityHint("Asks for permission to read selected Apple Health data")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today")
                    .font(.mission(.headline))
                Spacer()
                refreshButton
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                HealthMetricCard(metric: health.snapshot.steps)
                HealthMetricCard(metric: health.snapshot.activeEnergy)
                HealthMetricCard(metric: health.snapshot.exerciseMinutes)
                HealthMetricCard(metric: health.snapshot.restingHeartRate)
            }
            Text("These are personal records, not a medical assessment. For care or urgent symptoms, use an appropriate health professional or emergency service.")
                .font(.mission(.caption))
                .foregroundStyle(MissionTheme.quietText)
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await health.refresh() }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .font(.mission(.subheadline, .semibold))
                .frame(minHeight: 44)
        }
        .disabled(health.access == .requesting)
        .accessibilityHint("Reads the latest permitted Apple Health data")
    }
}

private struct HealthMetricCard: View {
    let metric: HealthMetric

    var body: some View {
        MissionCard(tint: MissionTheme.surface) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: metric.symbol)
                    .font(.mission(.title3))
                    .foregroundStyle(MissionTheme.health)
                    .accessibilityHidden(true)
                Text(metric.title)
                    .font(.mission(.subheadline, .semibold))
                Text(metric.value)
                    .font(.mission(.title2, .bold))
                    .monospacedDigit()
                Text(metric.detail)
                    .font(.mission(.caption))
                    .foregroundStyle(MissionTheme.quietText)
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct HealthSnapshot {
    var steps = HealthMetric(title: "Steps", value: "—", detail: "Today", symbol: "figure.walk")
    var activeEnergy = HealthMetric(title: "Active energy", value: "—", detail: "Today", symbol: "flame")
    var exerciseMinutes = HealthMetric(title: "Exercise", value: "—", detail: "Today", symbol: "figure.run")
    var restingHeartRate = HealthMetric(title: "Resting heart rate", value: "—", detail: "Most recent", symbol: "heart")
}

private struct HealthMetric {
    let title: String
    let value: String
    let detail: String
    let symbol: String
}

@MainActor
private final class AppleHealthSummaryStore: ObservableObject {
    enum Access {
        case notRequested, requesting, available, unavailable, failed
    }

    @Published private(set) var access: Access = .notRequested
    @Published private(set) var snapshot = HealthSnapshot()

    private let healthStore = HKHealthStore()
    private let requestRecordedKey = "missionAppleHealthReadAccessRequested"

    func restoreAndRefresh() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            access = .unavailable
            return
        }
        guard UserDefaults.standard.bool(forKey: requestRecordedKey) else { return }
        access = .available
        await refresh()
    }

    func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            access = .unavailable
            return
        }
        access = .requesting
        do {
            try await requestReadAuthorization()
            UserDefaults.standard.set(true, forKey: requestRecordedKey)
            access = .available
            await refresh()
        } catch {
            access = .failed
        }
    }

    func refresh() async {
        guard access == .available else { return }
        // Health permissions are granular. A type that has no records, or was
        // not permitted, must leave only that card empty — never hide the
        // other permitted panels behind a global loading error.
        async let steps = bestEffortCumulativeValue(for: .stepCount, unit: .count())
        async let energy = bestEffortCumulativeValue(for: .activeEnergyBurned, unit: .kilocalorie())
        async let exercise = bestEffortCumulativeValue(for: .appleExerciseTime, unit: .minute())
        async let restingHeartRate = bestEffortMostRecentValue(for: .restingHeartRate, unit: .count().unitDivided(by: .minute()))

        let loaded = await (steps, energy, exercise, restingHeartRate)
        snapshot = HealthSnapshot(
            steps: metric(title: "Steps", raw: loaded.0, detail: "Today", symbol: "figure.walk", formatter: { $0.formatted(.number.grouping(.automatic)) }),
            activeEnergy: metric(title: "Active energy", raw: loaded.1, detail: "Today", symbol: "flame", formatter: { "\(Int($0.rounded())) kcal" }),
            exerciseMinutes: metric(title: "Exercise", raw: loaded.2, detail: "Today", symbol: "figure.run", formatter: { "\(Int($0.rounded())) min" }),
            restingHeartRate: metric(title: "Resting heart rate", raw: loaded.3, detail: "Most recent", symbol: "heart", formatter: { "\(Int($0.rounded())) bpm" })
        )
    }

    private func metric(title: String, raw: Double?, detail: String, symbol: String, formatter: (Double) -> String) -> HealthMetric {
        HealthMetric(title: title, value: raw.map(formatter) ?? "—", detail: raw == nil ? "No data available" : detail, symbol: symbol)
    }

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.restingHeartRate),
        ]
    }

    private func requestReadAuthorization() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthAccessError.authorizationNotCompleted)
                }
            }
        }
    }

    private func cumulativeValue(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        let type = HKQuantityType(identifier)
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func bestEffortCumulativeValue(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        try? await cumulativeValue(for: identifier, unit: unit)
    }

    private func mostRecentValue(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        let type = HKQuantityType(identifier)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func bestEffortMostRecentValue(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        try? await mostRecentValue(for: identifier, unit: unit)
    }

    private enum HealthAccessError: Error {
        case authorizationNotCompleted
    }
}
