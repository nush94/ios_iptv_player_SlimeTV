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
  @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true

  @State private var showManagePlaylist = false
  @State private var showAdvanced = false
  @State private var showNotifications = false
  @State private var showClearCacheAlert = false
  @State private var showLogOutAlert = false
  @State private var isRefreshingAccount = false

  private var isConfigured: Bool {
    !playlistURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || [apiHost, apiLogin, apiPassword].allSatisfy {
        !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("Settings")
          .font(.system(size: 36, weight: .bold))
          .foregroundStyle(.white)
          .padding(.top, 8)
          .padding(.bottom, 2)

        playlistCard
        accountCard
        appCard
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 36)
    }
    .background(Color.black.ignoresSafeArea())
    .preferredColorScheme(.dark)
    .sheet(isPresented: $showManagePlaylist) { ManagePlaylistView() }
    .sheet(isPresented: $showAdvanced) { AdvancedPlaylistView() }
    .sheet(isPresented: $showNotifications) {
      NotificationsSettingsView(enabled: $notificationsEnabled)
    }
    .alert("Clear Cache", isPresented: $showClearCacheAlert) {
      Button("Clear", role: .destructive) { CacheManager.shared.resetDatabase() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This removes downloaded Movies, Shows, and Live data. Your playlist stays saved and will reload from Manage Playlist.")
    }
    .alert("Log Out", isPresented: $showLogOutAlert) {
      Button("Log Out", role: .destructive) { logOut() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This clears your playlist credentials and cached library from this device.")
    }
  }

  // MARK: - Playlist card

  private var playlistCard: some View {
    SettingsCard {
      cardHeader(title: "Playlist", statusText: isConfigured ? "Connected" : "Not connected", isOn: isConfigured)

      if isConfigured {
        if !expDate.isEmpty {
          expirationLine
        }

        VStack(spacing: 10) {
          summaryRow(label: "Server", value: PlaylistService.displayHost(apiHost), mono: true)
          divider
          summaryRow(label: "Username", value: apiLogin.isEmpty ? "—" : apiLogin, mono: true)
          divider
          summaryRow(label: "Password", value: apiPassword.isEmpty ? "—" : "••••••••", mono: true)
        }
        .padding(.top, 4)
      } else {
        Text("No playlist added yet. Tap Manage Playlist to connect.")
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.6))
      }

      Button {
        showManagePlaylist = true
      } label: {
        Text("Manage Playlist")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .background(.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
      .buttonStyle(.plain)
      .padding(.top, 4)

      Button {
        showAdvanced = true
      } label: {
        HStack {
          Text("Advanced")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
          Spacer()
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white.opacity(0.4))
        }
        .frame(height: 26)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Account card

  private var accountCard: some View {
    SettingsCard {
      cardHeader(
        title: "Account",
        statusText: status.isEmpty ? (isConfigured ? "Active" : "Inactive") : status.capitalized,
        isOn: isConfigured
      )

      if !expDate.isEmpty {
        expirationLine
      }

      Button(action: refreshAccount) {
        HStack(spacing: 8) {
          if isRefreshingAccount {
            ProgressView().tint(.white)
          } else {
            Image(systemName: "arrow.clockwise")
          }
          Text("Refresh Account")
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(.white.opacity(0.22), lineWidth: 1)
        }
      }
      .buttonStyle(.plain)
      .disabled(isRefreshingAccount || !isConfigured)
      .opacity(isConfigured ? 1 : 0.5)
      .padding(.top, 2)
    }
  }

  // MARK: - App card

  private var appCard: some View {
    SettingsCard(spacing: 0) {
      appRow(icon: "trash", title: "Clear Cache") { showClearCacheAlert = true }
      divider
      appRow(icon: "bell", title: "Notifications") { showNotifications = true }
      divider
      appRow(icon: "rectangle.portrait.and.arrow.right", title: "Log Out", tint: .red) {
        showLogOutAlert = true
      }
    }
  }

  // MARK: - Reusable pieces

  private func cardHeader(title: String, statusText: String, isOn: Bool) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .font(.system(size: 20, weight: .bold))
        .foregroundStyle(.white)
      Spacer()
      HStack(spacing: 6) {
        Circle()
          .fill(isOn ? Color.green : Color.white.opacity(0.3))
          .frame(width: 8, height: 8)
        Text(statusText)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(isOn ? .white.opacity(0.85) : .white.opacity(0.5))
      }
    }
  }

  private var expirationLine: some View {
    Text("Expires: \(expDate)")
      .font(.footnote.weight(.medium))
      .foregroundStyle(.white.opacity(0.55))
  }

  private func summaryRow(label: String, value: String, mono: Bool = false) -> some View {
    HStack {
      Text(label)
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.55))
      Spacer()
      Text(value)
        .font(mono ? .system(.subheadline, design: .monospaced) : .subheadline)
        .foregroundStyle(.white)
        .lineLimit(1)
        .truncationMode(.middle)
    }
  }

  private func appRow(icon: String, title: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: icon)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(tint)
          .frame(width: 26)
        Text(title)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(tint)
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(.white.opacity(0.4))
      }
      .frame(height: 52)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var divider: some View {
    Rectangle()
      .fill(.white.opacity(0.08))
      .frame(height: 1)
  }

  // MARK: - Actions

  private func refreshAccount() {
    isRefreshingAccount = true
    PlaylistService.refreshUserInfo()
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
      isRefreshingAccount = false
    }
  }

  private func logOut() {
    CacheManager.shared.resetDatabase()
    playlistURL = ""
    apiHost = ""
    apiLogin = ""
    apiPassword = ""
    expDate = ""
    status = ""
  }
}

