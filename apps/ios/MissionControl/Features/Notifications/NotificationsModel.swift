import Foundation
import Observation

/// The notification inbox: what the assistant has sent, newest first, with its read state. Generation-guarded like
/// `MemoryModel`, so a slow page cannot overwrite a newer one.
@MainActor @Observable
final class NotificationsModel {
    private(set) var items: [NotificationsAPI.Item] = []
    private(set) var unread = 0
    private(set) var loaded = false
    private(set) var loading = false
    private(set) var hasMore = false
    /// False in developer mode or with no router configured: the inbox is a gateway route, and the dev world does not
    /// serve it.
    private(set) var available = false
    private(set) var failure: String?

    private var nextBefore: String?
    private var generation = 0
    private var api: NotificationsAPI?

    func attach(_ api: NotificationsAPI?) {
        self.api = api
        available = api != nil
    }

    func refresh() async {
        guard let api else { return }
        generation += 1
        let current = generation
        loading = true; failure = nil
        defer { if current == generation { loading = false } }
        do {
            let page = try await api.page()
            guard !Task.isCancelled, current == generation else { return }
            items = page.items; unread = page.unread; nextBefore = page.nextBefore; hasMore = page.nextBefore != nil
            loaded = true
        } catch {
            // Keep what is on screen; a failed refresh is not an empty inbox.
            guard !Task.isCancelled, current == generation else { return }
            failure = Self.message(error)
        }
    }

    func loadMore() async {
        guard let api, !loading, hasMore, let before = nextBefore else { return }
        let current = generation
        loading = true
        defer { if current == generation { loading = false } }
        do {
            let page = try await api.page(before: before)
            guard !Task.isCancelled, current == generation else { return }
            let known = Set(items.map(\.id))
            items += page.items.filter { !known.contains($0.id) }
            unread = page.unread; nextBefore = page.nextBefore; hasMore = page.nextBefore != nil
            failure = nil
        } catch {
            guard !Task.isCancelled, current == generation else { return }
            failure = Self.message(error)
        }
    }

    /// Read is marked when the person opens one, not when the list is shown — the unread count is the point of the badge.
    func markRead(_ item: NotificationsAPI.Item) async {
        guard let api, let index = items.firstIndex(where: { $0.id == item.id }), items[index].isUnread else { return }
        items[index].readAt = Date()
        unread = max(0, unread - 1)
        do { try await api.markRead(item.id) } catch { failure = Self.message(error); await refresh() }
    }

    func markAllRead() async {
        guard let api, unread > 0 else { return }
        do {
            let marked = try await api.markAllRead()
            let now = Date()
            for index in items.indices where items[index].isUnread { items[index].readAt = now }
            unread = max(0, unread - marked)
            failure = nil
        } catch { failure = Self.message(error) }
    }

    private static func message(_ error: Error) -> String {
        switch error as? NotificationsError {
        case .unauthorized: "Please sign in again."
        case .server(_, let message): message.isEmpty ? "Notifications aren't available right now." : message
        default: "You're offline, or the service is busy. Try again in a moment."
        }
    }
}
