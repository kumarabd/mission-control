import SwiftUI

/// Where long-running things live: routines you keep doing, and goals you are working toward.
struct ProgressTab: View {
    var onSettings: () -> Void = {}
    @Environment(Life.self) private var life
    @State private var segment = Segment.goals
    @State private var sheet: Sheet?
    @State private var path = NavigationPath()

    enum Segment: String, CaseIterable, Identifiable { case goals = "Goals", routines = "Routines"; var id: Self { self } }
    enum Sheet: Identifiable { case routine, goal; var id: Self { self } }

    var body: some View {
        NavigationStack(path: $path) {
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
            .screenBackground().safeAreaPadding(.bottom, 80)
            .navigationTitle(segment.rawValue)
            .navigationDestination(for: GoalRef.self) { GoalDetail(goalID: $0.id) }
            .onAppear { openLink(DeepLink.shared.pending) }
            .onChange(of: DeepLink.shared.pending) { _, target in openLink(target) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "person.crop.circle", action: onSettings).frame(minWidth: 44, minHeight: 44)
                }
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

    /// A tapped notification for a goal opens it.
    private func openLink(_ target: PushLink.Target?) {
        guard let target, target.entity == "goal" else { return }
        segment = .goals
        path = NavigationPath([GoalRef(id: target.id)])
        DeepLink.shared.pending = nil
    }
}
