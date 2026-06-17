import SwiftUI

@MainActor
final class PlaylistDetailViewModel: ObservableObject {
    @Published var channels: [PlaylistChannel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(playlistId: String, token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            channels = try await SupabaseDB.fetchChannels(playlistId: playlistId, token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ channel: PlaylistChannel, token: String) async {
        do {
            try await SupabaseDB.deleteChannel(id: channel.id, token: token)
            channels.removeAll { $0.id == channel.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PlaylistDetailView: View {
    let playlist: Playlist

    @EnvironmentObject var auth: SupabaseAuth
    @StateObject private var vm = PlaylistDetailViewModel()
    @State private var showAddChannel = false
    @State private var showM3UImport = false
    @State private var playingChannel: PlaylistChannel?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if vm.isLoading && vm.channels.isEmpty {
                ProgressView().tint(.white)
            } else if vm.channels.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.channels) { channel in
                            ChannelRow(channel: channel)
                                .onTapGesture { playingChannel = channel }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await vm.delete(channel, token: auth.accessToken ?? "") }
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
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showAddChannel = true }) {
                        Label("Add by URL", systemImage: "link.badge.plus")
                    }
                    Button(action: { showM3UImport = true }) {
                        Label("Import M3U", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "plus").foregroundStyle(.white)
                }
            }
        }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil), actions: {
            Button("OK") { vm.errorMessage = nil }
        }, message: {
            Text(vm.errorMessage ?? "")
        })
        .sheet(isPresented: $showAddChannel, onDismiss: {
            Task { await vm.load(playlistId: playlist.id, token: auth.accessToken ?? "") }
        }) {
            AddChannelView(playlist: playlist, nextPosition: vm.channels.count)
        }
        .sheet(isPresented: $showM3UImport, onDismiss: {
            Task { await vm.load(playlistId: playlist.id, token: auth.accessToken ?? "") }
        }) {
            M3UImportView(playlist: playlist, nextPosition: vm.channels.count)
        }
        .fullScreenCover(item: $playingChannel) { channel in
            PlaylistPlayerView(channel: channel)
        }
        .task {
            await vm.load(playlistId: playlist.id, token: auth.accessToken ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.3))
            Text("No channels yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Add channels by URL or import an M3U playlist.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button(action: { showAddChannel = true }) {
                    Label("Add URL", systemImage: "link")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button(action: { showM3UImport = true }) {
                    Label("Import M3U", systemImage: "square.and.arrow.down")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
    }
}

struct ChannelRow: View {
    let channel: PlaylistChannel

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(kindColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: kindIcon)
                    .foregroundStyle(kindColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(channel.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !channel.category.isEmpty {
                    Text(channel.category)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(14)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var kindIcon: String {
        switch channel.kind {
        case "vod": return "film.fill"
        case "series": return "square.stack.fill"
        default: return "antenna.radiowaves.left.and.right"
        }
    }

    private var kindColor: Color {
        switch channel.kind {
        case "vod": return .purple
        case "series": return .orange
        default: return .blue
        }
    }
}
