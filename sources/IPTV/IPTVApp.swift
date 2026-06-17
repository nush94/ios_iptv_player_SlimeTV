import SwiftUI

@main
struct IPTVApp: App {
#if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
#endif

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .environmentObject(SupabaseAuth.shared)
        }
    }
}
