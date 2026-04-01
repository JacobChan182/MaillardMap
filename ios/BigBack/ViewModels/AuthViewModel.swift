import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isSignupMode = false

    // Form fields
    @Published var username = ""
    @Published var phoneOrEmail = ""
    @Published var password = ""

    private let api: APIClient

    init(api: APIClient = .live()) {
        self.api = api
        // Check for existing session
        if UserDefaults.standard.string(forKey: "authToken") != nil,
           let data = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder.default.decode(User.self, from: data) {
            self.currentUser = user
        }
    }

    var isLoggedIn: Bool {
        currentUser != nil
    }

    func login() async {
        guard !phoneOrEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Enter phone/email and password"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let resp = try await api.login(phoneOrEmail: phoneOrEmail, password: password)
            currentUser = resp.user
            saveUser(resp.user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signup() async {
        guard !username.isEmpty, !phoneOrEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Fill in all fields"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let resp = try await api.signup(phoneOrEmail: phoneOrEmail, password: password, username: username)
            currentUser = resp.user
            saveUser(resp.user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        currentUser = nil
        api.clearSession()
        username = ""
        phoneOrEmail = ""
        password = ""
        UserDefaults.standard.removeObject(forKey: "currentUser")
    }

    private func saveUser(_ user: User) {
        if let data = try? JSONEncoder.default.encode(user) {
            UserDefaults.standard.set(data, forKey: "currentUser")
        }
    }
}
