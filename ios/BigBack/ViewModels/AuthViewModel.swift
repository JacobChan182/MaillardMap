import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isSignupMode = false

    @Published var username = ""
    @Published var password = ""
    @Published var phoneOrEmail = ""

    let api: APIClient

    init(api: APIClient = .live()) {
        self.api = api
        if UserDefaults.standard.string(forKey: "authToken") != nil,
           let data = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder.default.decode(User.self, from: data) {
            currentUser = user
        } else if UserDefaults.standard.string(forKey: "authToken") != nil,
                  let id = UserDefaults.standard.string(forKey: "currentUserId") {
            currentUser = User(
                id: id,
                username: UserDefaults.standard.string(forKey: "currentUsername") ?? "",
                phoneOrEmail: nil,
                displayName: nil,
                avatarUrl: nil,
                bio: nil,
                createdAt: nil
            )
        }
    }

    var isLoggedIn: Bool { currentUser != nil }

    func login() async {
        guard !username.isEmpty else {
            errorMessage = "Enter your username or email"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Enter your password"
            return
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
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
            errorMessage = error.localizedDescription
        }
    }

    func signup() async {
        guard !username.isEmpty else {
            errorMessage = "Choose a username"
            return
        }
        guard username.count >= 3 else {
            errorMessage = "Username must be at least 3 characters"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Choose a password"
            return
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let contact = phoneOrEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            let resp = try await api.signup(username: username, password: password, phoneOrEmail: contact.isEmpty ? nil : contact)
            currentUser = resp.user
            saveUser(resp.user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func replaceCurrentUser(_ user: User) {
        currentUser = user
        saveUser(user)
    }

    func logout() {
        currentUser = nil
        api.clearSession()
        username = ""
        password = ""
        phoneOrEmail = ""
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
