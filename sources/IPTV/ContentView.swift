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
        .padding(.top, selectedSection == .settings ? 12 : 82)
        .padding(.bottom, isBottomBarHidden ? 0 : 92)

      if selectedSection != .settings {
        AppTopNavigationBar(selectedSection: $selectedSection)
          .zIndex(2)
      }

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
      .onReceive(NotificationCenter.default.publisher(for: .playlistImportCompleted)) { _ in
        withAnimation(.snappy) {
          selectedSection = .movies
          isBottomBarHidden = false
        }
      }
  }

  @ViewBuilder
  private var selectedContent: some View {
    if !hasPlaylistSettings, selectedSection != .settings, selectedSection != .favorites, selectedSection != .watching {
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
        TVView()
      case .search:
        SearchView()
      case .favorites:
        FavoritesView()
      case .watching:
        ContinueWatchingView()
      case .settings:
        SettingsView()
      }
    }
  }
}

private enum AppSection: String, CaseIterable, Identifiable {
  case movies = "Movies"
  case shows = "Shows"
  case tvLive = "TV"
  case search = "Search"
  case favorites = "Favorites"
  case watching = "Watching"
  case settings = "Settings"

  var id: String { rawValue }

  static var mainSections: [AppSection] {
    [.movies, .shows, .tvLive]
  }

  var systemImage: String? {
    switch self {
    case .search:
      return "magnifyingglass"
    case .favorites:
      return "star.fill"
    case .watching:
      return "play.rectangle.fill"
    case .settings:
      return "gearshape.fill"
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

        HStack(spacing: 4) {
          RegionMenu()
          iconButton(for: .search)
          iconButton(for: .settings)
        }
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
  @Namespace private var pillNamespace

  private struct Tab: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let target: AppSection
    let isSelected: (AppSection) -> Bool
  }

  private var tabs: [Tab] {
    [
      Tab(id: "home", title: "Home", systemImage: "house.fill", target: .movies) {
        AppSection.mainSections.contains($0) || $0 == .search
      },
      Tab(id: "favorites", title: "Favorites", systemImage: "star.fill", target: .favorites) {
        $0 == .favorites
      },
      Tab(id: "watching", title: "Watching", systemImage: "play.rectangle.fill", target: .watching) {
        $0 == .watching
      },
    ]
  }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(tabs) { tab in
        let isSelected = tab.isSelected(selectedSection)

        Button {
          withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
            selectedSection = tab.target
          }
        } label: {
          VStack(spacing: 5) {
            Image(systemName: tab.systemImage)
              .font(.system(size: 22, weight: .semibold))

            Text(tab.title)
              .font(.system(size: 12, weight: .bold))
          }
          .foregroundStyle(isSelected ? .white : .white.opacity(0.62))
          .frame(maxWidth: .infinity)
          .frame(height: 58)
          .background {
            if isSelected {
              selectionPill
                .matchedGeometryEffect(id: "selectionPill", in: pillNamespace)
            }
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
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

  /// The sliding selection indicator — real Liquid Glass on iOS 26,
  /// a frosted material capsule on earlier versions.
  @ViewBuilder
  private var selectionPill: some View {
    Group {
      if #available(iOS 26.0, *) {
        Color.clear
          .glassEffect(.regular, in: Capsule())
      } else {
        Capsule()
          .fill(.white.opacity(0.18))
          .overlay {
            Capsule().stroke(.white.opacity(0.28), lineWidth: 1)
          }
      }
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 2)
  }
}

private struct FavoritesView: View {
  @ObservedResults(FavoriEntity.self) private var favorites
  @State private var selectedStreamURL: URL?
  @State private var currentID = 9999
  @State private var selectedKind: KindMedia = .vod
  @State private var selectedPlaybackContext: PlaybackProgressContext?
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
          ViewPlayerContent(
            mediaURL: selectedStreamURL,
            id: currentID,
            kind: selectedKind,
            playbackContext: selectedPlaybackContext
          )
            .ignoresSafeArea()
        }
      }
    }
  }

  private func open(_ stream: FavoriEntity) {
    let streamURL = stream.streamURL()
    currentID = stream.id
    selectedKind = stream.kindMedia
    selectedStreamURL = URL(string: streamURL)
    if stream.kindMedia == .vod {
      selectedPlaybackContext = PlaybackProgressContext(
        mediaId: stream.id,
        kind: .vod,
        title: stream.name.formatted(),
        imageURL: stream.streamIcon,
        streamURL: streamURL
      )
    } else {
      selectedPlaybackContext = nil
    }
    showPlayer = true
  }
}

