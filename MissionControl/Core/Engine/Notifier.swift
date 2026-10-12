import Foundation
import UserNotifications

/// Local notifications for the Life Engine's reminders, derived from the list the engine returned and re-derived whenever
/// it changes, so the phone never holds a reminder the engine does not. They are a fallback for push (the gateway pushes
/// the same reminders when the app is closed); remove this once push is proven, or the same reminder would buzz twice.
enum Notifier {
    static let prefix = "reminder:"

    /// The instant a pending reminder next needs attention: its snooze if it has one, else its due time.
    static func fireDate(_ r: Wire.Reminder) -> Date? { r.isDone ? nil : (r.snoozedUntil ?? r.dueAt) }

    static func sync(_ reminders: [Wire.Reminder], now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let stale = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        let upcoming = reminders.compactMap { r in fireDate(r).flatMap { $0 > now ? (r, $0) : nil } }
        guard !upcoming.isEmpty else { return }
        // Asked the first time there is something to be reminded of, never at launch.
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return }
            await PushRegistrar.shared.start()   // now allowed: ask iOS for a device token so reminders can arrive while the app is closed
        }
        guard await center.notificationSettings().authorizationStatus != .denied else { return }
        for (r, date) in upcoming.prefix(60) {   // iOS keeps at most 64 pending local notifications
            let content = UNMutableNotificationContent()
            content.title = "Reminder"; content.body = r.title; content.sound = .default
            if let link = try? Wire.encoder.encode(r.link) , let object = try? JSONSerialization.jsonObject(with: link) { content.userInfo = ["link": object] }
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            try? await center.add(UNNotificationRequest(identifier: prefix + r.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
        }
    }
}
