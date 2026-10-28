import SwiftUI

/// The assistant's inbox at desktop detail. The gateway serves the same feed
/// the phone lists; this surface adds the web console's page grammar, filters
/// and row affordances so a Mac can scan a long inbox.
struct NotificationsScreen: View {
    @Environment(WorkspaceModel.self) private var workspace

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All", unread = "Unread"
        var id: String { rawValue }
    }

    @State private var filter = Filter.all

    private var model: NotificationsModel { workspace.notifications }

    private var visible: [NotificationsAPI.Item] {
        filter == .unread ? model.items.filter(\.isUnread) : model.items
    }

    var body: some View {
        VStack(spacing: 0) {
            ConsolePageHeader(
                "Notifications",
                eyebrow: "Inbox",
                description: "What your assistant has sent: check-ins, schedule results, and updates about your plans."
            ) {
                if model.unread > 0 {
                    Button {
                        Task { await model.markAllRead() }
                    } label: {
                        Label("Mark all read", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.loading)
                }
                Button { Task { await model.refresh() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("r", modifiers: .command)
            }

            filterRow
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Tok.background)
        .navigationTitle("Notifications")
        .task { if !model.loaded { await model.refresh() } }
    }

    private var filterRow: some View {
        HStack(spacing: Space.s) {
            ForEach(Filter.allCases) { item in
                let count = item == .all ? model.items.count : model.unread
                Button {
                    filter = item
                } label: {
                    HStack(spacing: 6) {
                        Text(item.rawValue)
                            .font(.mission(.subheadline, filter == item ? .medium : .regular))
                        Text("\(count)")
                            .font(.missionMono(.caption2, .medium))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                (filter == item ? Tok.accent.opacity(0.16) : Tok.raised),
                                in: Capsule())
                    }
                    .foregroundStyle(filter == item ? Tok.accent : Tok.muted)
                    .padding(.horizontal, Space.m)
                    .frame(minHeight: 30)
                    .background(filter == item ? Tok.accent.opacity(0.08) : .clear, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(filter == item ? Tok.accent.opacity(0.35) : Tok.hairline)
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.rawValue), \(count)")
                .accessibilityAddTraits(filter == item ? .isSelected : [])
            }
            Spacer(minLength: 0)
            if model.unread > 0 {
                Text("\(model.unread) unread")
                    .font(.missionMono(.caption))
                    .foregroundStyle(Tok.muted)
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.m)
    }

    @ViewBuilder private var content: some View {
        if !model.available {
            empty("Notifications need your workspace",
                  detail: "They are kept with your assistant, which isn't reachable right now.",
                  symbol: "icloud.slash")
        } else if model.loading && !model.loaded {
            ConsolePanel {
                ConsoleSkeletonRows(count: 5)
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
        } else if model.items.isEmpty, let failure = model.failure {
            ConsoleNotice(title: "Couldn't load notifications", message: failure) {
                Task { await model.refresh() }
            }
            .padding(.horizontal, Space.xl)
            .padding(.bottom, Space.xl)
        } else if model.items.isEmpty {
            empty("Nothing yet",
                  detail: "Reminders, nudges and check-ins your assistant speaks about appear here.",
                  symbol: "tray")
        } else {
            VStack(spacing: Space.s) {
                if let failure = model.failure {
                    ConsoleNotice(title: "The latest refresh didn't land", message: failure) {
                        Task { await model.refresh() }
                    }
                    .padding(.horizontal, Space.xl)
                }
                ScrollView {
                    ConsolePanel {
                        LazyVStack(spacing: 0) {
                            if visible.isEmpty {
                                VStack(spacing: Space.xs) {
                                    Text("You're all caught up.")
                                        .font(.mission(.body, .medium))
                                    Text("No unread notifications. Switch to All to read earlier ones.")
                                        .font(.mission(.caption))
                                        .foregroundStyle(Tok.muted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(Space.xl)
                            } else {
                                ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                                    row(item)
                                    if index < visible.count - 1 {
                                        Divider().padding(.leading, 40)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, Space.xs)
                    }
                    .padding(.horizontal, Space.xl)

                    if model.hasMore {
                        Button {
                            Task { await model.loadMore() }
                        } label: {
                            if model.loading {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Load earlier notifications")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.loading)
                        .padding(.vertical, Space.m)
                    }
                }
            }
            .padding(.bottom, Space.m)
        }
    }

    private func row(_ item: NotificationsAPI.Item) -> some View {
        Button {
            Task {
                await model.markRead(item)
                if let target = target(for: item) { workspace.open(target) }
            }
        } label: {
            HStack(alignment: .top, spacing: Space.m) {
                Circle()
                    .fill(item.isUnread ? Tok.accent : .clear)
                    .frame(width: 7, height: 7)
                    .padding(.top, 7)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.mission(.callout, item.isUnread ? .medium : .regular))
                        .foregroundStyle(item.isUnread ? Tok.text : Tok.muted)
                        .multilineTextAlignment(.leading)
                    if !item.body.isEmpty {
                        Text(item.body)
                            .font(.mission(.subheadline))
                            .foregroundStyle(Tok.muted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Text(meta(item))
                        .font(.missionMono(.caption))
                        .foregroundStyle(Tok.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if item.priority == "high" {
                    Text("High")
                        .font(.missionMono(.caption2, .medium))
                        .foregroundStyle(Tok.warn)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Tok.warn.opacity(0.1), in: Capsule())
                }
                if target(for: item) != nil {
                    Image(systemName: "chevron.right")
                        .font(.mission(.caption, .semibold))
                        .foregroundStyle(Tok.muted)
                        .padding(.top, 5)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.m)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight(radius: 0)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.isUnread ? "Unread" : "Read")
    }

    private func meta(_ item: NotificationsAPI.Item) -> String {
        let today = Calendar.current.isDateInToday(item.createdAt)
        let sameYear = Calendar.current.component(.year, from: item.createdAt)
            == Calendar.current.component(.year, from: Date())
        let style: Date.FormatStyle = today
            ? .dateTime.hour().minute()
            : sameYear
                ? .dateTime.month(.abbreviated).day().hour().minute()
                : .dateTime.year().month(.abbreviated).day().hour().minute()
        let when = item.createdAt.formatted(style)
        var parts = [when]
        if item.priority == "high" { parts.insert("High priority", at: 0) }
        if !item.source.isEmpty { parts.append(item.source) }
        return parts.joined(separator: " · ")
    }

    private func target(for item: NotificationsAPI.Item) -> PushLink.Target? {
        guard let link = item.link, let section = PushLink.section(for: link.entity) else { return nil }
        return PushLink.Target(entity: link.entity, id: link.id, section: section)
    }

    private func empty(_ title: String, detail: String, symbol: String) -> some View {
        VStack(spacing: Space.s) {
            Image(systemName: symbol)
                .font(.mission(.title))
                .foregroundStyle(Tok.accent.opacity(0.75))
                .accessibilityHidden(true)
            Text(title).font(.mission(.title3, .semibold))
            Text(detail)
                .font(.mission(.body))
                .foregroundStyle(Tok.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Space.xl)
    }
}

/// Chat, at desktop width: conversations beside the thread.
struct ChatScreen: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        HSplitView {
            SessionSidebar(store: workspace.chat)
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
            ChatView(store: workspace.chat)
                .frame(minWidth: 480)
        }
        .background(Tok.background)
        .onAppear { workspace.chat.isVisible = true }
        .onDisappear { workspace.chat.isVisible = false }
    }
}
