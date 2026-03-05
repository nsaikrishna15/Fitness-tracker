import SwiftUI
import UserNotifications

@main
struct FitTrackApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                // Clear any delivered notifications that may linger after the app was reinstalled
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            }
        }
    }
}
