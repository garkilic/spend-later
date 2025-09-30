import Foundation
import UserNotifications

protocol NotificationScheduling {
    func requestAuthorizationIfNeeded()
    func updateWeeklyReminder(enabled: Bool)
    func cancelMonthlyReminder()
}

final class NotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter
    private let queue = DispatchQueue(label: "NotificationScheduler")

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            self.center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }
    }

    func updateWeeklyReminder(enabled: Bool) {
        queue.async {
            let identifier = "weekly-temptation-reminder"
            self.center.removePendingNotificationRequests(withIdentifiers: [identifier])
            guard enabled else { return }

            var dateComponents = DateComponents()
            dateComponents.weekday = 1 // Sunday
            dateComponents.hour = 18

            let content = UNMutableNotificationContent()
            content.title = "Log temptations"
            content.body = "Snap the things you resisted this week."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            self.center.add(request)
        }
    }

    func cancelMonthlyReminder() {
        queue.async {
            let identifier = "monthly-draw-reminder"
            self.center.removePendingNotificationRequests(withIdentifiers: [identifier])
        }
    }
}
