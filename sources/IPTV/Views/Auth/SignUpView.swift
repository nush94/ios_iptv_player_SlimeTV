import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var auth: SupabaseAuth
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var error: String?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(white: 0.08)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding()

                Spacer()

                VStack(spacing: 8) {
                    Text("Create Account")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Join SlimeTV and build your playlists")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer().frame(height: 40)

                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .fieldStyle()

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .fieldStyle()

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .fieldStyle()
                }
                .padding(.horizontal, 32)

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                        .padding(.top, 8)
                        .padding(.horizontal, 32)
                }

                Spacer().frame(height: 24)

                Button(action: { Task { await signUp() } }) {
                    Group {
                        if auth.isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("Create Account").font(.headline).foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 32)
                .disabled(auth.isLoading)

                Spacer()
            }
        }
    }

    private func signUp() async {
        error = nil
        guard !email.isEmpty else { error = "Email is required."; return }
        guard password.count >= 6 else { error = "Password must be at least 6 characters."; return }
        guard password == confirmPassword else { error = "Passwords do not match."; return }
        do {
            try await auth.signUp(email: email, password: password)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private extension View {
    func fieldStyle() -> some View {
        self
            .padding()
            .background(.white.opacity(0.08))
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12)))
    }
}
