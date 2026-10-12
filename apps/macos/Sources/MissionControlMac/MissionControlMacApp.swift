import SwiftUI
import ClerkKit

@main
struct MissionControlMacApp: App {
    init() {
        MissionFonts.register()
        AppConfiguration.configureAuthentication()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(Clerk.shared)
                .frame(minWidth: 900, minHeight: 620)
                .tint(MissionTheme.tint)
                .onOpenURL { url in
                    Task { try? await Clerk.shared.handle(url) }
                }
        }
        .defaultSize(width: 1180, height: 780)
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
