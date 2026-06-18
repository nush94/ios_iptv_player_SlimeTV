//
//  ContentView.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 10/11/2024.
//

import IPTVComponents
import IPTVModels
import RealmSwift
import SwiftUI

struct ContentView: View {
  @State private var selectedSection: AppSection = .movies
  @State private var isBottomBarHidden = false
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
    ZStack(alignment: .top) {
      selectedContent
        .padding(.top, 82)
        .padding(.bottom, isBottomBarHidden ? 0 : 92)

      AppTopNavigationBar(selectedSection: $selectedSection)
        .zIndex(2)

      VStack {
        Spacer()
        if !isBottomBarHidden {
          AppBottomNavigationBar(selectedSection: $selectedSection)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .ignoresSafeArea(.keyboard, edges: .bottom)
      .zIndex(3)
    }
      .simultaneousGesture(
        DragGesture(minimumDistance: 18)
          .onChanged { value in
            if value.translation.height < -14 {
              withAnimation(.snappy) {
                isBottomBarHidden = true
              }
            } else if value.translation.height > 14 {
              withAnimation(.snappy) {
                isBottomBarHidden = false
              }
            }
          }
      )
      .background {
        HeroHeaderView(belowFold: true)
      }
      .tint(.red)
      .preferredColorScheme(.dark)
  }

  @ViewBuilder
  private var selectedContent: some View {
    if !hasPlaylistSettings, selectedSection != .settings, selectedSection != .favorites {
      PlaylistSetupPromptView {
        withAnimation(.snappy) {
          selectedSection = .settings
          isBottomBarHidden = false
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
      case .favorites:
        FavoritesView()
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
  case favorites = "Favorites"
  case settings = "Settings"

  var id: String { rawValue }

  static var mainSections: [AppSection] {
    [.movies, .shows, .tvLive, .tvGuide]
  }

  var systemImage: String? {
    switch self {
    case .search:
      return "magnifyingglass"
    case .favorites:
      return "star.fill"
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
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 18) {
            ForEach(AppSection.mainSections) { section in
              navigationButton(for: section)
            }
          }
          .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        iconButton(for: .search)
      }
      .frame(height: 48)
      .padding(.leading, 18)
      .padding(.trailing, 12)
      .padding(.bottom, 10)
    }
    .safeAreaPadding(.top, 8)
    .background {
      Rectangle()
        .fill(.black.opacity(0.92))
        .overlay(alignment: .bottom) {
          LinearGradient(
            colors: [.clear, .black.opacity(0.34)],
            startPoint: .top,
            endPoint: .bottom
          )
        }
        .ignoresSafeArea()
    }
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(.white.opacity(0.08))
        .frame(height: 1)
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
      .frame(height: 40)
      .frame(minWidth: section.systemImage == nil ? 56 : 34)
      .contentShape(Rectangle())
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

private struct AppBottomNavigationBar: View {
  @Binding var selectedSection: AppSection

  var body: some View {
    HStack(spacing: 0) {
      bottomButton(
        title: "Home",
        systemImage: "house.fill",
        isSelected: AppSection.mainSections.contains(selectedSection) || selectedSection == .search
      ) {
        selectedSection = .movies
      }

      bottomButton(
        title: "Favorites",
        systemImage: "star.fill",
        isSelected: selectedSection == .favorites
      ) {
        selectedSection = .favorites
      }

      bottomButton(
        title: "Settings",
        systemImage: "gearshape.fill",
        isSelected: selectedSection == .settings
      ) {
        selectedSection = .settings
      }
    }
    .frame(height: 74)
    .padding(.horizontal, 10)
    .background(.ultraThinMaterial, in: Capsule())
    .overlay {
      Capsule()
        .stroke(.white.opacity(0.22), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.35), radius: 22, x: 0, y: 12)
    .padding(.horizontal, 36)
    .padding(.bottom, 12)
  }

  private func bottomButton(
    title: String,
    systemImage: String,
    isSelected: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button {
      withAnimation(.snappy) {
        action()
      }
    } label: {
      VStack(spacing: 5) {
        Image(systemName: systemImage)
          .font(.system(size: 22, weight: .semibold))

        Text(title)
          .font(.system(size: 12, weight: .bold))
      }
      .foregroundStyle(isSelected ? .white : .white.opacity(0.62))
      .frame(maxWidth: .infinity)
      .frame(height: 58)
      .background {
        if isSelected {
          Capsule()
            .fill(.white.opacity(0.16))
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
  }
}

private struct FavoritesView: View {
  @ObservedResults(FavoriEntity.self) private var favorites
  @State private var selectedStreamURL: URL?
  @State private var currentID = 9999
  @State private var selectedKind: KindMedia = .vod
  @State private var showPlayer = false

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 24) {
          Text("Favorites")
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(.white)
            .padding(.top, 10)

          if favorites.isEmpty {
            LibraryEmptyStateView(
              systemImage: "star",
              title: "No favorites yet",
              message: "Long press a movie, show, or live channel to add it here."
            )
            .padding(.top, 36)
          } else {
            FavoriMovieShelf(kindMedia: .vod) { stream in
              open(stream)
            }

            FavoriSerieShelf(kindMedia: .series) { stream in
              open(stream)
            }

            FavoriLiveShelf(kindMedia: .live) { stream in
              open(stream)
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
      }
      .background {
        HeroHeaderView(belowFold: true)
      }
      .fullScreenCover(isPresented: Binding(get: {
        showPlayer && selectedStreamURL != nil
      }, set: { showPlayer = $0 })) {
        if let selectedStreamURL {
          ViewPlayerContent(mediaURL: selectedStreamURL, id: currentID, kind: selectedKind)
            .ignoresSafeArea()
        }
      }
    }
  }

  private func open(_ stream: FavoriEntity) {
    currentID = stream.id
    selectedKind = stream.kindMedia
    selectedStreamURL = URL(string: stream.streamURL())
    showPlayer = true
  }
}

private struct TVGuidePlaceholderView: View {
  @ObservedResults(CategoryEntity.self, where: ({ $0.section == KindMedia.live.rawValue })) private var categories
  @ObservedResults(CachedStream.self, where: ({ $0.section == KindMedia.live.rawValue })) private var channels
  @ObservedResults(CachedEPGProgram.self) private var epgPrograms

  @State private var selectedCategoryId: String?
  @State private var selectedChannel: CachedStream?
  @State private var selectedStreamURL: URL?
  @State private var currentID = 9999
  @State private var showPlayer = false
  @State private var isRefreshingEPG = false
  @State private var requestedEPGStreamIds = Set<Int>()

  private var visibleChannels: [CachedStream] {
    let filteredChannels: [CachedStream]
    if let selectedCategoryId {
      filteredChannels = channels.filter { $0.categoryId == selectedCategoryId }
    } else {
      filteredChannels = Array(channels)
    }

    return filteredChannels.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }

  var body: some View {
    NavigationStack {
      GeometryReader { proxy in
        Group {
          if categories.isEmpty || channels.isEmpty {
            emptyState
          } else if proxy.size.width > proxy.size.height {
            landscapeLayout(width: proxy.size.width, height: proxy.size.height)
          } else {
            portraitLayout
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      }
      .navigationTitle("")
      .onAppear {
        selectFirstChannelIfNeeded()
        refreshVisibleEPGIfNeeded()
      }
      .onChange(of: selectedCategoryId) {
        selectFirstChannelIfNeeded(force: true)
        refreshVisibleEPGIfNeeded()
      }
      .background {
        HeroHeaderView(belowFold: true)
      }
      .fullScreenCover(isPresented: Binding(get: {
        showPlayer && selectedStreamURL != nil
      }, set: { showPlayer = $0 })) {
        if let selectedStreamURL {
          ViewPlayerContent(mediaURL: selectedStreamURL, id: currentID, kind: .live)
            .ignoresSafeArea()
        }
      }
    }
  }

  // MARK: - Layouts

  private var portraitLayout: some View {
    VStack(spacing: 0) {
      previewPlayer
        .padding(.horizontal, 16)
        .padding(.top, 8)

      channelsHeader
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)

      categoryBar
        .padding(.bottom, 8)

      channelList
    }
  }

  private func landscapeLayout(width: CGFloat, height: CGFloat) -> some View {
    let leftWidth = max(260, min(340, width * 0.32))
    let rightWidth = width - leftWidth - 1
    // Largest 16:9 video that fits the pane width and leaves room for the info block.
    let videoWidth = max(220, min(rightWidth - 24, (height - 24 - 92) * 16 / 9))

    return HStack(spacing: 0) {
      VStack(spacing: 0) {
        channelsHeader
          .padding(.horizontal, 16)
          .padding(.top, 10)
          .padding(.bottom, 10)

        categoryBar
          .padding(.bottom, 10)

        channelList
      }
      .frame(width: leftWidth)
      .clipped()

      Rectangle()
        .fill(.white.opacity(0.08))
        .frame(width: 1)

      VStack(spacing: 0) {
        Spacer(minLength: 0)
        previewPlayer
          .frame(width: videoWidth)
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
  }

  // MARK: - Sections

  private var emptyState: some View {
    ScrollView {
      LibraryEmptyStateView(
        systemImage: "calendar",
        title: "No guide channels yet",
        message: "Add your Xtream playlist in Settings, then tap Save & Load Playlist."
      )
      .padding(.top, 36)
      .padding(.horizontal, 16)
    }
  }

  private var previewPlayer: some View {
    GuidePreviewPlayer(
      channel: selectedChannel,
      program: selectedChannel.flatMap { nowProgram(for: $0) },
      categoryName: selectedChannel.map { categoryName(for: $0.categoryId) } ?? "Live TV",
      onFullscreen: { if let selectedChannel { open(selectedChannel) } }
    )
  }

  private var channelsHeader: some View {
    HStack(spacing: 12) {
      Text("Channels")
        .font(.system(size: 20, weight: .bold))
        .foregroundStyle(.white)

      Spacer()

      Button(action: refreshVisibleEPG) {
        Group {
          if isRefreshingEPG {
            ProgressView().tint(.white)
          } else {
            Image(systemName: "arrow.clockwise")
              .font(.system(size: 15, weight: .bold))
          }
        }
        .frame(width: 36, height: 36)
        .background(.white.opacity(0.10), in: Circle())
      }
      .buttonStyle(.plain)
      .disabled(isRefreshingEPG)
    }
  }

  private var categoryBar: some View {
    CategoryFilterBar(categories: categories, selectedCategoryId: $selectedCategoryId)
  }

  private var channelList: some View {
    ScrollView {
      LazyVStack(spacing: 8) {
        ForEach(visibleChannels, id: \.id) { channel in
          GuideChannelRow(
            channel: channel,
            program: nowProgram(for: channel),
            isSelected: selectedChannel?.id == channel.id
          ) {
            select(channel)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 4)
      .padding(.bottom, 24)
    }
    .scrollIndicators(.hidden)
  }

  private func categoryName(for categoryId: String) -> String {
    categories.first(where: { $0.id == categoryId })?.name.formatted() ?? "Live TV"
  }

  private func select(_ channel: CachedStream) {
    withAnimation(.snappy) {
      selectedChannel = channel
    }
    if !requestedEPGStreamIds.contains(channel.id), !hasFreshEPG(for: channel.id) {
      fetchEPG(for: [channel.id])
    }
  }

  private func selectFirstChannelIfNeeded(force: Bool = false) {
    let channels = visibleChannels
    let stillVisible = selectedChannel.map { current in channels.contains { $0.id == current.id } } ?? false
    if force || selectedChannel == nil || !stillVisible {
      selectedChannel = channels.first
    }
  }

  private func open(_ channel: CachedStream) {
    currentID = channel.id
    selectedStreamURL = URL(string: channel.streamURL())
    showPlayer = true
  }

  private func nowProgram(for channel: CachedStream) -> CachedEPGProgram? {
    let now = Date()
    let programs = Array(epgPrograms
      .where { $0.streamId == channel.id }
      .sorted(by: \.startDate, ascending: true))

    return programs.first { $0.startDate <= now && $0.endDate > now } ?? programs.first
  }

  private func refreshVisibleEPGIfNeeded() {
    let idsToFetch = visibleChannels
      .prefix(20)
      .map(\.id)
      .filter { !requestedEPGStreamIds.contains($0) && !hasFreshEPG(for: $0) }

    guard !idsToFetch.isEmpty else { return }
    fetchEPG(for: idsToFetch)
  }

  private func refreshVisibleEPG() {
    let idsToFetch = visibleChannels.prefix(20).map(\.id)
    requestedEPGStreamIds = requestedEPGStreamIds.subtracting(idsToFetch)
    fetchEPG(for: idsToFetch)
  }

  private func fetchEPG(for streamIds: [Int]) {
    guard !streamIds.isEmpty, !isRefreshingEPG else { return }
    isRefreshingEPG = true
    streamIds.forEach { requestedEPGStreamIds.insert($0) }

    Task {
      for streamId in streamIds {
        do {
          let response = try await fetchShortEPG(streamId: streamId)
          await cache(response.epgListings, streamId: streamId)
        } catch {
          print("EPG fetch failed for stream \(streamId): \(error)")
        }
      }

      await MainActor.run {
        isRefreshingEPG = false
      }
    }
  }

  private func fetchShortEPG(streamId: Int) async throws -> ShortEPGResponse {
    try await withCheckedThrowingContinuation { continuation in
      APIManager.shared.fetchShortEPG(streamId: streamId) { result in
        continuation.resume(with: result)
      }
    }
  }

  @MainActor
  private func cache(_ listings: [EPGListing], streamId: Int) async {
    guard !listings.isEmpty else { return }

    let realm = try! await Realm()
    do {
      try realm.write {
        let existing = realm.objects(CachedEPGProgram.self).where { $0.streamId == streamId }
        realm.delete(existing)

        for listing in listings {
          guard let startDate = listing.startDate,
                let endDate = listing.endDate
          else {
            continue
          }

          realm.add(CachedEPGProgram(
            streamId: streamId,
            title: listing.decodedTitle,
            programDescription: listing.decodedDescription,
            startDate: startDate,
            endDate: endDate
          ), update: .modified)
        }
      }
    } catch {
      print("EPG cache failed for stream \(streamId): \(error)")
    }
  }

  private func hasFreshEPG(for streamId: Int) -> Bool {
    guard let fetchedAt = epgPrograms
      .where({ $0.streamId == streamId })
      .first?
      .fetchedAt
    else {
      return false
    }

    return Date().timeIntervalSince(fetchedAt) < 60 * 60 * 4
  }
}

private struct GuidePreviewPlayer: View {
  let channel: CachedStream?
  let program: CachedEPGProgram?
  let categoryName: String
  let onFullscreen: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ZStack {
        if let channel, let url = URL(string: channel.streamURL()) {
          VideoPlayerView(streamURL: url, id: channel.id, kind: .live)
            .id(channel.id)
        } else {
          ZStack {
            Color.black
            VStack(spacing: 8) {
              Image(systemName: "tv")
                .font(.system(size: 30, weight: .semibold))
              Text("Select a channel")
                .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.6))
          }
        }
      }
      .aspectRatio(16.0 / 9.0, contentMode: .fit)
      .frame(maxWidth: .infinity)
      .background(.black)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(alignment: .topLeading) {
        if channel != nil {
          HStack(spacing: 5) {
            Circle().fill(.red).frame(width: 7, height: 7)
            Text("LIVE")
              .font(.caption2.weight(.heavy))
              .foregroundStyle(.white)
          }
          .padding(.horizontal, 9)
          .padding(.vertical, 5)
          .background(.black.opacity(0.55), in: Capsule())
          .padding(10)
        }
      }
      .overlay(alignment: .bottomTrailing) {
        if channel != nil {
          Button(action: onFullscreen) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(.white)
              .frame(width: 34, height: 34)
              .background(.black.opacity(0.55), in: Circle())
          }
          .buttonStyle(.plain)
          .padding(10)
        }
      }

      if let channel {
        VStack(alignment: .leading, spacing: 4) {
          Text(channel.name.formatted())
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)

          Text(program?.title ?? "Program information unavailable")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.78))
            .lineLimit(1)

          Text(subtitle)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.5))
            .lineLimit(1)
        }
      }
    }
  }

  private var subtitle: String {
    guard let program else {
      return "\(categoryName) • Tap fullscreen to watch"
    }
    return "Now: \(GuideTime.range(program.startDate, program.endDate)) • \(categoryName)"
  }
}

private struct GuideChannelRow: View {
  let channel: CachedStream
  let program: CachedEPGProgram?
  let isSelected: Bool
  let action: () -> Void

  private var fillColor: Color {
    isSelected ? Color.red.opacity(0.16) : Color.white.opacity(0.06)
  }

  private var strokeColor: Color {
    isSelected ? Color.red.opacity(0.6) : Color.white.opacity(0.08)
  }

  @ViewBuilder
  private var logo: some View {
    if let imageUrl = channel.getImage(), !imageUrl.isEmpty, let url = URL(string: imageUrl) {
      AsyncImage(url: url, placeholder: {
        Image(systemName: "tv").foregroundStyle(.white.opacity(0.6))
      }, content: { image in
        image.resizable().scaledToFit()
      })
      .padding(6)
    } else {
      Image(systemName: "tv")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.white.opacity(0.7))
    }
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        logo
          .frame(width: 52, height: 52)
          .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

        VStack(alignment: .leading, spacing: 3) {
          Text(channel.name.formatted())
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)

          Text(program?.title ?? "Program information unavailable")
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.56))
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        if isSelected {
          Image(systemName: "play.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.red)
        }
      }
      .padding(10)
      .background(fillColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(strokeColor, lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }
}

private enum GuideTime {
  static func range(_ start: Date, _ end: Date) -> String {
    "\(string(start)) - \(string(end))"
  }

  static func string(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date)
  }
}

private struct PlaylistSetupPromptView: View {
  let openSettings: () -> Void

  var body: some View {
    VStack {
      Spacer(minLength: 30)

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

      Spacer(minLength: 30)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

#Preview {
  ContentView()
}
