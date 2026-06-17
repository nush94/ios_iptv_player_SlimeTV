import SwiftUI

@MainActor
final class PlaylistsViewModel: ObservableObject {
    @Published var playlists: [Playlist] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            playlists = try await SupabaseDB.fetchPlaylists(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ playlist: Playlist, token: String) async {
        do {
            try await SupabaseDB.deletePlaylist(id: playlist.id, token: token)
            playlists.removeAll { $0.id == playlist.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PlaylistsView: View {
    @EnvironmentObject var auth: SupabaseAuth
    @StateObject private var vm = PlaylistsViewModel()
    @State private var showCreate = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if vm.isLoading && vm.playlists.isEmpty {
                    ProgressView().tint(.white)
                } else if vm.playlists.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(vm.playlists) { playlist in
                                NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                                    PlaylistCard(playlist: playlist)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await vm.delete(playlist, token: auth.accessToken ?? "") }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Playlists")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreate = true }) {
                        Image(systemName: "plus").foregroundStyle(.white)
                    }
                }
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil), actions: {
                Button("OK") { vm.errorMessage = nil }
            }, message: {
                Text(vm.errorMessage ?? "")
            })
        }
        .task {
            await vm.load(token: auth.accessToken ?? "")
        }
        .sheet(isPresented: $showCreate, onDismiss: {
            Task { await vm.load(token: auth.accessToken ?? "") }
        }) {
            CreatePlaylistView()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.3))
            Text("No playlists yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Create a playlist and add your favourite\nstreams to it.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            Button(action: { showCreate = true }) {
                Label("Create Playlist", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}

struct PlaylistCard: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.25))
                    .frame(width: 56, height: 56)
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !playlist.description.isEmpty {
                    Text(playlist.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Image(systemName: playlist.isPublic ? "globe" : "lock.fill")
                        .font(.caption2)
                    Text(playlist.isPublic ? "Public" : "Private")
                        .font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(16)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
