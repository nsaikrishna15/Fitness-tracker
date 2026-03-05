import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    struct ReminderSchedule {
        let id: String
        let hour: Int
        let minute: Int
        let title: String
        let body: String
    }

    // One notification per habit block — fires daily, iOS wakes the alert even when app is closed
    let schedules: [ReminderSchedule] = [
        ReminderSchedule(id: "r_0630", hour:  6, minute: 30, title: "Wake & Water",
                         body: "Start your morning hydration. Day begins now."),
        ReminderSchedule(id: "r_0635", hour:  6, minute: 35, title: "Brush + Toilet",
                         body: "Morning routine. No phone. 5 minutes."),
        ReminderSchedule(id: "r_0645", hour:  6, minute: 45, title: "Sunlight",
                         body: "5 minutes outside. Light exposure resets your clock."),
        ReminderSchedule(id: "r_0650", hour:  6, minute: 50, title: "Pre-Workout Meal",
                         body: "Fuel up before training. Check your Diet tab for today's amounts."),
        ReminderSchedule(id: "r_0700", hour:  7, minute:  0, title: "GYM TIME",
                         body: "Check your Workout tab — Upper / Lower / Walk / REST today."),
        ReminderSchedule(id: "r_0815", hour:  8, minute: 15, title: "Breakfast",
                         body: "Post-workout meal. Check your Diet tab for today's amounts."),
        ReminderSchedule(id: "r_0900", hour:  9, minute:  0, title: "Office — Hydrate",
                         body: "Carry your bottle. Stay on pace with your water target."),
        ReminderSchedule(id: "r_1230", hour: 12, minute: 30, title: "Lunch",
                         body: "Midday meal. Check your Diet tab for protein and carb amounts."),
        ReminderSchedule(id: "r_1530", hour: 15, minute: 30, title: "Water Check",
                         body: "Check your hydration target. You should be about halfway there."),
        ReminderSchedule(id: "r_1630", hour: 16, minute: 30, title: "Snack",
                         body: "Afternoon snack time. Keep protein intake on track."),
        ReminderSchedule(id: "r_1930", hour: 19, minute: 30, title: "Dinner",
                         body: "Evening meal. Check your Diet tab for today's amounts."),
        ReminderSchedule(id: "r_2030", hour: 20, minute: 30, title: "Stretch + Kegels",
                         body: "10 min stretch + Kegels 3×20. Non-negotiable."),
        ReminderSchedule(id: "r_2130", hour: 21, minute: 30, title: "Progress Photo",
                         body: "Same spot, same light, relaxed pose. Take it."),
        ReminderSchedule(id: "r_2230", hour: 22, minute: 30, title: "Wind Down",
                         body: "Phone down. Dim lights. Prepare your mind for sleep."),
        ReminderSchedule(id: "r_2300", hour: 23, minute:  0, title: "Sleep",
                         body: "7.5 hours minimum. Lights out. You did the work."),
    ]

    func requestPermissionAndSchedule(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted { self.scheduleAll() }
                completion(granted)
            }
        }
    }

    func scheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: schedules.map { $0.id })

        for schedule in schedules {
            let content = UNMutableNotificationContent()
            content.title = schedule.title
            content.body  = schedule.body
            content.sound = .default
            content.interruptionLevel = .timeSensitive  // bypasses focus modes

            var comps = DateComponents()
            comps.hour   = schedule.hour
            comps.minute = schedule.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: schedule.id, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }

    func removeAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: schedules.map { $0.id })
    }

    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }
}
