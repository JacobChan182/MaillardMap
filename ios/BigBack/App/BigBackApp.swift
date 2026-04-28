import SwiftUI
import UIKit
import UserNotifications

final class BigBackPushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func registerForPushNotificationsIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("Push authorization failed: \(error.localizedDescription)")
                return
            }
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif

        Task {
            do {
                try await APIClient.live().registerAPNSToken(token: token, environment: environment)
            } catch {
                print("APNs token registration failed: \(error.localizedDescription)")
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Remote notification registration failed: \(error.localizedDescription)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationCenter.default.post(
            name: .bigBackOpenNotifications,
            object: nil,
            userInfo: response.notification.request.content.userInfo
        )
        completionHandler()
    }
}

@main
struct BigBackApp: App {
    @UIApplicationDelegateAdaptor(BigBackPushAppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isLoggedIn {
                    MainTabView(auth: auth)
                } else {
                    AuthView(auth: auth)
                }
            }
            .dismissKeyboardOnTap()
            .keyboardDoneToolbar()
            .environmentObject(auth)
            .onReceive(NotificationCenter.default.publisher(for: .bigBackSessionExpired)) { _ in
                auth.logout()
            }
            .task {
                if auth.isLoggedIn {
                    appDelegate.registerForPushNotificationsIfNeeded()
                }
            }
            .onChange(of: auth.isLoggedIn) { _, isLoggedIn in
                if isLoggedIn {
                    appDelegate.registerForPushNotificationsIfNeeded()
                }
            }
        }
    }
}
