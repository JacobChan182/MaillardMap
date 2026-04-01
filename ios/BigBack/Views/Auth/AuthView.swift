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

                    Text("BigBack")
                        .font(.largeTitle.weight(.bold))
                    Text(auth.isSignupMode ? "Create your account" : "Welcome back")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                VStack(spacing: 16) {
                    TextField("Username", text: $auth.username)
                        .textInputAutocapitalization(.never)
                        .textContentType(.username)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $auth.password)
                        .textContentType(.password)

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
                }
                .textFieldStyle(.roundedBorder)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        auth.isSignupMode.toggle()
                        auth.errorMessage = nil
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
