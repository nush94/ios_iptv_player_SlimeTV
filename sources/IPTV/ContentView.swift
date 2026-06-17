//
//  ContentView.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 10/11/2024.
//

import IPTVComponents
import IPTVModels
import Realm
import SwiftUI

struct ContentView: View {
  @State private var selectedSection: AppSection = .movies
  @AppStorage("playlistURL") private var playlistURL: String = ""
  @AppStorage("apiHost") private var apiHost: String = ""
  @AppStorage("apiLogin") private var apiLogin: String = ""
  @AppStorage("apiPassword") private var apiPassword: String = ""

  private var hasPlaylistSettings: Bool {
    let hasPlaylistURL = !playlistURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let hasManualLogin = [apiHost, apiLogin, apiPassword].allSatisfy {
      !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    return hasPlaylistURL || hasManualLogin
  }

  var body: some View {
    selectedContent
      .safeAreaInset(edge: .top, spacing: 0) {
        AppTopNavigationBar(selectedSection: $selectedSection)
      }
      .background {
        HeroHeaderView(belowFold: true)
      }
      .tint(.red)
      .preferredColorScheme(.dark)
  }

  @ViewBuilder
  private var selectedContent: some View {
    if !hasPlaylistSettings, selectedSection != .settings {
      PlaylistSetupPromptView {
        withAnimation(.snappy) {
          selectedSection = .settings
        }
      }
    } else {
      switch selectedSection {
      case .movies:
        VodView(kindMedia: .vod)
      case .shows:
        SeriesView(kindMedia: .series)
      case .tvLive:
        LiveView(kindMedia: .live)
      case .tvGuide:
        TVGuidePlaceholderView()
      case .search:
        SearchView()
      case .settings:
        SettingsView()
      }
    }
  }
}

private enum AppSection: String, CaseIterable, Identifiable {
  case movies = "Movies"
  case shows = "Shows"
  case tvLive = "TV Live"
  case tvGuide = "TV Guide"
  case search = "Search"
  case settings = "Settings"

  var id: String { rawValue }

  static var mainSections: [AppSection] {
    [.movies, .shows, .tvLive, .tvGuide]
  }

  var systemImage: String? {
    switch self {
    case .search:
      return "magnifyingglass"
    case .settings:
      return "gearshape"
    default:
      return nil
    }
  }
}

private struct AppTopNavigationBar: View {
  @Binding var selectedSection: AppSection

  var body: some View {
    HStack(spacing: 8) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 24) {
          ForEach(AppSection.mainSections) { section in
            navigationButton(for: section)
          }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollClipDisabled()
      .frame(maxWidth: .infinity, alignment: .leading)

      iconButton(for: .search)
      iconButton(for: .settings)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.leading, 16)
    .padding(.trailing, 10)
    .padding(.top, 6)
    .padding(.bottom, 10)
    .background {
      LinearGradient(
        colors: [.black.opacity(0.92), .black.opacity(0.62), .black.opacity(0)],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()
    }
  }

  private func navigationButton(for section: AppSection) -> some View {
    Button {
      withAnimation(.snappy) {
        selectedSection = section
      }
    } label: {
      VStack(spacing: 6) {
        if let systemImage = section.systemImage {
          Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
        } else {
          Text(section.rawValue)
            .font(.system(size: 16, weight: selectedSection == section ? .bold : .semibold))
        }

        Capsule()
          .fill(selectedSection == section ? .red : .clear)
          .frame(width: selectedSection == section ? 32 : 0, height: 3)
      }
      .foregroundStyle(selectedSection == section ? .white : .white.opacity(0.62))
      .frame(minWidth: section.systemImage == nil ? 58 : 34)
    }
    .buttonStyle(.plain)
  }

  private func iconButton(for section: AppSection) -> some View {
    Button {
      withAnimation(.snappy) {
        selectedSection = section
      }
    } label: {
      VStack(spacing: 6) {
        Image(systemName: section.systemImage ?? "")
          .font(.system(size: 20, weight: .semibold))

        Capsule()
          .fill(selectedSection == section ? .red : .clear)
          .frame(width: selectedSection == section ? 22 : 0, height: 3)
      }
      .foregroundStyle(selectedSection == section ? .white : .white.opacity(0.66))
      .frame(width: 44, height: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(section.rawValue)
  }
}

private struct TVGuidePlaceholderView: View {
  var body: some View {
    NavigationStack {
      ZStack {
        HeroHeaderView(belowFold: true)

        LibraryEmptyStateView(
          systemImage: "calendar",
          title: "TV Guide",
          message: "Guide support can be added after playlist categories and EPG data are connected."
        )
        .padding(.horizontal, 16)
      }
    }
  }
}

private struct PlaylistSetupPromptView: View {
  let openSettings: () -> Void

  var body: some View {
    ZStack {
      HeroHeaderView(belowFold: true)

      VStack(spacing: 18) {
        Image(systemName: "plus.rectangle.on.folder")
          .font(.system(size: 40, weight: .semibold))
          .foregroundStyle(.white)
          .frame(width: 76, height: 76)
          .background(.white.opacity(0.12), in: Circle())

        VStack(spacing: 8) {
          Text("Add Your Playlist")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(.white)

          Text("Add your Xtream playlist once, then Movies, Shows, and Live TV will appear here.")
            .font(.callout)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.68))
            .lineSpacing(2)
        }

        Button(action: openSettings) {
          HStack(spacing: 8) {
            Image(systemName: "gearshape")
            Text("Open Settings")
          }
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 52)
          .background(.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 30)
      .frame(maxWidth: 390)
      .padding(.horizontal, 22)
    }
  }
}

#Preview {
  ContentView()
}
