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
            .environmentObject(auth)
        }
    }
}
