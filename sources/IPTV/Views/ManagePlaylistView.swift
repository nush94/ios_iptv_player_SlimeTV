//
//  ManagePlaylistView.swift
//  IPTV
//
//  Editable Xtream playlist connection form, presented as a sheet from
//  the Settings screen. All credential editing + library loading lives here.
//

import IPTVModels
import SwiftUI

struct ManagePlaylistView: View {
  @Environment(\.dismiss) private var dismiss

  @AppStorage("apiLogin") private var apiLogin: String = AppConfig.apiLogin
  @AppStorage("apiPassword") private var apiPassword: String = AppConfig.apiPassword
  @AppStorage("apiHost") private var apiHost: String = AppConfig.apiHost
  @AppStorage("playlistURL") private var playlistURL: String = ""

  @State private var showErrorMessage = false
  @State private var errorMessage = ""
  @State private var isLoadingPlaylist = false
  @State private var loadStatus = ""

  var body: some View {
    NavigationStack {
      Group {
        if isLoadingPlaylist {
          PlaylistImportLoadingView(statusText: loadStatus)
        } else {
          formContent
        }
      }
      .background(Color.black.ignoresSafeArea())
      .navigationTitle("Manage Playlist")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          if !isLoadingPlaylist {
            Button("Done") { dismiss() }
              .foregroundStyle(.white)
          }
        }
      }
      .preferredColorScheme(.dark)
      .alert("Error", isPresented: $showErrorMessage) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage)
      }
      .onAppear(perform: seedDefaultSettingsIfNeeded)
      .interactiveDismissDisabled(isLoadingPlaylist)
    }
  }

  // MARK: - Building blocks

  private var formContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        section("Xtream Playlist") {
          settingsTextField("Full playlist URL", text: $playlistURL)
            .keyboardType(.URL)

          Button(action: fillFieldsFromPlaylistURL) {
            HStack(spacing: 8) {
              Image(systemName: "link")
              Text("Fill From URL")
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
          }
          .buttonStyle(.plain)
          .foregroundStyle(.red)
          .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }

        section("Connection") {
          settingsTextField("Server URL", text: $apiHost)
            .keyboardType(.URL)
          settingsTextField("Username", text: $apiLogin)
            .textContentType(.username)
          settingsSecureField("Password", text: $apiPassword)
        }

        Button(action: saveAndLoadPlaylist) {
          Text("Save & Load Playlist")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)

        if !loadStatus.isEmpty {
          Text(loadStatus)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.64))
            .frame(maxWidth: .infinity, alignment: .center)
        }
      }
      .padding(20)
    }
  }

  @ViewBuilder
  private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title)
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(.white.opacity(0.66))
        .textCase(.uppercase)
      content()
    }
  }

  private func settingsTextField(_ placeholder: String, text: Binding<String>) -> some View {
    TextField(placeholder, text: text)
      .textInputAutocapitalization(.never)
      .disableAutocorrection(true)
      .foregroundStyle(.white)
      .padding(.horizontal, 14)
      .frame(height: 48)
      .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(.white.opacity(0.10), lineWidth: 1)
      }
  }

  private func settingsSecureField(_ placeholder: String, text: Binding<String>) -> some View {
    SecureField(placeholder, text: text)
      .textContentType(.password)
      .textInputAutocapitalization(.never)
      .disableAutocorrection(true)
      .foregroundStyle(.white)
      .padding(.horizontal, 14)
      .frame(height: 48)
      .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .stroke(.white.opacity(0.10), lineWidth: 1)
      }
  }

  // MARK: - Actions

  private func saveAndLoadPlaylist() {
    guard !isLoadingPlaylist, validateAndSaveSettings() else { return }

    PlaylistService.refreshUserInfo()
    isLoadingPlaylist = true
    loadStatus = "Connecting..."

    Task {
      do {
        try await PlaylistService.loadFullPlaylist { loadStatus = $0 }
        isLoadingPlaylist = false
        loadStatus = "Playlist loaded."
        NotificationCenter.default.post(name: .playlistImportCompleted, object: nil)
        dismiss()
      } catch {
        isLoadingPlaylist = false
        errorMessage = error.localizedDescription
        showErrorMessage = true
        loadStatus = "Could not load playlist."
      }
    }
  }

  private func validateAndSaveSettings() -> Bool {
    guard applyPlaylistURLIfPresent() else { return false }

    if apiLogin.isEmpty {
      return fail("Username is required.")
    }
    if apiPassword.isEmpty {
      return fail("Password is required.")
    }
    if apiHost.isEmpty {
      return fail("Server URL is required.")
    }

    apiHost = PlaylistService.normalizedServerURL(apiHost)
    return true
  }

  private func fail(_ message: String) -> Bool {
    errorMessage = message
    showErrorMessage = true
    return false
  }

  private func fillFieldsFromPlaylistURL() {
    guard !playlistURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      _ = fail("Playlist URL is required.")
      return
    }
    if applyPlaylistURLIfPresent() {
      loadStatus = "URL filled. Tap Save & Load Playlist."
    }
  }

  private func applyPlaylistURLIfPresent() -> Bool {
    let trimmed = playlistURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return true }

    guard let credentials = PlaylistService.parseXtreamURL(trimmed) else {
      return fail("Paste a valid Xtream M3U or player_api URL with username and password.")
    }

    playlistURL = trimmed
    apiHost = credentials.host
    apiLogin = credentials.username
    apiPassword = credentials.password
    return true
  }

  private func seedDefaultSettingsIfNeeded() {
    if apiHost.isEmpty, !AppConfig.apiHost.isEmpty { apiHost = AppConfig.apiHost }
    if apiPassword.isEmpty, !AppConfig.apiPassword.isEmpty { apiPassword = AppConfig.apiPassword }
    if apiLogin.isEmpty, !AppConfig.apiLogin.isEmpty { apiLogin = AppConfig.apiLogin }
  }
}

