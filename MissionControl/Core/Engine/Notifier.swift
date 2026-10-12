import Foundation
import UserNotifications

/// Local notifications for reminders that have a time. Asks for permission the first time one is needed.
enum Notifier {
    static func schedule(_ outcome: CaptureOutcome) async {
        guard case .reminder(let r) = outcome, let due = r.due, due > Date() else { return }
        await schedule(id: r.id, title: r.title, at: due)
    }

    static func schedule(id: UUID, title: String, at date: Date) async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Reminder"; content.body = title; content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        try? await center.add(UNNotificationRequest(identifier: id.uuidString, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
    }
}
