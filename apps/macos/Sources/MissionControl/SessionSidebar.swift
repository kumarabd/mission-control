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
                ForEach(orderedSessions, id: \.session.sessionID) { row in
                    SessionRow(session: row.session, depth: row.depth)
                        .tag(row.session.sessionID)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .refreshable { await store.refreshSessions() }

            ConnectionFooter(state: store.connectionState)
        }
        .background(MissionTheme.surface)
    }

    /// Latest-first at every level, with forks nested directly under their
    /// parent. Depth is capped so a bad parent chain cannot march off the
    /// sidebar.
    private var orderedSessions: [(session: SessionSummary, depth: Int)] {
        let sessions = store.sessions
        var byID: [String: SessionSummary] = [:]
        for session in sessions { byID[session.sessionID] = session }
        var children: [String: [SessionSummary]] = [:]
        var roots: [SessionSummary] = []
        for session in sessions {
            if let parent = session.parentSessionID, parent != session.sessionID, byID[parent] != nil {
                children[parent, default: []].append(session)
            } else {
                roots.append(session)
            }
        }
        let latestFirst: (SessionSummary, SessionSummary) -> Bool = { $0.updatedAt > $1.updatedAt }
        roots.sort(by: latestFirst)
        for key in children.keys { children[key]?.sort(by: latestFirst) }

        var ordered: [(session: SessionSummary, depth: Int)] = []
        var seen = Set<String>()
        func visit(_ session: SessionSummary, _ depth: Int) {
            guard seen.insert(session.sessionID).inserted else { return }
            ordered.append((session, depth))
            for child in children[session.sessionID] ?? [] { visit(child, min(depth + 1, 8)) }
        }
        roots.forEach { visit($0, 0) }
        for session in sessions { visit(session, 0) } // a malformed parent cycle still gets listed, once
        return ordered
    }
}

private struct SessionRow: View {
    let session: SessionSummary
    var depth = 0

    private var isChild: Bool { depth > 0 }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: session.parentSessionID == nil ? "house" : "bubble.left")
                .font(.mission(.caption2))
                .foregroundStyle(session.parentSessionID == nil ? MissionTheme.tint : MissionTheme.quietText)
            Text(session.title)
                .font(.mission(isChild ? .caption : .callout))
                .fontWeight(isChild ? .regular : .semibold)
                .foregroundStyle(MissionTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            if session.isRunning {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Text(session.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.missionMono(.caption2))
                    .foregroundStyle(MissionTheme.quietText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, isChild ? 1 : 4)
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
