import SwiftUI

struct M3UImportView: View {
    let playlist: Playlist
    let nextPosition: Int

    @EnvironmentObject var auth: SupabaseAuth
    @Environment(\.dismiss) var dismiss

    @State private var m3uUrl = ""
    @State private var pastedContent = ""
    @State private var mode: ImportMode = .url
    @State private var parsedEntries: [M3UEntry] = []
    @State private var selectedIds: Set<UUID> = []
    @State private var isLoading = false
    @State private var isParsing = false
    @State private var error: String?
    @State private var showPreview = false

    enum ImportMode: String, CaseIterable { case url = "URL", paste = "Paste" }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if showPreview {
                    previewList
                } else {
                    inputForm
                }
            }
            .navigationTitle("Import M3U")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { toolbarItems }
            .alert("Error", isPresented: .constant(error != nil), actions: {
                Button("OK") { error = nil }
            }, message: {
                Text(error ?? "")
            })
        }
    }

    // MARK: - Input Form

    private var inputForm: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $mode) {
                ForEach(ImportMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            Form {
                if mode == .url {
                    Section {
                        TextField("https://example.com/playlist.m3u", text: $m3uUrl)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                    } header: {
                        Text("M3U URL").foregroundStyle(.white.opacity(0.6))
                    } footer: {
                        Text("Enter a direct link to an M3U or M3U8 file.").foregroundStyle(.white.opacity(0.4))
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                } else {
                    Section {
                        TextEditor(text: $pastedContent)
                            .frame(minHeight: 200)
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                    } header: {
                        Text("Paste M3U Content").foregroundStyle(.white.opacity(0.6))
                    } footer: {
                        Text("Paste the full contents of an M3U file here.").foregroundStyle(.white.opacity(0.4))
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                }
            }
            .scrollContentBackground(.hidden)

            Button(action: { Task { await parse() } }) {
                Group {
                    if isParsing { ProgressView().tint(.black) }
                    else { Text("Preview Channels").font(.headline).foregroundStyle(.black) }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding()
            .disabled(isParsing || (mode == .url ? m3uUrl.isEmpty : pastedContent.isEmpty))
        }
    }

    // MARK: - Preview List

    private var previewList: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { showPreview = false }) {
                    Label("Back", systemImage: "chevron.left").foregroundStyle(.white)
                }
                Spacer()
                Text("\(selectedIds.count) of \(parsedEntries.count) selected")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Button(selectedIds.count == parsedEntries.count ? "Deselect All" : "Select All") {
                    if selectedIds.count == parsedEntries.count {
                        selectedIds.removeAll()
                    } else {
                        selectedIds = Set(parsedEntries.map(\.id))
                    }
                }
                .font(.caption.bold())
                .foregroundStyle(.white)
            }
            .padding()

            List(parsedEntries) { entry in
                HStack {
                    Image(systemName: selectedIds.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedIds.contains(entry.id) ? .blue : .white.opacity(0.4))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if !entry.category.isEmpty {
                            Text(entry.category)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    Spacer()
                    kindBadge(entry.kind)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedIds.contains(entry.id) { selectedIds.remove(entry.id) }
                    else { selectedIds.insert(entry.id) }
                }
                .listRowBackground(Color.white.opacity(0.06))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Button(action: { Task { await importSelected() } }) {
                Group {
                    if isLoading { ProgressView().tint(.black) }
                    else { Text("Import \(selectedIds.count) Channels").font(.headline).foregroundStyle(.black) }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .background(selectedIds.isEmpty ? .gray : .white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding()
            .disabled(selectedIds.isEmpty || isLoading)
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }.foregroundStyle(.white)
        }
    }

    private func kindBadge(_ kind: String) -> some View {
        Text(kind.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(kind == "vod" ? Color.purple : kind == "series" ? Color.orange : Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Logic

    private func parse() async {
        isParsing = true
        error = nil
        do {
            let content: String
            if mode == .url {
                guard let url = URL(string: m3uUrl) else { throw ImportError.invalidURL }
                let (data, _) = try await URLSession.shared.data(from: url)
                content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            } else {
                content = pastedContent
            }
            let entries = M3UParser.parse(content: content)
            if entries.isEmpty {
                error = "No channels found. Make sure this is a valid M3U file."
            } else {
                parsedEntries = entries
                selectedIds = Set(entries.map(\.id))
                showPreview = true
            }
        } catch {
            self.error = error.localizedDescription
        }
        isParsing = false
    }

    private func importSelected() async {
        guard let userId = auth.userId, let token = auth.accessToken else { return }
        isLoading = true
        error = nil
        let toImport = parsedEntries.filter { selectedIds.contains($0.id) }
        do {
            for (i, entry) in toImport.enumerated() {
                let payload = CreateChannelPayload(
                    playlistId: playlist.id,
                    userId: userId,
                    name: entry.name,
                    streamUrl: entry.url,
                    logoUrl: entry.logoUrl,
                    category: entry.category,
                    kind: entry.kind,
                    position: nextPosition + i
                )
                _ = try await SupabaseDB.addChannel(payload, token: token)
            }
            dismiss()
        } catch {
            self.error = "Imported some channels but encountered an error: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

enum ImportError: LocalizedError {
    case invalidURL
    var errorDescription: String? { "Invalid URL. Please check the M3U link." }
}
