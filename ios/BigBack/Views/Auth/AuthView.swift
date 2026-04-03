import SwiftUI

struct AuthView: View {
    @ObservedObject var auth: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.orange)

                    Text("MaillardMap")
                        .font(.largeTitle.weight(.bold))
                    Text(auth.isSignupMode ? "Create your account" : "Welcome back")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                VStack(spacing: 16) {
                    TextField(auth.isSignupMode ? "Username" : "Username or email", text: $auth.username)
                        .textInputAutocapitalization(.never)
                        .textContentType(.username)
                        .autocorrectionDisabled()

                    if auth.isSignupMode {
                        TextField("Email", text: $auth.email)
                            .textInputAutocapitalization(.never)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                    }

                    SecureField("Password", text: $auth.password)
                        .textContentType(auth.isSignupMode ? .newPassword : .password)

                    Button {
                        Task {
                            if auth.isSignupMode {
                                await auth.signup()
                            } else {
                                await auth.login()
                            }
                        }
                    } label: {
                        Text(auth.isSignupMode ? "Sign Up" : "Log In")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                    }
                    .disabled(auth.isLoading)

                    if auth.isLoading {
                        ProgressView()
                    }

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if let info = auth.infoMessage {
                        Text(info)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .textFieldStyle(.roundedBorder)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        auth.isSignupMode.toggle()
                        auth.errorMessage = nil
                        auth.infoMessage = nil
                    } label: {
                        Text(auth.isSignupMode
                             ? "Already have an account? Log in"
                             : "Don't have an account? Sign up")
                        .font(.footnote)
                        .foregroundStyle(.blue)
                    }

                    if !auth.isSignupMode {
                        Button {
                            auth.isSignupMode.toggle()
                        } label: {
                            Text("Need to reset your password?")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .padding()
        }
    }
}

#Preview {
    AuthView(auth: AuthViewModel())
}
