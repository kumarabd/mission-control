import SwiftUI

struct SessionSidebar: View {
    @Bindable var store: ChatStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MISSION CONTROL")
                        .font(.mission(.caption2, .semibold))
                        .tracking(1.4)
                        .foregroundStyle(MissionTheme.quietText)
                    Text("Conversations")
                        .font(.mission(.title3, .bold))
                        .foregroundStyle(MissionTheme.ink)
                }
                Spacer()
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
                    SessionRow(session: session)
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
}

private struct SessionRow: View {
    let session: SessionSummary

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
        }
        .padding(.vertical, 5)
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
