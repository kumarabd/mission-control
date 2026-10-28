import SwiftUI

/// Memory at desktop width. The World/About you lenses live under Memory in the
/// main sidebar, so the graph gets the whole detail column instead of a second
/// navigation list inside the screen.
struct MemoryScreen: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(MemoryModel.self) private var model

    private var service: MemoryService { workspace.memoryService }

    var body: some View {
        NavigationStack {
            Group {
                switch workspace.memoryLens {
                case .world:
                    WorldScreen(service: service, initial: model.world) { entity in
                        workspace.discuss(entity.map { "About \($0) in my world: " }
                                          ?? "About the people, places and things in my world: ")
                    }
                case .aboutYou:
                    AboutYouComingSoon {
                        workspace.discuss("About what you remember and understand about me: ")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(workspace.memoryLens.title)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { workspace.discuss("About what you remember and understand about me: ") } label: {
                        Label("Discuss memory", systemImage: "bubble.left")
                    }
                    .help("Discuss what memory holds with the assistant")
                    if workspace.memoryLens == .world {
                        Button { Task { await model.loadWorld(service: service, force: true) } } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .keyboardShortcut("r", modifiers: .command)
                    }
                }
            }
        }
        .task { await model.loadWorld(service: service) }
        .onChange(of: workspace.chat.completedTurns) { _, _ in
            Task { await model.loadWorld(service: service, force: true) }
        }
    }
}

/// The About you lens is not formed yet; the assistant can still answer
/// directly, so the placeholder offers that next step.
struct AboutYouComingSoon: View {
    var onDiscuss: () -> Void

    var body: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 36))
                .foregroundStyle(Tok.accent.opacity(0.8))
                .accessibilityHidden(true)
            Text("About you is coming soon")
                .font(.mission(.title3, .semibold))
            Text("When it is ready, your assistant's understanding of who you are and how you like to work will appear here. Until then, ask it directly in Chat.")
                .font(.mission(.body))
                .foregroundStyle(Tok.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("Talk with your assistant", action: onDiscuss)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tok.background)
        .navigationTitle("About you")
    }
}
