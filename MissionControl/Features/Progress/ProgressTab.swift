import SwiftUI

/// Where long-running things live: routines you keep doing, and goals you are working toward.
struct ProgressTab: View {
    @Environment(Life.self) private var life
    @State private var segment = Segment.routines
    @State private var sheet: Sheet?

    enum Segment: String, CaseIterable, Identifiable { case routines = "Routines", goals = "Goals"; var id: Self { self } }
    enum Sheet: Identifiable { case routine, goal; var id: Self { self } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Show", selection: $segment) {
                    ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).padding(.horizontal, Space.l).padding(.vertical, Space.s)
                switch segment {
                case .routines: RoutinesList { sheet = .routine }
                case .goals: GoalsList { sheet = .goal }
                }
            }
            .screenBackground()
            .navigationTitle("Progress")
            .navigationDestination(for: GoalRef.self) { GoalDetail(goalID: $0.id) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { sheet = segment == .routines ? .routine : .goal } label: { Image(systemName: "square.and.pencil").frame(minWidth: 44, minHeight: 44) }
                        .accessibilityLabel(segment == .routines ? "New routine" : "New goal")
                }
            }
            .sheet(item: $sheet) { s in
                switch s {
                case .routine: NewRoutineSheet().environment(life)
                case .goal: CaptureSheet(draft: "I want to ").environment(life)
                }
            }
        }
    }
}
