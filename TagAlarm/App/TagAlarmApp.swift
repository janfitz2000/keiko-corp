import SwiftUI
import UserNotifications

@main
struct TagAlarmApp: App {
    @StateObject private var alarmManager = AlarmManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var nfcManager = NFCManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alarmManager)
                .environmentObject(locationManager)
                .environmentObject(nfcManager)
                .onReceive(NotificationCenter.default.publisher(for: .alarmTriggered)) { notification in
                    if let alarmID = notification.userInfo?["alarmID"] as? String {
                        alarmManager.handleNotification(alarmID: alarmID)
                    }
                }
        }
    }
}

extension Notification.Name {
    static let alarmTriggered = Notification.Name("alarmTriggered")
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let alarmID = notification.request.content.userInfo["alarmID"] as? String ?? ""
        NotificationCenter.default.post(name: .alarmTriggered, object: nil, userInfo: ["alarmID": alarmID])
        completionHandler([.sound, .banner])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let alarmID = response.notification.request.content.userInfo["alarmID"] as? String ?? ""
        NotificationCenter.default.post(name: .alarmTriggered, object: nil, userInfo: ["alarmID": alarmID])
        completionHandler()
    }
}
