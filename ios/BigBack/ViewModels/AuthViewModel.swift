import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isSignupMode = false

    @Published var username = ""
    @Published var password = ""

    private let api: APIClient

    init(api: APIClient = .live()) {
        self.api = api
        if UserDefaults.standard.string(forKey: "authToken") != nil,
           let data = UserDefaults.standard.data(forKey: "currentUser"),
           let _ = try? JSONDecoder.default.decode(User.self, from: data) {
            // Session exists — user is authed
            if let id = UserDefaults.standard.string(forKey: "currentUserId") {
                self.currentUser = User(id: id, username: UserDefaults.standard.string(forKey: "currentUsername") ?? "", phoneOrEmail: nil, createdAt: nil)
            }
        }
    }

    var isLoggedIn: Bool { currentUser != nil }

    func login() async {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Enter username and password"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await api.login(username: username, password: password)
            currentUser = resp.user
            saveUser(resp.user)
        } catch {
            errorMessage = "Invalid credentials"
        }
    }

    func signup() async {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Enter username and password"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await api.signup(username: username, password: password)
            currentUser = resp.user
            saveUser(resp.user)
        } catch {
            errorMessage = "Signup failed"
        }
    }

    func logout() {
        currentUser = nil
        api.clearSession()
        username = ""
        password = ""
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "currentUserId")
        UserDefaults.standard.removeObject(forKey: "currentUsername")
    }

    private func saveUser(_ user: User) {
        UserDefaults.standard.set(user.id, forKey: "currentUserId")
        UserDefaults.standard.set(user.username, forKey: "currentUsername")
        if let data = try? JSONEncoder.default.encode(user) {
            UserDefaults.standard.set(data, forKey: "currentUser")
        }
    }
}
