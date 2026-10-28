import SwiftUI

struct SessionSidebar: View {
    @Bindable var store: ChatStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Conversations")
                        .font(.mission(.title3, .bold))
                        .foregroundStyle(MissionTheme.ink)
                    Text("\(store.sessions.count) with your assistant")
                        .font(.mission(.caption))
                        .foregroundStyle(MissionTheme.quietText)
                }
                Spacer()
                Button {
                    Task { await store.refreshSessions() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(MissionTheme.quietText)
                        .padding(7)
                        .background(MissionTheme.raised, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.borderless)
                .help("Refresh conversations")
                Button {
                    store.forkSession()
                } label: {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(MissionTheme.quietText)
                        .padding(7)
                        .background(MissionTheme.raised, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.borderless)
                .help("Fork this conversation")
                Button {
                    store.newSession()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(MissionTheme.tint)
                        .padding(7)
                        .background(MissionTheme.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.borderless)
                .help("New conversation")
                .keyboardShortcut("n", modifiers: .command)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            List(selection: Binding(
                get: { store.selectedSessionID },
                set: { store.selectSession($0) }
            )) {
                ForEach(store.sessions) { session in
                    SessionRow(session: session, depth: depth(of: session))
                        .tag(session.sessionID)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .refreshable { await store.refreshSessions() }

            ConnectionFooter(state: store.connectionState)
        }
        .background(MissionTheme.surface)
    }

    /// How many forks deep a conversation sits, capped so a bad parent chain
    /// cannot march off the sidebar.
    private func depth(of session: SessionSummary) -> Int {
        var depth = 0
        var parent = session.parentSessionID
        while let id = parent, depth < 8 {
            depth += 1
            parent = store.sessions.first { $0.sessionID == id }?.parentSessionID
        }
        return depth
    }
}

private struct SessionRow: View {
    let session: SessionSummary
    var depth = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Image(systemName: session.parentSessionID == nil ? "house" : "bubble.left")
                    .foregroundStyle(session.parentSessionID == nil ? MissionTheme.tint : MissionTheme.quietText)
                Text(session.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(MissionTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if session.isRunning {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            if !session.preview.isEmpty {
                Text(session.preview)
                    .font(.mission(.caption))
                    .foregroundStyle(MissionTheme.quietText)
                    .lineLimit(2)
            }
            Text(session.updatedAt.formatted(.relative(presentation: .named)))
                .font(.missionMono(.caption2))
                .foregroundStyle(MissionTheme.quietText)
        }
        .padding(.vertical, 5)
        .padding(.leading, CGFloat(depth) * 12)
        .accessibilityElement(children: .combine)
        .accessibilityValue(session.parentSessionID == nil ? "Root conversation" : "Forked conversation")
    }
}

private struct ConnectionFooter: View {
    let state: ConnectionState

    private var value: (String, Color) {
        switch state {
        case .live: ("Live", MissionTheme.tint)
        case .connecting: ("Connecting", MissionTheme.attention)
        case .reconnecting: ("Reconnecting", MissionTheme.attention)
        case .offline: ("Offline · history recovery active", MissionTheme.quietText)
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(value.1).frame(width: 7, height: 7)
            Text(value.0).font(.mission(.caption)).foregroundStyle(MissionTheme.quietText)
            Spacer()
        }
        .padding(12)
        .background(MissionTheme.raised)
        .overlay(alignment: .top) { Divider().overlay(MissionTheme.line) }
    }
}
