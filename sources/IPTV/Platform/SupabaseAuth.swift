import Foundation

@MainActor
final class SupabaseAuth: ObservableObject {
    static let shared = SupabaseAuth()

    @Published var session: UserSession?
    @Published var isLoading = false
    @Published var errorMessage: String?

    var isLoggedIn: Bool { session != nil }
    var accessToken: String? { session?.accessToken }
    var userId: String? { session?.user.id }
    var userEmail: String? { session?.user.email }

    private let sessionKey = "slimetv_session"

    private init() {
        loadPersistedSession()
    }

    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let body = try JSONEncoder().encode(["email": email, "password": password])
        let data = try await post(path: "/auth/v1/signup", body: body)
        let parsed = try decode(UserSession.self, from: data)
        persist(parsed)
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let body = try JSONEncoder().encode(["email": email, "password": password])
        let data = try await post(path: "/auth/v1/token?grant_type=password", body: body)
        let parsed = try decode(UserSession.self, from: data)
        persist(parsed)
    }

    func signOut() async {
        if let token = accessToken {
            var req = URLRequest(url: URL(string: "\(SupabaseConfig.url)/auth/v1/logout")!)
            req.httpMethod = "POST"
            req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: req)
        }
        session = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    // MARK: - Private

    private func post(path: String, body: Data) async throws -> Data {
        var req = URLRequest(url: URL(string: "\(SupabaseConfig.url)\(path)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw AuthError.failed(extractMessage(from: data))
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw AuthError.failed("Invalid response from server")
        }
    }

    private func persist(_ s: UserSession) {
        session = s
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }

    private func loadPersistedSession() {
        guard let data = UserDefaults.standard.data(forKey: sessionKey),
              let s = try? JSONDecoder().decode(UserSession.self, from: data) else { return }
        session = s
    }

    private func extractMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return (json["message"] as? String)
                ?? (json["error_description"] as? String)
                ?? (json["error"] as? String)
                ?? "Unknown error"
        }
        return "Unknown error"
    }
}

enum AuthError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        if case .failed(let msg) = self { return msg }
        return nil
    }
}
