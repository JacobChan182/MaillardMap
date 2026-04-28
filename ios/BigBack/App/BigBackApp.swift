import SwiftUI

@main
struct BigBackApp: App {
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
        }
    }
}
