import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var isLoading = false
    @Published var isSignupMode = false
    /// Seconds until "Resend confirmation" is enabled again (counts down every second).
    @Published private(set) var resendCooldownSeconds = 0
    /// After login 403 EMAIL_NOT_VERIFIED — show resend using the identifier they typed.
    @Published var needsEmailVerificationFromLogin = false

    @Published var username = ""
    @Published var password = ""
    @Published var email = ""

    let api: APIClient
    private var resendCooldownTask: Task<Void, Never>?

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
                createdAt: nil,
                profilePrivate: nil
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
        infoMessage = nil
        defer { isLoading = false }
        do {
            let resp = try await api.login(username: username, password: password)
            currentUser = resp.user
            saveUser(resp.user)
            needsEmailVerificationFromLogin = false
        } catch {
            errorMessage = error.localizedDescription
            if let apiErr = error as? APIError, apiErr.serverErrorCode == "EMAIL_NOT_VERIFIED" {
                needsEmailVerificationFromLogin = true
                startResendCooldown()
            } else {
                needsEmailVerificationFromLogin = false
            }
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
        let addr = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !addr.isEmpty else {
            errorMessage = "Enter your email"
            return
        }
        guard addr.contains("@"), addr.contains(".") else {
            errorMessage = "Enter a valid email address"
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
        infoMessage = nil
        defer { isLoading = false }
        do {
            let result = try await api.signup(username: username, email: addr, password: password)
            infoMessage = result.message.isEmpty ? "Check your email to confirm your account before logging in." : result.message
            password = ""
            needsEmailVerificationFromLogin = false
            startResendCooldown()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var showResendConfirmation: Bool {
        infoMessage != nil || needsEmailVerificationFromLogin
    }

    func resendConfirmationEmail() async {
        let id = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard id.count >= 3 else {
            errorMessage = "Enter the username or email you used to sign up."
            return
        }
        guard resendCooldownSeconds == 0 else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let msg = try await api.resendConfirmation(usernameOrEmail: id)
            infoMessage = msg
        } catch {
            errorMessage = error.localizedDescription
        }
        startResendCooldown()
    }

    func requestPasswordResetEmail() async {
        let id = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard id.count >= 3 else {
            errorMessage = "Enter your username or email first."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            infoMessage = try await api.requestPasswordReset(usernameOrEmail: id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startResendCooldown() {
        resendCooldownTask?.cancel()
        resendCooldownSeconds = 30
        resendCooldownTask = Task { @MainActor in
            while resendCooldownSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                resendCooldownSeconds -= 1
            }
        }
    }

    /// Clears verification messaging and resend cooldown (e.g. when switching log in / sign up).
    func resetVerificationUI() {
        errorMessage = nil
        infoMessage = nil
        needsEmailVerificationFromLogin = false
        resendCooldownTask?.cancel()
        resendCooldownSeconds = 0
    }

    func replaceCurrentUser(_ user: User) {
        currentUser = user
        saveUser(user)
    }

    func logout() {
        api.unregisterStoredAPNSTokenBestEffort()
        currentUser = nil
        api.clearSession()
        username = ""
        password = ""
        email = ""
        errorMessage = nil
        infoMessage = nil
        needsEmailVerificationFromLogin = false
        resendCooldownTask?.cancel()
        resendCooldownSeconds = 0
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
