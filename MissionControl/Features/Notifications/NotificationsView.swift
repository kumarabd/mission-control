import SwiftUI

/// What the assistant has sent: reminders it spoke about, routine nudges it acted on, schedule results, goal
/// check-ins. The list is the gateway's inbox, newest first; opening one marks it read and follows its link to the
/// record it is about.
struct NotificationsView: View {
    @Environment(NotificationsModel.self) private var model
    /// What the parent does with a tapped row: leave this screen, then open the record.
    let open: (PushLink.Target) -> Void

    var body: some View {
        Group {
            if !model.available {
                EmptyState(symbol: "icloud.slash", title: "Notifications need your workspace",
                           message: "They are kept with your assistant, which isn't reachable right now.")
            } else if model.loading && !model.loaded {
                ProgressView("Loading notifications…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.items.isEmpty, let failure = model.failure {
                EmptyState(symbol: "wifi.exclamationmark", title: "Couldn't load notifications", message: failure,
                           actionTitle: "Try again") { Task { await model.refresh() } }
            } else if model.items.isEmpty {
                EmptyState(symbol: "tray", title: "Nothing yet",
                           message: "Reminders, nudges and check-ins your assistant speaks about appear here.")
            } else {
                list
            }
        }
        .readableWidth()
        .screenBackground()
        .navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
        .task { if !model.loaded { await model.refresh() } }
        .toolbar {
            if model.unread > 0 {
                ToolbarItem(placement: .primaryAction) {
                    Button("Mark all read") { Task { await model.markAllRead() } }.frame(minHeight: 44)
                }
            }
        }
    }

    private var list: some View {
        List {
            if let failure = model.failure {
                Section {
                    Text(failure).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                    Button("Try again") { Task { await model.refresh() } }.frame(minHeight: 44)
                }.listRowBackground(Tok.surface)
            }
            Section {
                ForEach(model.items) { item in
                    Button {
                        Task {
                            await model.markRead(item)
                            if let target = target(for: item) { open(target) }
                        }
                    } label: { row(item) }
                    .buttonStyle(.borderless)
                    .listRowBackground(Tok.surface)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if item.isUnread {
                            Button("Mark read", systemImage: "checkmark.circle") { Task { await model.markRead(item) } }
                                .tint(Tok.accent)
                        }
                    }
                }
                if model.hasMore {
                    Button(model.loading ? "Loading…" : "More") { Task { await model.loadMore() } }
                        .frame(minHeight: 44).disabled(model.loading)
                }
            } footer: {
                Text("Sent by your assistant. Nudges it decided against were never sent, so they are not listed.")
                    .font(.mission(.footnote))
            }
        }
        .scrollContentBackground(.hidden).screenBackground()
        .refreshable { await model.refresh() }
    }

    private func row(_ item: NotificationsAPI.Item) -> some View {
        HStack(alignment: .top, spacing: Space.s) {
            Circle().fill(Tok.accent).frame(width: 8, height: 8)
                .padding(.top, 6).opacity(item.isUnread ? 1 : 0)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(item.title)
                    .font(.mission(.body, item.isUnread ? .medium : .regular))
                    .foregroundStyle(item.isUnread ? Tok.text : Tok.muted)
                    .multilineTextAlignment(.leading)
                if !item.body.isEmpty {
                    Text(item.body).font(.mission(.subheadline)).foregroundStyle(Tok.muted)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                Text(time(item))
                    .font(.missionMono(.caption)).foregroundStyle(Tok.muted)
            }
            Spacer(minLength: 0)
            if target(for: item) != nil {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Tok.muted).padding(.top, 4)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.isUnread ? "Unread" : "Read")
    }

    private func target(for item: NotificationsAPI.Item) -> PushLink.Target? {
        guard let link = item.link, let section = PushLink.section(for: link.entity) else { return nil }
        return PushLink.Target(entity: link.entity, id: link.id, section: section)
    }

    private func time(_ item: NotificationsAPI.Item) -> String {
        let date = item.createdAt.formatted(date: Calendar.current.isDateInToday(item.createdAt) ? .omitted : .abbreviated,
                                            time: .shortened)
        return item.priority == "high" ? "High priority · \(date)" : date
    }
}