private struct ContinueWatchingView: View {
  @ObservedResults(
    CachedPlaybackProgress.self,
    sortDescriptor: SortDescriptor(keyPath: "updatedAt", ascending: false)
  ) private var progressItems

  @State private var selectedStreamURL: URL?
  @State private var selectedPlaybackContext: PlaybackProgressContext?
  @State private var selectedKind: KindMedia = .vod
  @State private var currentID = 9999
  @State private var showPlayer = false

  private var movieItems: [CachedPlaybackProgress] {
    progressItems.filter { $0.kind == KindMedia.vod.rawValue }
  }

  private var showItems: [CachedPlaybackProgress] {
    progressItems.filter { $0.kind == KindMedia.series.rawValue }
  }

  private var hasItems: Bool {
    !movieItems.isEmpty || !showItems.isEmpty
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 24) {
          header

          if hasItems {
            ContinueWatchingShelf(title: "Movies", items: movieItems) { item in
              open(item)
            }

            ContinueWatchingShelf(title: "Shows", items: showItems) { item in
              open(item)
            }
          } else {
            LibraryEmptyStateView(
              systemImage: "play.rectangle",
              title: "Nothing to resume yet",
              message: "Start a movie or episode, then it will appear here."
            )
            .padding(.top, 36)
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
          ViewPlayerContent(
            mediaURL: selectedStreamURL,
            id: currentID,
            kind: selectedKind,
            playbackContext: selectedPlaybackContext
          )
          .ignoresSafeArea()
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text("Continue Watching")
        .font(.system(size: 34, weight: .bold))
        .foregroundStyle(.white)

      Text("Resume movies and episodes from where you stopped.")
        .font(.callout.weight(.medium))
        .foregroundStyle(.white.opacity(0.62))
    }
    .padding(.top, 10)
  }

  private func open(_ item: CachedPlaybackProgress) {
    currentID = item.mediaId
    selectedKind = KindMedia(rawValue: item.kind) ?? .vod
    selectedStreamURL = URL(string: item.streamURL)
    selectedPlaybackContext = PlaybackProgressContext(progress: item)
    showPlayer = true
  }
}

private struct TVView: View {
  @ObservedResults(CategoryEntity.self, where: ({ $0.section == KindMedia.live.rawValue })) private var categories
  @ObservedResults(CachedStream.self, where: ({ $0.section == KindMedia.live.rawValue })) private var channels
  @ObservedResults(CachedEPGProgram.self) private var epgPrograms
  @ObservedResults(FavoriEntity.self, where: ({ $0.kind == KindMedia.live.rawValue })) private var favoriteChannels

  @State private var selectedCategoryId: String?
  @State private var selectedChannel: CachedStream?
  @State private var selectedStreamURL: URL?
  @State private var searchText = ""
  @State private var effectiveSearchText = ""
  @State private var searchTask: Task<Void, Never>?
  @State private var rebuildTask: Task<Void, Never>?
  @State private var showFavoritesOnly = false
  @State private var currentID = 9999
  @State private var showPlayer = false
  @State private var inlinePlayingChannelId: Int?
  @State private var showCatchUp = false
  @AppStorage("contentRegion") private var region: String = ""

  private var regionChannelCategoryIds: Set<String>? {
    guard !region.isEmpty else { return nil }
    return Set(categories.filter { RegionTag.code(from: $0.name) == region }.map { $0.id })
  }
  @State private var isRefreshingEPG = false
  @State private var requestedEPGStreamIds = Set<Int>()
  @State private var displayedChannels: [CachedStream] = []
  @State private var displayedChannelTotal = 0
  @State private var categoryOptionsCache: [LiveTVCategoryOption] = []
  @State private var categoryNameCache: [String: String] = [:]
  @State private var favoriteLiveChannelIds = Set<Int>()
  @State private var favoriteLiveChannelPreview: [CachedStream] = []
  @State private var favoriteLiveChannelCount = 0
  @State private var currentProgramsByStreamId: [Int: LiveProgram] = [:]

