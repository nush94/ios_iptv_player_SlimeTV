import SwiftUI

struct CreatePlaylistView: View {
    @EnvironmentObject var auth: SupabaseAuth
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var isPublic = false
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                Form {
                    Section {
                        TextField("Playlist name", text: $name)
                            .foregroundStyle(.white)
                        TextField("Description (optional)", text: $description)
                            .foregroundStyle(.white)
                    } header: {
                        Text("Details").foregroundStyle(.white.opacity(0.6))
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section {
                        Toggle("Make Public", isOn: $isPublic)
                            .tint(.blue)
                            .foregroundStyle(.white)
                    } header: {
                        Text("Visibility").foregroundStyle(.white.opacity(0.6))
                    } footer: {
                        Text("Public playlists can be imported by anyone with the share link.")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: create) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Create").bold()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    .foregroundStyle(.white)
                }
            }
            .alert("Error", isPresented: .constant(error != nil), actions: {
                Button("OK") { error = nil }
            }, message: {
                Text(error ?? "")
            })
        }
    }

    private func create() {
        guard let userId = auth.userId, let token = auth.accessToken else { return }
        isLoading = true
        Task {
            do {
                let payload = CreatePlaylistPayload(
                    name: name.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces),
                    isPublic: isPublic,
                    userId: userId
                )
                _ = try await SupabaseDB.createPlaylist(payload, token: token)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
