import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: SupabaseAuth

    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var showSignUp = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color(white: 0.08)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "tv.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .foregroundStyle(.white)

                    Text("SlimeTV")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Stream anything. Your way.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer().frame(height: 48)

                VStack(spacing: 14) {
                    inputField("Email", text: $email, contentType: .emailAddress, keyboard: .emailAddress)
                    secureInputField("Password", text: $password, contentType: .password)
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

                primaryButton(title: "Sign In", loading: auth.isLoading) {
                    Task { await signIn() }
                }
                .padding(.horizontal, 32)

                Button(action: { showSignUp = true }) {
                    Text("New here? ")
                        .foregroundStyle(.white.opacity(0.5))
                    + Text("Create an account")
                        .foregroundStyle(.white)
                }
                .font(.footnote)
                .padding(.top, 20)

                Spacer()
            }
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
    }

    // MARK: - Components

    private func inputField(_ placeholder: String, text: Binding<String>, contentType: UITextContentType, keyboard: UIKeyboardType) -> some View {
        TextField(placeholder, text: text)
            .textContentType(contentType)
            .keyboardType(keyboard)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .padding()
            .background(.white.opacity(0.08))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12)))
    }

    private func secureInputField(_ placeholder: String, text: Binding<String>, contentType: UITextContentType) -> some View {
        SecureField(placeholder, text: text)
            .textContentType(contentType)
            .padding()
            .background(.white.opacity(0.08))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12)))
    }

    private func primaryButton(title: String, loading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if loading {
                    ProgressView().tint(.black)
                } else {
                    Text(title).font(.headline).foregroundStyle(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .disabled(loading)
    }

    // MARK: - Logic

    private func signIn() async {
        error = nil
        guard !email.isEmpty, !password.isEmpty else {
            error = "Please enter your email and password."
            return
        }
        do {
            try await auth.signIn(email: email, password: password)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
