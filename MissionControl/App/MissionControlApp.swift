import SwiftUI
import SwiftData

@main
struct MissionControlApp: App {
    private let modelContainer: ModelContainer = {
        let schema = Schema([MissionTask.self])
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()

    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        .modelContainer(modelContainer)
    }
}
