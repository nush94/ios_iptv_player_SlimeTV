import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject var auth: SupabaseAuth

    var body: some View {
        Group {
            if auth.isLoggedIn {
                ContentView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: auth.isLoggedIn)
    }
}
