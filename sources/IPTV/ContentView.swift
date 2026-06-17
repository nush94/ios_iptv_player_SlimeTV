import IPTVComponents
import IPTVModels
import Realm
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: SupabaseAuth
    @AppStorage("status") private var xtreamStatus: String = ""

    var body: some View {
        TabView {
            Tab("Live", systemImage: "tv") {
                if xtreamStatus.isEmpty {
                    XtreamSetupPrompt()
                } else {
                    LiveView(kindMedia: .live)
                }
            }
            Tab("VOD", systemImage: "film") {
                if xtreamStatus.isEmpty {
                    XtreamSetupPrompt()
                } else {
                    VodView(kindMedia: .vod)
                }
            }
            Tab("Series", systemImage: "square.stack") {
                if xtreamStatus.isEmpty {
                    XtreamSetupPrompt()
                } else {
                    SeriesView(kindMedia: .series)
                }
            }
            Tab("Search", systemImage: "magnifyingglass") {
                if xtreamStatus.isEmpty {
                    XtreamSetupPrompt()
                } else {
                    SearchView()
                }
            }
            Tab("My Playlists", systemImage: "list.bullet.rectangle.fill") {
                PlaylistsView()
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView()
                    .background {
                        HeroHeaderView(belowFold: true)
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
            }
        }
        .background {
            HeroHeaderView(belowFold: true)
        }
    }
}

struct XtreamSetupPrompt: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "server.rack")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.3))
                Text("IPTV Server Not Configured")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("Go to Settings to connect your Xtream Codes server.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SupabaseAuth.shared)
}