private struct PlaylistImportLoadingView: View {
  let statusText: String

  private var activePhase: String {
    let lowercased = statusText.lowercased()
    if lowercased.contains("search") { return "Search" }
    if lowercased.contains("final") { return "Ready" }
    if lowercased.contains("live") { return "Live TV" }
    if lowercased.contains("movie") { return "Movies" }
    if lowercased.contains("show") { return "Shows" }
    return "Connecting"
  }

  var body: some View {
    VStack(spacing: 26) {
      Spacer(minLength: 28)

      ZStack {
        Circle()
          .fill(.red.opacity(0.14))
          .frame(width: 96, height: 96)

        ProgressView()
          .tint(.red)
          .scaleEffect(1.45)
      }

      VStack(spacing: 8) {
        Text("Downloading Playlist")
          .font(.system(size: 30, weight: .bold))
          .foregroundStyle(.white)
          .multilineTextAlignment(.center)

        Text(statusText.isEmpty ? "Connecting..." : statusText)
          .font(.callout.weight(.semibold))
          .foregroundStyle(.white.opacity(0.68))
          .multilineTextAlignment(.center)
      }

      VStack(spacing: 10) {
        phaseRow(title: "Live TV", systemImage: "tv", isActive: activePhase == "Live TV")
        phaseRow(title: "Movies", systemImage: "film", isActive: activePhase == "Movies")
        phaseRow(title: "Shows", systemImage: "rectangle.stack", isActive: activePhase == "Shows")
        phaseRow(title: "Search", systemImage: "magnifyingglass", isActive: activePhase == "Search")
        phaseRow(title: "Ready", systemImage: "checkmark.circle", isActive: activePhase == "Ready")
      }
      .padding(16)
      .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(.white.opacity(0.10), lineWidth: 1)
      }

      Spacer()
    }
    .padding(.horizontal, 28)
  }

  private func phaseRow(title: String, systemImage: String, isActive: Bool) -> some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(isActive ? .white : .white.opacity(0.48))
        .frame(width: 34, height: 34)
        .background(isActive ? .red : .white.opacity(0.08), in: Circle())

      Text(title)
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(isActive ? .white : .white.opacity(0.62))

      Spacer()

      if isActive {
        ProgressView()
          .tint(.white)
          .scaleEffect(0.82)
      }
    }
  }
}

extension Notification.Name {
  static let playlistImportCompleted = Notification.Name("playlistImportCompleted")
}
