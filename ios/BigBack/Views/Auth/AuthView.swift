import SwiftUI

// MARK: - Brand

private enum AuthTheme {
    static let accent = Color.orange
    static let accentGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.55, blue: 0.2), Color.orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Auth screen

struct AuthView: View {
    @ObservedObject var auth: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case username, email, password
    }

    var body: some View {
        ZStack {
            AuthBackground()

            ScrollView {
                VStack(spacing: 28) {
                    AuthHeader(isSignupMode: auth.isSignupMode)
                        .padding(.top, 48)

                    AuthModePicker(isSignupMode: $auth.isSignupMode) {
                        auth.resetVerificationUI()
                    }

                    VStack(spacing: 14) {
                        AuthTextField(
                            title: auth.isSignupMode ? "Username" : "Username or email",
                            text: $auth.username,
                            icon: "person.fill",
                            contentType: .username,
                            keyboard: .default,
                            submitLabel: auth.isSignupMode ? .next : .done,
                            isFocused: focusedField == .username
                        ) {
                            focusedField = auth.isSignupMode ? .email : .password
                        }
                        .focused($focusedField, equals: .username)

                        if auth.isSignupMode {
                            AuthTextField(
                                title: "Email",
                                text: $auth.email,
                                icon: "envelope.fill",
                                contentType: .emailAddress,
                                keyboard: .emailAddress,
                                submitLabel: .next,
                                isFocused: focusedField == .email
                            ) {
                                focusedField = .password
                            }
                            .focused($focusedField, equals: .email)
                        }

                        AuthSecureField(
                            title: "Password",
                            text: $auth.password,
                            contentType: auth.isSignupMode ? .newPassword : .password,
                            isFocused: focusedField == .password
                        ) {
                            submitAuth()
                        }
                        .focused($focusedField, equals: .password)

                        if let error = auth.errorMessage {
                            AuthBanner(text: error, style: .error)
                        }
                        if let info = auth.infoMessage {
                            AuthBanner(text: info, style: .info)
                        }

                        AuthPrimaryButton(
                            title: auth.isSignupMode ? "Create account" : "Log in",
                            isLoading: auth.isLoading
                        ) {
                            submitAuth()
                        }
                        .disabled(auth.isLoading)
                        .padding(.top, 4)

                        if auth.showResendConfirmation {
                            Button {
                                Task { await auth.resendConfirmationEmail() }
                            } label: {
                                Text(
                                    auth.resendCooldownSeconds > 0
                                        ? "Resend confirmation email (\(auth.resendCooldownSeconds)s)"
                                        : "Resend confirmation email"
                                )
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(
                                    auth.resendCooldownSeconds > 0 ? Color.secondary : AuthTheme.accent
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(auth.resendCooldownSeconds > 0 || auth.isLoading)
                        }

                        if !auth.isSignupMode {
                            Button {
                                Task { await auth.requestPasswordResetEmail() }
                            } label: {
                                Text("Forgot password?")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .disabled(auth.isLoading)
                        }
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.background)
                            .shadow(color: .black.opacity(0.06), radius: 24, y: 12)
                    }

                    Text(auth.isSignupMode
                         ? "Share where you eat with friends — quick posts, no long reviews."
                         : "Discover restaurants through the people you trust.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func submitAuth() {
        focusedField = nil
        Task {
            if auth.isSignupMode {
                await auth.signup()
            } else {
                await auth.login()
            }
        }
    }
}

// MARK: - Background

private struct AuthBackground: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.orange.opacity(0.35), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
                .frame(width: 440, height: 440)
                .offset(x: 120, y: -280)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.orange.opacity(0.18), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: -140, y: 320)
        }
    }
}

// MARK: - Header

private struct AuthHeader: View {
    let isSignupMode: Bool

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AuthTheme.accentGradient)
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.orange.opacity(0.35), radius: 16, y: 8)

                Image(systemName: "fork.knife")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                Text("MaillardMap")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text(isSignupMode ? "Create your account" : "Welcome back")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Mode picker

private struct AuthModePicker: View {
    @Binding var isSignupMode: Bool
    var onChange: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            modeButton(title: "Log in", selected: !isSignupMode) {
                guard isSignupMode else { return }
                withAnimation(.snappy(duration: 0.25)) {
                    isSignupMode = false
                    onChange()
                }
            }
            modeButton(title: "Sign up", selected: isSignupMode) {
                guard !isSignupMode else { return }
                withAnimation(.snappy(duration: 0.25)) {
                    isSignupMode = true
                    onChange()
                }
            }
        }
        .padding(4)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
    }

    private func modeButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if selected {
                        Capsule()
                            .fill(.background)
                            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fields

private struct AuthTextField: View {
    let title: String
    @Binding var text: String
    let icon: String
    let contentType: UITextContentType
    let keyboard: UIKeyboardType
    let submitLabel: SubmitLabel
    let isFocused: Bool
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(isFocused ? AuthTheme.accent : Color.secondary)
                .frame(width: 22)

            TextField(title, text: $text)
                .textInputAutocapitalization(.never)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(fieldBackground)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isFocused ? AuthTheme.accent.opacity(0.6) : Color.clear,
                        lineWidth: 1.5
                    )
            }
    }
}

private struct AuthSecureField: View {
    let title: String
    @Binding var text: String
    let contentType: UITextContentType
    let isFocused: Bool
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.body.weight(.medium))
                .foregroundStyle(isFocused ? AuthTheme.accent : Color.secondary)
                .frame(width: 22)

            SecureField(title, text: $text)
                .textContentType(contentType)
                .submitLabel(.go)
                .onSubmit(onSubmit)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isFocused ? AuthTheme.accent.opacity(0.6) : Color.clear,
                            lineWidth: 1.5
                        )
                }
        }
    }
}

// MARK: - Button & banners

private struct AuthPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AuthTheme.accentGradient)
            }
        }
        .buttonStyle(.plain)
        .opacity(isLoading ? 0.85 : 1)
    }
}

private struct AuthBanner: View {
    enum Style { case error, info }

    let text: String
    let style: Style

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: style == .error ? "exclamationmark.circle.fill" : "info.circle.fill")
                .foregroundStyle(style == .error ? Color.red : Color.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(style == .error ? Color.red : Color.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(style == .error ? Color.red.opacity(0.08) : Color(.tertiarySystemGroupedBackground))
        }
    }
}

#Preview {
    AuthView(auth: AuthViewModel())
}
