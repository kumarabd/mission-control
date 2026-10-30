import SwiftUI

struct SessionSidebar: View {
    @Bindable var store: ChatStore
    @State private var expanded: Set<String> = []

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
                ForEach(orderedRows) { row in
                    SessionRow(
                        session: row.session,
                        depth: row.depth,
                        childCount: row.childCount,
                        isExpanded: expanded.contains(row.id),
                        onToggle: { toggleExpanded(row.id) }
                    )
                    .tag(row.session.sessionID)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .refreshable { await store.refreshSessions() }
            .onChange(of: store.selectedSessionID) { _, sessionID in
                expandAncestors(of: sessionID)
            }

            ConnectionFooter(state: store.connectionState)
        }
        .background(MissionTheme.surface)
    }

    /// Latest-first at every level, with forks nested directly under their
    /// parent. A fork is listed only when every ancestor folder is expanded.
    /// Depth is capped so a bad parent chain cannot march off the sidebar.
    private var orderedRows: [OrderedSession] {
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

        var rows: [(session: SessionSummary, depth: Int)] = []
        var seen = Set<String>()
        func visit(_ session: SessionSummary, _ depth: Int) {
            guard seen.insert(session.sessionID).inserted else { return }
            rows.append((session, depth))
            for child in children[session.sessionID] ?? [] { visit(child, min(depth + 1, 8)) }
        }
        roots.forEach { visit($0, 0) }
        for session in sessions { visit(session, 0) } // a malformed parent cycle still gets listed, once

        func isOpen(_ session: SessionSummary) -> Bool {
            var parent = session.parentSessionID
            var hops = 0
            while let id = parent, hops < 8 {
                guard expanded.contains(id) else { return false }
                guard let ancestor = byID[id] else { return true }
                parent = ancestor.parentSessionID
                hops += 1
            }
            return true
        }
        return rows.filter { isOpen($0.session) }.map { row in
            OrderedSession(
                session: row.session,
                depth: row.depth,
                childCount: children[row.session.sessionID]?.count ?? 0
            )
        }
    }

    private func toggleExpanded(_ sessionID: String) {
        if expanded.contains(sessionID) { expanded.remove(sessionID) }
        else { expanded.insert(sessionID) }
    }

    /// A newly forked or selected child must not be hidden inside a collapsed
    /// folder, so its ancestors open with it.
    private func expandAncestors(of sessionID: String) {
        var parent = store.sessions.first { $0.sessionID == sessionID }?.parentSessionID
        var hops = 0
        while let id = parent, hops < 8 {
            expanded.insert(id)
            parent = store.sessions.first { $0.sessionID == id }?.parentSessionID
            hops += 1
        }
    }
}

private struct OrderedSession: Identifiable {
    let session: SessionSummary
    let depth: Int
    let childCount: Int

    var id: String { session.sessionID }
}

private struct SessionRow: View {
    let session: SessionSummary
    var depth = 0
    var childCount = 0
    var isExpanded = false
    var onToggle: () -> Void = {}

    private var isChild: Bool { depth > 0 }

    var body: some View {
        HStack(spacing: 5) {
            if childCount > 0 {
                Button(action: onToggle) {
                    Image(systemName: "chevron.right")
                        .font(.mission(.caption2))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(MissionTheme.quietText)
                        .frame(width: 12, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help(isExpanded ? "Collapse forks" : "Expand forks")
                .accessibilityLabel(isExpanded ? "Collapse forks" : "Expand forks")
            } else {
                Color.clear
                    .frame(width: 12, height: 12)
            }
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
        .accessibilityElement(children: childCount > 0 ? .contain : .combine)
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
