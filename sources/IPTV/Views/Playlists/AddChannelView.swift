import SwiftUI

struct AddChannelView: View {
    let playlist: Playlist
    let nextPosition: Int

    @EnvironmentObject var auth: SupabaseAuth
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var streamUrl = ""
    @State private var logoUrl = ""
    @State private var category = ""
    @State private var kind = "live"
    @State private var isLoading = false
    @State private var error: String?

    private let kinds = [("Live TV", "live"), ("Movie / VOD", "vod"), ("Series", "series")]

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                Form {
                    Section {
                        TextField("Channel name", text: $name)
                            .foregroundStyle(.white)
                        TextField("Stream URL (http://...)", text: $streamUrl)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                    } header: {
                        Text("Required").foregroundStyle(.white.opacity(0.6))
                    }
                    .listRowBackground(Color.white.opacity(0.08))

                    Section {
                        TextField("Logo URL (optional)", text: $logoUrl)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                        TextField("Category (optional)", text: $category)
                            .foregroundStyle(.white)
                        Picker("Type", selection: $kind) {
                            ForEach(kinds, id: \.1) { label, value in
                                Text(label).tag(value)
                            }
                        }
                        .foregroundStyle(.white)
                    } header: {
                        Text("Optional").foregroundStyle(.white.opacity(0.6))
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Channel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: add) {
                        if isLoading { ProgressView().tint(.white) }
                        else { Text("Add").bold() }
                    }
                    .disabled(name.isEmpty || streamUrl.isEmpty || isLoading)
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

    private func add() {
        guard let userId = auth.userId, let token = auth.accessToken else { return }
        guard let _ = URL(string: streamUrl) else {
            error = "Please enter a valid stream URL."
            return
        }
        isLoading = true
        Task {
            do {
                let payload = CreateChannelPayload(
                    playlistId: playlist.id,
                    userId: userId,
                    name: name.trimmingCharacters(in: .whitespaces),
                    streamUrl: streamUrl.trimmingCharacters(in: .whitespaces),
                    logoUrl: logoUrl.trimmingCharacters(in: .whitespaces),
                    category: category.trimmingCharacters(in: .whitespaces),
                    kind: kind,
                    position: nextPosition
                )
                _ = try await SupabaseDB.addChannel(payload, token: token)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
