import SwiftUI
import ClerkKit

@main
struct MissionControlApp: App {
    init() {
        MissionFonts.register()
        AppConfiguration.configureAuthentication()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(Clerk.shared)
                .frame(minWidth: 1000, minHeight: 680)
                .tint(MissionTheme.tint)
                .onOpenURL { url in
                    Task { try? await Clerk.shared.handle(url) }
                }
        }
        .defaultSize(width: 1320, height: 840)
        .commands {
            SidebarCommands()
        }

        Settings {
            SettingsView()
                .environment(Clerk.shared)
                .tint(MissionTheme.tint)
        }
    }
}