  private var trimmedSearchText: String {
    effectiveSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var isSearching: Bool {
    !trimmedSearchText.isEmpty
  }

  private var visibleChannels: [CachedStream] {
    displayedChannels
  }

  private var favoriteLiveChannels: [CachedStream] {
    favoriteLiveChannelPreview
  }

  private var categoryNamesById: [String: String] {
    categoryNameCache
  }

  private var currentProgramByStreamId: [Int: LiveProgram] {
    currentProgramsByStreamId
  }

  private var channelDisplayLimit: Int {
    isSearching ? 500 : 250
  }

  private var visibleChannelCount: Int {
    if isSearching {
      return displayedChannelTotal
    }

    if showFavoritesOnly {
      return favoriteLiveChannelCount
    }

    if let selectedCategoryId {
      return displayedChannelTotal
    }

    return channels.count
  }

  private var channelSectionTitle: String {
    if isSearching {
      return "Search Results"
    }

    if showFavoritesOnly {
      return "Favorites"
    }

    if let selectedCategoryId {
      return categoryOptions.first { $0.id == selectedCategoryId }?.title
        ?? categoryName(for: selectedCategoryId)
    }

    return "All Channels"
  }

  private var categoryOptions: [LiveTVCategoryOption] {
    categoryOptionsCache.isEmpty
      ? [LiveTVCategoryOption(id: nil, title: "All")]
      : categoryOptionsCache
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
      .ignoresSafeArea(.keyboard, edges: .bottom)
      .navigationTitle("")
      .onAppear {
        rebuildLiveTVCaches()
        selectFirstChannelIfNeeded(force: false)
        refreshVisibleEPGIfNeeded()
      }
      .onChange(of: selectedCategoryId) {
        if selectedCategoryId != nil {
          showFavoritesOnly = false
        }
        rebuildDisplayedChannels()
        selectFirstChannelIfNeeded(force: true)
        refreshVisibleEPGIfNeeded()
      }
      .onChange(of: searchText) {
        selectedChannel = nil
        inlinePlayingChannelId = nil
        scheduleSearchUpdate()
      }
      .onChange(of: showFavoritesOnly) {
        if showFavoritesOnly {
          selectedCategoryId = nil
        }
        rebuildDisplayedChannels()
        selectFirstChannelIfNeeded(force: true)
        refreshVisibleEPGIfNeeded()
      }
      .onChange(of: channels.count) {
        scheduleLiveTVRebuild()
      }
      .onChange(of: categories.count) {
        scheduleLiveTVRebuild()
      }
      .onChange(of: favoriteChannels.count) {
        rebuildFavoriteChannelCache()
        rebuildDisplayedChannels()
      }
      .onChange(of: region) {
        selectedCategoryId = nil
        scheduleLiveTVRebuild()
      }
      .onDisappear {
        searchTask?.cancel()
        rebuildTask?.cancel()
        inlinePlayingChannelId = nil
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
      .sheet(isPresented: $showCatchUp) {
        if let selectedChannel {
          CatchUpView(channel: selectedChannel)
        }
      }
    }
  }

  @ViewBuilder
  private var catchUpButton: some View {
    if let selectedChannel, selectedChannel.tvArchive {
      Button { showCatchUp = true } label: {
        HStack(spacing: 8) {
          Image(systemName: "clock.arrow.circlepath")
          Text("Catch-up")
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(.white.opacity(0.12), in: Capsule())
        .overlay { Capsule().stroke(.white.opacity(0.18), lineWidth: 1) }
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Layouts

  private var portraitLayout: some View {
    VStack(spacing: 0) {
      tvHeader
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)

      searchField
        .padding(.horizontal, 16)
        .padding(.bottom, 12)

      quickSections
        .padding(.bottom, 12)

      categoryBar
        .padding(.bottom, 12)

      favoritesSection
        .padding(.bottom, 12)

      channelsHeader
        .padding(.horizontal, 16)
        .padding(.bottom, 8)

      previewPlayer
        .padding(.horizontal, 16)
        .padding(.bottom, 12)

      catchUpButton
        .padding(.horizontal, 16)
        .padding(.bottom, 12)

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
        tvHeader
          .padding(.horizontal, 16)
          .padding(.top, 10)
          .padding(.bottom, 12)

        searchField
          .padding(.horizontal, 16)
          .padding(.bottom, 12)

        quickSections
          .padding(.bottom, 12)

        categoryBar
          .padding(.bottom, 12)

        favoritesSection
          .padding(.bottom, 12)

        channelsHeader
          .padding(.horizontal, 16)
          .padding(.bottom, 10)

        channelList
      }
      .frame(width: leftWidth)
      .clipped()

      Rectangle()
        .fill(.white.opacity(0.08))
        .frame(width: 1)

      VStack(spacing: 12) {
        Spacer(minLength: 0)
        previewPlayer
          .frame(width: videoWidth)
        catchUpButton
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
        systemImage: "sparkles.tv",
        title: "No live channels yet",
        message: "Add your Xtream playlist in Settings, then tap Save & Load Playlist."
      )
      .padding(.top, 36)
      .padding(.horizontal, 16)
    }
  }

  private var tvHeader: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text("Live TV")
        .font(.system(size: 34, weight: .bold))
        .foregroundStyle(.white)

      Text("Watch live channels from your playlist.")
        .font(.callout.weight(.medium))
        .foregroundStyle(.white.opacity(0.64))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var searchField: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white.opacity(0.55))

      TextField("Search channels, sports, movies...", text: $searchText)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)

      if !searchText.isEmpty {
        Button {
          searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white.opacity(0.55))
        }
        .buttonStyle(.plain)
      }
    }
    .frame(height: 44)
    .padding(.horizontal, 14)
    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(.white.opacity(0.10), lineWidth: 1)
    }
  }

  private var previewPlayer: some View {
    GuidePreviewPlayer(
      channel: selectedChannel,
      program: selectedChannel.flatMap { currentProgramByStreamId[$0.id] },
      categoryName: selectedChannel.map { categoryName(for: $0.categoryId) } ?? "Live TV",
      isPlayingInline: selectedChannel.map { inlinePlayingChannelId == $0.id } ?? false,
      onPlayInline: {
        if let selectedChannel {
          playInline(selectedChannel)
        }
      },
      onFullscreen: {
        if let selectedChannel {
          openFullscreen(selectedChannel)
        }
      }
    )
  }

  private var channelsHeader: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(channelSectionTitle)
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(.white)

        Text("\(visibleChannelCount.formatted()) channels")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.52))
      }

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
    LiveTVCategoryBar(
      options: categoryOptions,
      selectedCategoryId: selectedCategoryId,
      showFavoritesOnly: showFavoritesOnly
    ) { option in
      withAnimation(.snappy) {
        showFavoritesOnly = false
        selectedCategoryId = option.id
      }
    }
  }

  private var quickSections: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 9) {
        LiveTVQuickSectionButton(
          title: "Continue Watching",
          subtitle: selectedChannel.map { TVChannelText.cleanName($0.name) } ?? "Select a channel",
          systemImage: "play.rectangle.fill",
          isSelected: false
        ) {
          if let selectedChannel {
            select(selectedChannel)
          } else {
            selectFirstChannelIfNeeded(force: true)
          }
        }

        LiveTVQuickSectionButton(
          title: "Favorites",
          subtitle: "\(favoriteLiveChannelCount) saved",
          systemImage: "star.fill",
          isSelected: showFavoritesOnly
        ) {
          withAnimation(.snappy) {
            selectedCategoryId = nil
            showFavoritesOnly = true
          }
        }

        LiveTVQuickSectionButton(
          title: "All Channels",
          subtitle: "\(channels.count.formatted()) total",
          systemImage: "list.bullet.rectangle",
          isSelected: selectedCategoryId == nil && !showFavoritesOnly
        ) {
          withAnimation(.snappy) {
            selectedCategoryId = nil
            showFavoritesOnly = false
          }
        }
      }
      .padding(.horizontal, 16)
    }
    .scrollClipDisabled()
  }

  @ViewBuilder
  private var favoritesSection: some View {
    if !favoriteLiveChannels.isEmpty {
      VStack(alignment: .leading, spacing: 9) {
        Text("Favorites")
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 16)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(favoriteLiveChannels.prefix(12), id: \.id) { channel in
              Button {
                select(channel)
              } label: {
                Text(TVChannelText.cleanName(channel.name))
                  .font(.caption.weight(.bold))
                  .foregroundStyle(.white)
                  .lineLimit(1)
                  .padding(.horizontal, 12)
                  .frame(height: 34)
                  .background(.white.opacity(0.09), in: Capsule())
                  .overlay {
                    Capsule().stroke(.white.opacity(0.11), lineWidth: 1)
                  }
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal, 16)
        }
        .scrollClipDisabled()
      }
    }
  }

  private var channelList: some View {
    let rows = displayedChannels
    let hiddenCount = max(visibleChannelCount - rows.count, 0)
    let programs = currentProgramByStreamId

    return ScrollView {
      LazyVStack(spacing: 8) {
        ForEach(rows, id: \.id) { channel in
          GuideChannelRow(
            channel: channel,
            program: programs[channel.id],
            categoryName: categoryName(for: channel.categoryId),
            isSelected: selectedChannel?.id == channel.id,
            isFavorite: isFavorite(channel)
          ) {
            select(channel)
          } onPlay: {
            playInline(channel)
          } onToggleFavorite: {
            toggleFavorite(channel)
          }
        }

        if hiddenCount > 0 {
          Text("Showing first \(rows.count.formatted()) channels. Search to find more.")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.52))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 4)
      .padding(.bottom, 132)
    }
    .scrollIndicators(.hidden)
  }

  private func categoryName(for categoryId: String) -> String {
    categoryNameCache[categoryId]
      ?? categories.first(where: { $0.id == categoryId })?.name.formatted()
      ?? "Live TV"
  }

  private func matchingCategory(keywords: [String]) -> CategoryEntity? {
    categories.first { category in
      let name = category.name.lowercased()
      return keywords.contains { name.contains($0) }
    }
  }

  private func isFavorite(_ channel: CachedStream) -> Bool {
    favoriteLiveChannelIds.contains(channel.id)
  }

  private func scheduleLiveTVRebuild() {
    rebuildTask?.cancel()
    rebuildTask = Task {
      try? await Task.sleep(nanoseconds: 180_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        rebuildLiveTVCaches()
        selectFirstChannelIfNeeded(force: true)
        refreshVisibleEPGIfNeeded()
      }
    }
  }

  private func rebuildLiveTVCaches() {
    rebuildCategoryNameCache()
    rebuildCategoryOptionsCache()
    rebuildFavoriteChannelCache()
    rebuildDisplayedChannels()
  }

  private func rebuildCategoryNameCache() {
    var values: [String: String] = [:]
    values.reserveCapacity(categories.count)
    for category in categories {
      values[category.id] = category.name.formatted()
    }
    categoryNameCache = values
  }

  private func rebuildCategoryOptionsCache() {
    let requested = [
      ("All", []),
      ("Locals", ["local", "locals"]),
      ("Sports", ["sport", "sports", "f1", "nba", "nfl", "mlb", "soccer"]),
      ("News", ["news"]),
      ("Movies", ["movie", "movies", "cinema"]),
      ("Shows", ["show", "shows", "series", "entertainment"]),
    ]

    var options: [LiveTVCategoryOption] = [
      LiveTVCategoryOption(id: nil, title: "All"),
    ]

    for item in requested.dropFirst() {
      guard let category = matchingCategory(keywords: item.1) else { continue }
      options.append(LiveTVCategoryOption(id: category.id, title: item.0))
    }

    categoryOptionsCache = options
  }

  private func rebuildFavoriteChannelCache() {
    let favoriteIds = Set(favoriteChannels.map(\.id))
    guard !favoriteIds.isEmpty else {
      favoriteLiveChannelIds = []
      favoriteLiveChannelPreview = []
      favoriteLiveChannelCount = 0
      return
    }

    var preview: [CachedStream] = []
    var count = 0

    for channel in channels where favoriteIds.contains(channel.id) {
      count += 1
      if preview.count < 12 {
        preview.append(channel)
      }
    }

    favoriteLiveChannelIds = favoriteIds
    favoriteLiveChannelPreview = preview
    favoriteLiveChannelCount = count
  }

  private func rebuildDisplayedChannels() {
    let limit = channelDisplayLimit
    let regionIds = regionChannelCategoryIds

    if !isSearching, !showFavoritesOnly, selectedCategoryId == nil, regionIds == nil {
      let rows = Array(channels.prefix(limit))
      displayedChannels = rows
      displayedChannelTotal = channels.count
      rebuildCurrentProgramCache(for: rows)
      return
    }

    let favoriteIds = showFavoritesOnly ? favoriteLiveChannelIds : []
    let categoryNames = isSearching ? categoryNamesById : [:]
    var rows: [CachedStream] = []
    rows.reserveCapacity(limit)
    var total = 0

    for channel in channels {
      if let regionIds, !regionIds.contains(channel.categoryId) {
        continue
      }

      if showFavoritesOnly && !favoriteIds.contains(channel.id) {
        continue
      }

      if !isSearching, let selectedCategoryId, channel.categoryId != selectedCategoryId {
        continue
      }

      if isSearching,
         !TVChannelText.matches(
          channel,
          categoryName: categoryNames[channel.categoryId] ?? "Live TV",
          search: trimmedSearchText
         )
      {
        continue
      }

      total += 1
      if rows.count < limit {
        rows.append(channel)
      }
    }

    displayedChannels = rows
    displayedChannelTotal = total
    rebuildCurrentProgramCache(for: rows)
  }

  private func rebuildCurrentProgramCache(for channels: [CachedStream]) {
    var streamIds = Set(channels.map(\.id))
    if let selectedChannel {
      streamIds.insert(selectedChannel.id)
    }

    guard !streamIds.isEmpty else {
      currentProgramsByStreamId = [:]
      return
    }

    let now = Date()
    var values: [Int: LiveProgram] = [:]
    for program in epgPrograms where streamIds.contains(program.streamId) {
      guard values[program.streamId] == nil else { continue }
      if program.startDate <= now, program.endDate > now {
        values[program.streamId] = LiveProgram(
          title: program.title,
          startDate: program.startDate,
          endDate: program.endDate
        )
      }
    }
    currentProgramsByStreamId = values
  }

  private func scheduleSearchUpdate() {
    searchTask?.cancel()
    let value = searchText
    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedValue.isEmpty else {
      effectiveSearchText = ""
      rebuildDisplayedChannels()
      selectFirstChannelIfNeeded(force: true)
      refreshVisibleEPGIfNeeded()
      return
    }

    searchTask = Task {
      try? await Task.sleep(nanoseconds: 250_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        effectiveSearchText = value
        rebuildDisplayedChannels()
        selectFirstChannelIfNeeded(force: true)
        refreshVisibleEPGIfNeeded()
      }
    }
  }

  @MainActor
  private func toggleFavorite(_ channel: CachedStream) {
    do {
      let realm = try Realm()
      let existing = realm.objects(FavoriEntity.self)
        .where { $0.id == channel.id && $0.kind == KindMedia.live.rawValue }

      try realm.write {
        if let favorite = existing.first {
          realm.delete(favorite)
        } else {
          realm.add(FavoriEntity(
            id: channel.id,
            kind: KindMedia.live.rawValue,
            name: channel.name,
            streamIcon: channel.streamIcon,
            added: Date(),
            tmdb: channel.tmdb
          ))
        }
      }
    } catch {
      print("Live favorite toggle failed: \(error)")
    }
  }

  private func select(_ channel: CachedStream) {
    withAnimation(.snappy) {
      selectedChannel = channel
    }
    if !requestedEPGStreamIds.contains(channel.id), !hasFreshEPG(for: channel.id) {
      fetchEPG(for: [channel.id])
    }
  }

  private func playInline(_ channel: CachedStream) {
    withAnimation(.snappy) {
      selectedChannel = channel
      inlinePlayingChannelId = channel.id
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

  private func openFullscreen(_ channel: CachedStream) {
    inlinePlayingChannelId = nil
    currentID = channel.id
    selectedStreamURL = URL(string: channel.streamURL())
    DispatchQueue.main.async {
      showPlayer = true
    }
  }

  private func refreshVisibleEPGIfNeeded() {
    guard !isSearching else { return }

    let idsToFetch = displayedChannels.prefix(12)
      .map(\.id)
      .filter { !requestedEPGStreamIds.contains($0) && !hasFreshEPG(for: $0) }

    guard !idsToFetch.isEmpty else { return }
    fetchEPG(for: idsToFetch)
  }

  private func refreshVisibleEPG() {
    let idsToFetch = displayedChannels.prefix(20).map(\.id)
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
        rebuildCurrentProgramCache(for: displayedChannels)
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

    guard let realm = try? await Realm() else { return }
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

/// Value snapshot of an EPG program, so views never hold a live (deletable)
/// Realm object — that was crashing Live TV when the EPG cache refreshed.
private struct LiveProgram {
  let title: String
  let startDate: Date
  let endDate: Date
}

private struct GuidePreviewPlayer: View {
  let channel: CachedStream?
  let program: LiveProgram?
  let categoryName: String
  let isPlayingInline: Bool
  let onPlayInline: () -> Void
  let onFullscreen: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ZStack {
        if let channel {
          ZStack {
            Color.black

            if isPlayingInline, let url = URL(string: channel.streamURL()) {
              VideoPlayerView(streamURL: url, id: channel.id, kind: .live)
                .id(channel.id)
            } else if let imagePath = channel.getImage(), !imagePath.isEmpty, let url = URL(string: imagePath) {
              AsyncImage(url: url, placeholder: {
                previewPlaceholder
              }, content: { image in
                image
                  .resizable()
                  .scaledToFit()
                  .padding(34)
              })
            } else {
              previewPlaceholder
            }
          }
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
      .overlay {
        if channel != nil, !isPlayingInline {
          Button(action: onPlayInline) {
            HStack(spacing: 8) {
              Image(systemName: "play.fill")
                .font(.system(size: 14, weight: .bold))
              Text("Play")
                .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 18)
            .frame(height: 44)
            .background(.white, in: Capsule())
          }
          .buttonStyle(.plain)
        }
      }

      if let channel {
        VStack(alignment: .leading, spacing: 4) {
          Text(TVChannelText.cleanName(channel.name))
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)

          Text(TVChannelText.status(channelName: channel.name, program: program))
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

  private var previewPlaceholder: some View {
    VStack(spacing: 10) {
      Image(systemName: "play.rectangle")
        .font(.system(size: 34, weight: .semibold))
      Text("Tap play to watch")
        .font(.subheadline.weight(.semibold))
    }
    .foregroundStyle(.white.opacity(0.62))
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
  let program: LiveProgram?
  let categoryName: String
  let isSelected: Bool
  let isFavorite: Bool
  let onSelect: () -> Void
  let onPlay: () -> Void
  let onToggleFavorite: () -> Void

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
    HStack(spacing: 12) {
      Button(action: onSelect) {
        HStack(spacing: 12) {
          logo
            .frame(width: 52, height: 52)
            .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

          VStack(alignment: .leading, spacing: 4) {
            Text(TVChannelText.cleanName(channel.name))
              .font(.system(size: 15, weight: .bold))
              .foregroundStyle(.white)
              .lineLimit(1)

            Text(TVChannelText.status(channelName: channel.name, program: program))
              .font(.caption.weight(.semibold))
              .foregroundStyle(.white.opacity(0.62))
              .lineLimit(1)

            Text(categoryName)
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.white.opacity(0.42))
              .lineLimit(1)
          }

          Spacer(minLength: 4)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button(action: onToggleFavorite) {
        Image(systemName: isFavorite ? "star.fill" : "star")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(isFavorite ? .yellow : .white.opacity(0.68))
          .frame(width: 34, height: 34)
          .background(.white.opacity(0.07), in: Circle())
      }
      .buttonStyle(.plain)

      Button(action: onPlay) {
        Image(systemName: "play.fill")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 36, height: 36)
          .background(.red, in: Circle())
      }
      .buttonStyle(.plain)
    }
    .padding(10)
    .background(fillColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(strokeColor, lineWidth: 1)
    }
  }
}

private struct LiveTVCategoryOption {
  let id: String?
  let title: String

  var stableId: String {
    id ?? "all"
  }
}

private struct LiveTVCategoryBar: View {
  let options: [LiveTVCategoryOption]
  let selectedCategoryId: String?
  let showFavoritesOnly: Bool
  let onSelect: (LiveTVCategoryOption) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(options, id: \.stableId) { option in
          let isSelected = !showFavoritesOnly && selectedCategoryId == option.id

          Button {
            onSelect(option)
          } label: {
            Text(option.title)
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(isSelected ? .white : .white.opacity(0.72))
              .padding(.horizontal, 14)
              .frame(height: 36)
              .background(isSelected ? .red : .white.opacity(0.07), in: Capsule())
              .overlay {
                Capsule().stroke(.white.opacity(isSelected ? 0.16 : 0.10), lineWidth: 1)
              }
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 16)
    }
    .scrollClipDisabled()
  }
}

private struct LiveTVQuickSectionButton: View {
  let title: String
  let subtitle: String
  let systemImage: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 9) {
        Image(systemName: systemImage)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(isSelected ? .white : .red)
          .frame(width: 30, height: 30)
          .background(isSelected ? .red : .red.opacity(0.13), in: Circle())

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)

          Text(subtitle)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.48))
            .lineLimit(1)
        }
      }
      .padding(.horizontal, 11)
      .frame(height: 50)
      .background(.white.opacity(isSelected ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(isSelected ? .red.opacity(0.42) : .white.opacity(0.09), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }
}

private enum TVChannelText {
  static func matches(_ channel: CachedStream, categoryName: String, search: String) -> Bool {
    let query = normalizedSearch(search)
    guard !query.isEmpty else { return true }

    let searchableText = [
      channel.name,
      channel.streamType,
      categoryName,
    ]
    .joined(separator: " ")

    return normalizedSearch(searchableText).contains(query)
  }

  static func cleanName(_ name: String) -> String {
    var value = name
      .replacingOccurrences(of: "- NO EVENT STREAMING -", with: "", options: .caseInsensitive)
      .replacingOccurrences(of: "NO EVENT STREAMING", with: "", options: .caseInsensitive)
      .replacingOccurrences(of: "8K EXCLUSIVE", with: "", options: .caseInsensitive)
      .replacingOccurrences(of: "4K EXCLUSIVE", with: "", options: .caseInsensitive)
      .replacingOccurrences(of: "FHD", with: "", options: .caseInsensitive)
      .replacingOccurrences(of: "HD", with: "", options: .caseInsensitive)
      .replacingOccurrences(of: ":", with: " | ")
      .replacingOccurrences(of: "_", with: " ")

    while value.contains("||") {
      value = value.replacingOccurrences(of: "||", with: "|")
    }
    while value.contains("  ") {
      value = value.replacingOccurrences(of: "  ", with: " ")
    }

    value = value
      .split(separator: "|")
      .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " -|")) }
      .filter { !$0.isEmpty }
      .joined(separator: " | ")
      .trimmingCharacters(in: CharacterSet(charactersIn: " -|"))

    return value.isEmpty ? name.formatted() : value.formatted()
  }

  static func status(channelName: String, program: LiveProgram?) -> String {
    if channelName.localizedCaseInsensitiveContains("no event streaming") {
      return "No event streaming"
    }
    if let title = program?.title, !title.isEmpty {
      return title
    }
    return "Live"
  }

  private static func normalizedSearch(_ value: String) -> String {
    value
      .lowercased()
      .replacingOccurrences(of: "|", with: " ")
      .replacingOccurrences(of: ":", with: " ")
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "_", with: " ")
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
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
