//
//  SettingsView.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 19/11/2024.
//

import Foundation
import IPTVModels
import RealmSwift
import SwiftUI

struct SettingsView: View {
  @AppStorage("apiLogin") private var apiLogin: String = AppConfig.apiLogin
  @AppStorage("apiPassword") private var apiPassword: String = AppConfig.apiPassword
  @AppStorage("apiHost") private var apiHost: String = AppConfig.apiHost
  @AppStorage("playlistURL") private var playlistURL: String = ""
  @AppStorage("expDate") private var expDate: String = ""
  @AppStorage("status") private var status: String = ""

  @State private var showSavedMessage: Bool = false
  @State private var showErrorMessage: Bool = false
  @State private var errorMessage: String = ""
  @State private var isLoadingPlaylist: Bool = false
  @State private var loadStatus: String = ""

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Text("Settings")
          .font(.system(size: 36, weight: .bold))
          .foregroundStyle(.white)
          .padding(.top, 14)

        VStack(alignment: .leading, spacing: 14) {
          sectionTitle("Xtream Playlist")

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

        VStack(alignment: .leading, spacing: 14) {
          sectionTitle("Connection")

          settingsTextField("Server URL", text: $apiHost)
            .keyboardType(.URL)
          settingsTextField("Username", text: $apiLogin)
            .textContentType(.username)
          settingsSecureField("Password", text: $apiPassword)

          Button(action: saveAndLoadPlaylist) {
            HStack(spacing: 10) {
              if isLoadingPlaylist {
                ProgressView()
                  .tint(.white)
              }
              Text(isLoadingPlaylist ? "Loading Playlist" : "Save & Load Playlist")
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
          .buttonStyle(.plain)
          .disabled(isLoadingPlaylist)
          .opacity(isLoadingPlaylist ? 0.75 : 1)

          if !loadStatus.isEmpty {
            Text(loadStatus)
              .font(.footnote.weight(.medium))
              .foregroundStyle(.white.opacity(0.64))
          }
        }

        if !status.isEmpty || !expDate.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Account")
            Text("\(status) - Expires: \(expDate)")
              .font(.callout)
              .foregroundStyle(.white.opacity(0.72))
          }
          .padding(.top, 4)
        }
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 34)
    }
    .background {
      Color.black.ignoresSafeArea()
    }
    .alert(isPresented: $showSavedMessage) {
      Alert(
        title: Text("Playlist Ready"),
        message: Text("Your Xtream playlist was saved and loaded."),
        dismissButton: .default(Text("OK"))
      )
    }
    .alert(isPresented: $showErrorMessage) {
      Alert(
        title: Text("Error"),
        message: Text(errorMessage),
        dismissButton: .default(Text("OK"))
      )
    }
    .onAppear {
      seedDefaultSettingsIfNeeded()
    }
  }

  private func sectionTitle(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 15, weight: .bold))
      .foregroundStyle(.white.opacity(0.66))
      .textCase(.uppercase)
  }

  private func settingsTextField(
    _ placeholder: String,
    text: Binding<String>
  ) -> some View {
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

  private func validateAndSaveSettings() -> Bool {
    guard applyPlaylistURLIfPresent() else {
      return false
    }

    if apiLogin.isEmpty {
      errorMessage = "Username is required."
      showErrorMessage = true
      return false
    }

    if apiPassword.isEmpty {
      errorMessage = "Password is required."
      showErrorMessage = true
      return false
    }

    if apiHost.isEmpty {
      errorMessage = "Server URL is required."
      showErrorMessage = true
      return false
    }

    apiHost = normalizedServerURL(apiHost)
    return true
  }

  private func saveSettings(showAlert: Bool = true) {
    if showAlert {
      showSavedMessage = true
    }

    APIManager.shared.fetchInfoUser(from: "\(APIManager.shared.baseURL)&action=get_infos") { result in
      switch result {
      case let .success(userInfo):
        print(userInfo)
        UserDefaults.standard.set(userInfo.userInfo.expDate.formatted(), forKey: "expDate")
        UserDefaults.standard.set(userInfo.userInfo.status, forKey: "status")
        UserDefaults.standard.synchronize()
      case let .failure(failure):
        print(failure)
      }
    }
  }

  private func saveAndLoadPlaylist() {
    guard !isLoadingPlaylist else {
      return
    }

    guard validateAndSaveSettings() else {
      return
    }

    saveSettings(showAlert: false)
    isLoadingPlaylist = true
    loadStatus = "Connecting..."

    Task {
      do {
        try await loadFullPlaylist()
        await MainActor.run {
          isLoadingPlaylist = false
          loadStatus = "Playlist loaded."
          showSavedMessage = true
        }
      } catch {
        await MainActor.run {
          isLoadingPlaylist = false
          errorMessage = error.localizedDescription
          showErrorMessage = true
          loadStatus = "Could not load playlist."
        }
      }
    }
  }

  private func seedDefaultSettingsIfNeeded() {
    if apiHost.isEmpty, !AppConfig.apiHost.isEmpty {
      apiHost = AppConfig.apiHost
    }

    if apiPassword.isEmpty, !AppConfig.apiPassword.isEmpty {
      apiPassword = AppConfig.apiPassword
    }

    if apiLogin.isEmpty, !AppConfig.apiLogin.isEmpty {
      apiLogin = AppConfig.apiLogin
    }
  }

  private func fillFieldsFromPlaylistURL() {
    guard !playlistURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      errorMessage = "Playlist URL is required."
      showErrorMessage = true
      return
    }

    if applyPlaylistURLIfPresent() {
      loadStatus = "URL filled. Tap Save & Load Playlist."
    }
  }

  private func applyPlaylistURLIfPresent() -> Bool {
    let trimmedPlaylistURL = playlistURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedPlaylistURL.isEmpty else {
      return true
    }

    guard let credentials = parseXtreamURL(trimmedPlaylistURL) else {
      errorMessage = "Paste a valid Xtream M3U or player_api URL with username and password."
      showErrorMessage = true
      return false
    }

    playlistURL = trimmedPlaylistURL
    apiHost = credentials.host
    apiLogin = credentials.username
    apiPassword = credentials.password
    return true
  }

  private func parseXtreamURL(_ value: String) -> XtreamCredentials? {
    let normalizedValue = value.contains("://") ? value : "http://\(value)"
    guard let components = URLComponents(string: normalizedValue),
          let scheme = components.scheme,
          let host = components.host
    else {
      return nil
    }

    let port = components.port.map { ":\($0)" } ?? ""
    let serverURL = "\(scheme)://\(host)\(port)"
    var username = queryValue(named: "username", in: components) ?? queryValue(named: "user", in: components) ?? ""
    var password = queryValue(named: "password", in: components) ?? queryValue(named: "pass", in: components) ?? ""

    if username.isEmpty || password.isEmpty {
      let pathParts = components.path
        .split(separator: "/")
        .map(String.init)

      if pathParts.count >= 3, ["live", "movie", "series"].contains(pathParts[0].lowercased()) {
        username = pathParts[1]
        password = pathParts[2]
      } else if pathParts.count >= 2, !pathParts[0].hasSuffix(".php") {
        username = pathParts[0]
        password = pathParts[1]
      }
    }

    guard !username.isEmpty, !password.isEmpty else {
      return nil
    }

    return XtreamCredentials(host: serverURL, username: username, password: password)
  }

  private func loadFullPlaylist() async throws {
    await updateLoadStatus("Checking playlist...")

    let liveCategories = try await fetchCategories(action: "get_live_categories")
    let movieCategories = try await fetchCategories(action: "get_vod_categories")
    let seriesCategories = try await fetchCategories(action: "get_series_categories")

    await MainActor.run {
      clearCachedLibrary()
    }

    await updateLoadStatus("Loading Live...")
    await CacheManager.shared.cacheCategories(liveCategories, for: KindMedia.live.rawValue)
    for category in liveCategories {
      let streams = try await fetchStreams(action: "get_live_streams", categoryId: category.id)
      CacheManager.shared.cacheStreams(streams, for: KindMedia.live.rawValue)
    }

    await updateLoadStatus("Loading Movies...")
    await CacheManager.shared.cacheCategories(movieCategories, for: KindMedia.vod.rawValue)
    for category in movieCategories {
      let streams = try await fetchStreams(action: "get_vod_streams", categoryId: category.id)
      CacheManager.shared.cacheStreams(streams, for: KindMedia.vod.rawValue)
    }

    await updateLoadStatus("Loading Shows...")
    await CacheManager.shared.cacheCategories(seriesCategories, for: KindMedia.series.rawValue)
    for category in seriesCategories {
      let series = try await fetchSeries(categoryId: category.id)
      CacheManager.shared.cacheSeries(series, for: KindMedia.series.rawValue)
    }
  }

  @MainActor
  private func updateLoadStatus(_ value: String) {
    loadStatus = value
  }

  private func fetchCategories(action: String) async throws -> [IPTVModels.Category] {
    guard let url = URL(string: "\(APIManager.shared.baseURL)&action=\(action)") else {
      throw PlaylistLoadError.invalidURL
    }

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[IPTVModels.Category], Error>) in
      APIManager.shared.fetchCategories(from: url) { result in
        continuation.resume(with: result)
      }
    }
  }

  private func fetchStreams(action: String, categoryId: String) async throws -> [IPTVModels.Stream] {
    let apiURL = "\(APIManager.shared.baseURL)&action=\(action)&category_id=\(categoryId)"

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[IPTVModels.Stream], Error>) in
      APIManager.shared.fetchStreams(for: apiURL) { result in
        continuation.resume(with: result)
      }
    }
  }

  private func fetchSeries(categoryId: String) async throws -> [IPTVModels.Series] {
    let apiURL = "\(APIManager.shared.baseURL)&action=get_series&category_id=\(categoryId)"

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[IPTVModels.Series], Error>) in
      APIManager.shared.fetchSeries(for: apiURL) { result in
        continuation.resume(with: result)
      }
    }
  }

  private func clearCachedLibrary() {
    let realm = try! Realm()
    do {
      try realm.write {
        realm.delete(realm.objects(CategoryEntity.self))
        realm.delete(realm.objects(CachedStream.self))
        realm.delete(realm.objects(CachedSeries.self))
      }
    } catch {
      print("Error clearing library: \(error)")
    }
  }

  private func normalizedServerURL(_ value: String) -> String {
    var normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if !normalizedValue.contains("://") {
      normalizedValue = "http://\(normalizedValue)"
    }

    while normalizedValue.hasSuffix("/") {
      normalizedValue.removeLast()
    }

    return normalizedValue
  }

  private func queryValue(named name: String, in components: URLComponents) -> String? {
    components.queryItems?
      .first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?
      .value
  }

  private struct XtreamCredentials {
    let host: String
    let username: String
    let password: String
  }

  private enum PlaylistLoadError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
      "The Xtream server URL is not valid."
    }
  }
}
