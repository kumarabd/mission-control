import SwiftUI
import SwiftData
import ClerkKit

@main
struct MissionControlApp: App {
    private let modelContainer: ModelContainer = {
        let schema = Schema([MissionTask.self])
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()

    init() {
        ClerkConfiguration.configure()
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(Clerk.shared)
                .onOpenURL { url in
                    Task { try? await Clerk.shared.handle(url) }
                }
        }
        .modelContainer(modelContainer)
    }
}