// MARK: - Card container

private struct SettingsCard<Content: View>: View {
  var spacing: CGFloat = 14
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: spacing) {
      content
    }
    .padding(.horizontal, 18)
    .padding(.vertical, spacing == 0 ? 4 : 18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(.white.opacity(0.08), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
  }
}

// MARK: - Advanced sheet

private struct AdvancedPlaylistView: View {
  @Environment(\.dismiss) private var dismiss
  @AppStorage("playlistURL") private var playlistURL: String = ""
  @AppStorage("apiHost") private var apiHost: String = ""

  @State private var isReloading = false
  @State private var statusText = ""
  @State private var showResetAlert = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          VStack(alignment: .leading, spacing: 8) {
            Text("PLAYLIST URL")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(.white.opacity(0.55))
            Text(playlistURL.isEmpty ? PlaylistService.normalizedServerURL(apiHost) : playlistURL)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(.white.opacity(0.85))
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(12)
              .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
          }

          Button(action: reload) {
            HStack(spacing: 10) {
              if isReloading { ProgressView().tint(.white) }
              Text(isReloading ? "Reloading…" : "Reload Playlist")
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
          .buttonStyle(.plain)
          .disabled(isReloading)

          Button { showResetAlert = true } label: {
            Text("Reset Library")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(.red)
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .stroke(.red.opacity(0.5), lineWidth: 1)
              }
          }
          .buttonStyle(.plain)

          if !statusText.isEmpty {
            Text(statusText)
              .font(.footnote.weight(.medium))
              .foregroundStyle(.white.opacity(0.64))
              .frame(maxWidth: .infinity, alignment: .center)
          }
        }
        .padding(20)
      }
      .background(Color.black.ignoresSafeArea())
      .navigationTitle("Advanced")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }.foregroundStyle(.white)
        }
      }
      .preferredColorScheme(.dark)
      .alert("Reset Library", isPresented: $showResetAlert) {
        Button("Reset", role: .destructive) { PlaylistService.clearCachedLibrary() }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("Removes all cached content. Reload Playlist to fetch it again.")
      }
    }
  }

  private func reload() {
    isReloading = true
    statusText = "Connecting..."
    Task {
      do {
        try await PlaylistService.loadFullPlaylist { statusText = $0 }
        statusText = "Playlist reloaded."
      } catch {
        statusText = "Could not reload: \(error.localizedDescription)"
      }
      isReloading = false
    }
  }
}

// MARK: - Notifications sheet

private struct NotificationsSettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var enabled: Bool

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 14) {
          Toggle(isOn: $enabled) {
            VStack(alignment: .leading, spacing: 2) {
              Text("Allow Notifications")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
              Text("Get alerts about new content and reminders.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.55))
            }
          }
          .tint(.red)
          .padding(16)
          .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(20)
      }
      .background(Color.black.ignoresSafeArea())
      .navigationTitle("Notifications")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }.foregroundStyle(.white)
        }
      }
      .preferredColorScheme(.dark)
    }
  }
}
