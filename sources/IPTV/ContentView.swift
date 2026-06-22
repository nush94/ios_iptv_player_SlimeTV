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
  @State private var isSearchPresented = false
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
        AppTopNavigationBar(selectedSection: $selectedSection, isSearchPresented: $isSearchPresented)
          .zIndex(2)
      }

      if isSearchPresented {
        SearchOverlayView(isPresented: $isSearchPresented)
          .transition(.opacity.combined(with: .move(edge: .top)))
          .zIndex(5)
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
      .task {
        // Resolve the user's coarse country/region for personalization (prompts
        // for When-In-Use only on first launch; otherwise uses the cached/locale
        // value), then keep scores in sync as it changes.
        UserRegionProvider.shared.resolve()
        // Match movies/shows against TMDB in the background (capped, resumable).
        MetadataEnricher.enrichIfNeeded()
        // Refresh TMDB trending on a schedule (stale-gated, req 16).
        TrendingRefresher.refreshIfStale()
      }
      .onReceive(UserRegionProvider.shared.$context.dropFirst()) { _ in
        SmartPlaylistOrganizer.recomputeScores()
      }
      .onReceive(NotificationCenter.default.publisher(for: .playlistImportCompleted)) { _ in
        withAnimation(.snappy) {
          selectedSection = .movies
          isBottomBarHidden = false
          isSearchPresented = false
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
  @Binding var isSearchPresented: Bool

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
          searchButton
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

  private var searchButton: some View {
    Button {
      withAnimation(.snappy) {
        isSearchPresented = true
      }
    } label: {
      VStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 20, weight: .semibold))

        Capsule()
          .fill(isSearchPresented ? .red : .clear)
          .frame(width: isSearchPresented ? 22 : 0, height: 3)
      }
      .foregroundStyle(isSearchPresented ? .white : .white.opacity(0.66))
      .frame(width: 44, height: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Search")
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

private struct SearchOverlayView: View {
  @Binding var isPresented: Bool
  @ObservedResults(CachedStream.self) private var streams
  @ObservedResults(CachedSeries.self) private var series

  @State private var query = ""
  @State private var effectiveQuery = ""
  @State private var searchTask: Task<Void, Never>?
  @State private var movieResults: [CachedStream] = []
  @State private var showResults: [CachedSeries] = []
  @State private var liveResults: [CachedStream] = []
  @State private var selectedStreamURL: URL?
  @State private var selectedKind: KindMedia = .vod
  @State private var selectedPlaybackContext: PlaybackProgressContext?
  @State private var selectedMovieForDetails: CachedStream?
  @State private var selectedSerieId: Int?
  @State private var showPlayer = false
  @State private var showMovieDetails = false
  @State private var showSerieDetail = false
  @State private var currentID = 9999
  @FocusState private var isSearchFocused: Bool

  var body: some View {
    ZStack(alignment: .top) {
      Color.black.opacity(0.58)
        .ignoresSafeArea()
        .onTapGesture {
          dismiss()
        }

      VStack(spacing: 12) {
        searchHeader

        if effectiveQuery.count < 2 {
          emptyHint
        } else {
          resultsList
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 74)
      .padding(.bottom, 16)
      .background(alignment: .top) {
        LinearGradient(
          colors: [.black.opacity(0.98), .black.opacity(0.86), .clear],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: 560)
        .ignoresSafeArea()
      }
    }
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
        isSearchFocused = true
      }
    }
    .onDisappear {
      searchTask?.cancel()
    }
    .onChange(of: query) {
      scheduleSearch()
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
    .fullScreenCover(isPresented: Binding(get: {
      showMovieDetails && selectedMovieForDetails != nil
    }, set: { showMovieDetails = $0 })) {
      if let selectedMovieForDetails {
        MovieInfoView(movie: selectedMovieForDetails)
      }
    }
    .fullScreenCover(isPresented: Binding(get: {
      showSerieDetail && selectedSerieId != nil
    }, set: { showSerieDetail = $0 })) {
      if let selectedSerieId {
        SerieDetailView(streamId: selectedSerieId)
      }
    }
  }

  private var searchHeader: some View {
    HStack(spacing: 10) {
      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(.white.opacity(0.62))

        TextField("Search movies, shows, live TV...", text: $query)
          .focused($isSearchFocused)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.white)
          .submitLabel(.search)

        if !query.isEmpty {
          Button {
            query = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 17, weight: .bold))
              .foregroundStyle(.white.opacity(0.55))
          }
          .buttonStyle(.plain)
        }
      }
      .frame(height: 48)
      .padding(.horizontal, 14)
      .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(.white.opacity(0.14), lineWidth: 1)
      }

      Button("Cancel") {
        dismiss()
      }
      .font(.system(size: 15, weight: .bold))
      .foregroundStyle(.red)
      .buttonStyle(.plain)
    }
  }

  private var emptyHint: some View {
    VStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 28, weight: .semibold))
      Text("Type at least 2 letters")
        .font(.system(size: 17, weight: .bold))
      Text("Find movies, shows, and live channels without leaving this screen.")
        .font(.callout.weight(.medium))
        .foregroundStyle(.white.opacity(0.58))
        .multilineTextAlignment(.center)
    }
    .foregroundStyle(.white.opacity(0.78))
    .frame(maxWidth: .infinity)
    .padding(.vertical, 34)
    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(.white.opacity(0.08), lineWidth: 1)
    }
  }

  private var resultsList: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 18) {
        resultSection(title: "Movies", count: movieResults.count) {
          ForEach(movieResults, id: \.id) { stream in
            SearchResultRow(
              title: stream.name.formatted(),
              subtitle: movieSubtitle(stream),
              imageURL: stream.tmdbImage ?? stream.streamIcon,
              systemImage: "film"
            ) {
              openMovie(stream)
            }
          }
        }

        resultSection(title: "Shows", count: showResults.count) {
          ForEach(showResults, id: \.id) { serie in
            SearchResultRow(
              title: serie.name.formatted(),
              subtitle: showSubtitle(serie),
              imageURL: serie.cover,
              systemImage: "play.tv"
            ) {
              openSeries(serie)
            }
          }
        }

        resultSection(title: "Live TV", count: liveResults.count) {
          ForEach(liveResults, id: \.id) { stream in
            SearchResultRow(
              title: TVChannelText.cleanName(stream.name),
              subtitle: "Live channel",
              imageURL: stream.streamIcon,
              systemImage: "tv"
            ) {
              openLive(stream)
            }
          }
        }

        if movieResults.isEmpty && showResults.isEmpty && liveResults.isEmpty {
          noResults
        }
      }
      .padding(.bottom, 130)
    }
    .frame(maxHeight: 560)
    .scrollIndicators(.hidden)
  }

  private func resultSection<Content: View>(
    title: String,
    count: Int,
    @ViewBuilder content: () -> Content
  ) -> some View {
    Group {
      if count > 0 {
        VStack(alignment: .leading, spacing: 9) {
          HStack {
            Text(title)
              .font(.system(size: 18, weight: .bold))
              .foregroundStyle(.white)

            Spacer()

            Text("\(count)")
              .font(.caption.weight(.bold))
              .foregroundStyle(.white.opacity(0.45))
          }

          LazyVStack(spacing: 8) {
            content()
          }
        }
      }
    }
  }

  private var noResults: some View {
    VStack(spacing: 8) {
      Image(systemName: "exclamationmark.magnifyingglass")
        .font(.system(size: 26, weight: .semibold))
      Text("No results found")
        .font(.system(size: 17, weight: .bold))
      Text("Try a shorter title, actor name, channel, or country.")
        .font(.callout.weight(.medium))
        .foregroundStyle(.white.opacity(0.58))
    }
    .foregroundStyle(.white.opacity(0.78))
    .frame(maxWidth: .infinity)
    .padding(.vertical, 30)
  }

  private func scheduleSearch() {
    searchTask?.cancel()
    let value = query.trimmingCharacters(in: .whitespacesAndNewlines)

    searchTask = Task {
      try? await Task.sleep(nanoseconds: 220_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        effectiveQuery = value
        rebuildResults(for: value)
      }
    }
  }

  private func rebuildResults(for text: String) {
    guard text.count >= 2,
          let predicate = SearchQuery.predicate(for: text),
          let moviePredicate = SearchQuery.predicate(for: text, section: KindMedia.vod.rawValue),
          let livePredicate = SearchQuery.predicate(for: text, section: KindMedia.live.rawValue)
    else {
      movieResults = []
      showResults = []
      liveResults = []
      return
    }

    movieResults = Array(streams.filter(moviePredicate).prefix(20))
    liveResults = Array(streams.filter(livePredicate).prefix(12))
    showResults = Array(series.filter(predicate).prefix(20))
  }

  private func movieSubtitle(_ stream: CachedStream) -> String {
    var parts: [String] = []
    if let year = stream.year, year > 0 {
      parts.append("\(year)")
    } else if let year = StreamYearExtractor.year(from: stream.name) {
      parts.append("\(year)")
    }
    if let rating = Double(stream.rating ?? ""), rating > 0 {
      parts.append(String(format: "%.1f", rating))
    }
    return parts.isEmpty ? "Movie" : parts.joined(separator: " • ")
  }

  private func showSubtitle(_ serie: CachedSeries) -> String {
    var parts: [String] = []
    if let year = StreamYearExtractor.year(from: serie.releaseDate) ?? StreamYearExtractor.year(from: serie.name) {
      parts.append("\(year)")
    }
    let rating = serie.rating ?? serie.rating5Based ?? 0
    if rating > 0 {
      parts.append(String(format: "%.1f", rating))
    }
    return parts.isEmpty ? "Show" : parts.joined(separator: " • ")
  }

  private func openMovie(_ stream: CachedStream) {
    selectedMovieForDetails = stream
    showMovieDetails = true
  }

  private func openLive(_ stream: CachedStream) {
    currentID = stream.id
    selectedKind = .live
    selectedPlaybackContext = nil
    selectedStreamURL = URL(string: stream.streamURL())
    showPlayer = true
  }

  private func openSeries(_ serie: CachedSeries) {
    selectedSerieId = serie.id
    showSerieDetail = true
  }

  private func dismiss() {
    searchTask?.cancel()
    isSearchFocused = false
    withAnimation(.snappy) {
      isPresented = false
    }
  }
}

private struct SearchResultRow: View {
  let title: String
  let subtitle: String
  let imageURL: String?
  let systemImage: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        poster
          .frame(width: 52, height: 68)
          .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

        VStack(alignment: .leading, spacing: 5) {
          Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)

          Text(subtitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.55))
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        Image(systemName: "play.fill")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 34, height: 34)
          .background(.red, in: Circle())
      }
      .padding(10)
      .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
          .stroke(.white.opacity(0.08), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var poster: some View {
    if let imageURL, !imageURL.isEmpty, let url = URL(string: imageURL) {
      AsyncImage(url: url, placeholder: {
        placeholder
      }, content: { image in
        image.resizable().scaledToFill()
      })
    } else {
      placeholder
    }
  }

  private var placeholder: some View {
    ZStack {
      Color.white.opacity(0.06)
      Image(systemName: systemImage)
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(.white.opacity(0.48))
    }
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

private enum LiveTVSortMode: String, CaseIterable, Identifiable {
  case liveNow
  case az
  case playlist

  var id: String { rawValue }

  var title: String {
    switch self {
    case .liveNow:
      return "Live Now"
    case .az:
      return "A-Z"
    case .playlist:
      return "Playlist"
    }
  }
}

private enum LiveSmartSection: String, CaseIterable, Identifiable {
  case localNearYou, newsNearYou, sportsNearYou, national, international
  var id: String { rawValue }

  var title: String {
    switch self {
    case .localNearYou: return "Near You"
    case .newsNearYou: return "News"
    case .sportsNearYou: return "Sports"
    case .national: return "National"
    case .international: return "International"
    }
  }

  var systemImage: String {
    switch self {
    case .localNearYou: return "location.fill"
    case .newsNearYou: return "newspaper.fill"
    case .sportsNearYou: return "sportscourt.fill"
    case .national: return "flag.fill"
    case .international: return "globe"
    }
  }

  func channels(country: String?, region: String?) -> [CachedStream] {
    switch self {
    case .localNearYou: return SmartSections.localChannels(country: country, region: region)
    case .newsNearYou: return SmartSections.newsChannels(country: country)
    case .sportsNearYou: return SmartSections.sportsChannels(country: country)
    case .national: return SmartSections.nationalChannels(country: country)
    case .international: return SmartSections.internationalChannels(country: country)
    }
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
  @State private var showRecentOnly = false
  @State private var hideDuplicateChannels = false
  @State private var sortMode: LiveTVSortMode = .liveNow
  @AppStorage("contentRegion") private var region: String = ""
  @AppStorage("recentLiveChannelIds") private var recentLiveChannelIdsRaw = ""
  @AppStorage("apiHost") private var apiHost: String = ""

  private var isPlaylistConfigured: Bool {
    !apiHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  @ObservedObject private var userRegion = UserRegionProvider.shared
  @State private var selectedLiveSmartSection: LiveSmartSection?

  /// The smart section only applies when no other filter is active, so it
  /// overrides cleanly without competing with category/favorites/recent/search.
  private var activeLiveSmartSection: LiveSmartSection? {
    guard selectedCategoryId == nil, !showFavoritesOnly, !showRecentOnly, !isSearching else { return nil }
    return selectedLiveSmartSection
  }

  private var regionChannelCategoryIds: Set<String>? {
    guard !region.isEmpty else { return nil }
    let ids = Set(categories.filter { RegionTag.code(from: $0.name) == region }.map { $0.id })
    // Live uses country codes (US/UK/CA), not language codes (EN). If the chosen
    // region matches no live categories, don't filter — show everything.
    return ids.isEmpty ? nil : ids
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
  @State private var channelDisplayLimitCount = 60

  private let channelPageSize = 60
  private let searchChannelPageSize = 80

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
    channelDisplayLimitCount
  }

  private var visibleChannelCount: Int {
    if activeLiveSmartSection != nil {
      return displayedChannelTotal
    }

    if isSearching {
      return displayedChannelTotal
    }

    if showFavoritesOnly {
      return favoriteLiveChannelCount
    }

    if showRecentOnly || hideDuplicateChannels || regionChannelCategoryIds != nil {
      return displayedChannelTotal
    }

    if selectedCategoryId != nil {
      return displayedChannelTotal
    }

    // Default (no category/filter): mirror what the filtered query actually shows
    // (e.g. `.liveNow` hides "NO EVENT STREAMING") rather than the raw, unfiltered
    // total — otherwise the header overcounts and paging keeps rebuilding at the end.
    return displayedChannelTotal
  }

  private var channelSectionTitle: String {
    if let section = activeLiveSmartSection {
      return "\(section.title) Channels"
    }

    if isSearching {
      return "Search Results"
    }

    if showFavoritesOnly {
      return "Favorites"
    }

    if showRecentOnly {
      return "Recent"
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

  private var recentLiveChannelIds: [Int] {
    recentLiveChannelIdsRaw
      .split(separator: ",")
      .compactMap { Int($0) }
  }

  private var recentLiveChannelIdSet: Set<Int> {
    Set(recentLiveChannelIds)
  }

  private var availableRegionCodes: [String] {
    var values = Set<String>()
    for category in categories {
      if let code = RegionTag.code(from: category.name) {
        values.insert(code)
      }
    }
    return values.sorted()
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
          showRecentOnly = false
        }
        resetChannelPaging()
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
          showRecentOnly = false
        }
        resetChannelPaging()
        rebuildDisplayedChannels()
        selectFirstChannelIfNeeded(force: true)
        refreshVisibleEPGIfNeeded()
      }
      .onChange(of: showRecentOnly) {
        if showRecentOnly {
          selectedCategoryId = nil
          showFavoritesOnly = false
        }
        resetChannelPaging()
        rebuildDisplayedChannels()
        selectFirstChannelIfNeeded(force: true)
        refreshVisibleEPGIfNeeded()
      }
      .onChange(of: hideDuplicateChannels) {
        resetChannelPaging()
        rebuildDisplayedChannels()
        selectFirstChannelIfNeeded(force: true)
        refreshVisibleEPGIfNeeded()
      }
      .onChange(of: sortMode) {
        resetChannelPaging()
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
        resetChannelPaging()
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
        .padding(.top, 6)
        .padding(.bottom, 10)

      searchField
        .padding(.horizontal, 16)
        .padding(.bottom, 10)

      categoryBar
        .padding(.bottom, 10)

      liveSmartSectionBar
        .padding(.bottom, 10)

      playlistOrganizerBar
        .padding(.horizontal, 16)
        .padding(.bottom, 10)

      previewPlayer
        .padding(.horizontal, 16)
        .padding(.bottom, 10)

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

        playlistOrganizerBar
          .padding(.horizontal, 16)
          .padding(.bottom, 12)

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
        systemImage: isPlaylistConfigured ? "arrow.clockwise" : "sparkles.tv",
        title: isPlaylistConfigured ? "Couldn't load channels" : "No live channels yet",
        message: isPlaylistConfigured
          ? "Your channel list didn't finish loading. Open Settings and tap Save & Load Playlist to try again."
          : "Add your Xtream playlist in Settings, then tap Save & Load Playlist."
      )
      .padding(.top, 36)
      .padding(.horizontal, 16)
    }
  }

  private var tvHeader: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 5) {
        Text("Live TV")
          .font(.system(size: 31, weight: .bold))
          .foregroundStyle(.white)

        Text("Watch live channels from your playlist.")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.white.opacity(0.64))
      }

      Spacer(minLength: 8)

      VStack(alignment: .leading, spacing: 2) {
        Label("\(channels.count.formatted()) channels", systemImage: "line.3.horizontal.decrease.circle")
          .font(.caption2.weight(.bold))
        Text("Grouped by category")
          .font(.system(size: 10, weight: .semibold))
      }
      .lineLimit(1)
      .foregroundStyle(.white.opacity(0.78))
      .padding(.horizontal, 10)
      .frame(height: 44)
      .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(.white.opacity(0.10), lineWidth: 1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var searchField: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white.opacity(0.55))

      TextField("Search channels, programs, countries...", text: $searchText)
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

      Image(systemName: "slider.horizontal.3")
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(.white.opacity(0.50))
    }
    .frame(height: 40)
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
      canCatchUp: selectedChannel?.tvArchive ?? false,
      onPlayInline: {
        if let selectedChannel {
          playInline(selectedChannel)
        }
      },
      onFullscreen: {
        if let selectedChannel {
          openFullscreen(selectedChannel)
        }
      },
      onCatchUp: { showCatchUp = true }
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
      showFavoritesOnly: showFavoritesOnly,
      showRecentOnly: showRecentOnly
    ) { option in
      withAnimation(.snappy) {
        showFavoritesOnly = false
        showRecentOnly = false
        selectedLiveSmartSection = nil
        selectedCategoryId = option.id
      }
    } onFavorites: {
      withAnimation(.snappy) {
        selectedCategoryId = nil
        showRecentOnly = false
        selectedLiveSmartSection = nil
        showFavoritesOnly.toggle()
      }
    }
  }

  /// "Near You / News / Sports / National / International" sections for Live (req 12).
  private var liveSmartSectionBar: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(LiveSmartSection.allCases) { section in
          Button {
            selectLiveSmartSection(selectedLiveSmartSection == section ? nil : section)
          } label: {
            HStack(spacing: 5) {
              Image(systemName: section.systemImage)
                .font(.system(size: 11, weight: .bold))
              Text(section.title)
                .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(selectedLiveSmartSection == section ? .white : .white.opacity(0.7))
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(selectedLiveSmartSection == section ? Color.red : .white.opacity(0.08), in: Capsule())
            .overlay { Capsule().stroke(.white.opacity(0.12), lineWidth: 1) }
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 16)
    }
  }

  private func selectLiveSmartSection(_ section: LiveSmartSection?) {
    withAnimation(.snappy) {
      selectedLiveSmartSection = section
      if section != nil {
        selectedCategoryId = nil
        showFavoritesOnly = false
        showRecentOnly = false
      }
    }
    resetChannelPaging()
    rebuildDisplayedChannels()
    selectFirstChannelIfNeeded(force: true)
    refreshVisibleEPGIfNeeded()
  }

  private var playlistOrganizerBar: some View {
    HStack(spacing: 10) {
      Menu {
        Button { region = "" } label: {
          Label("All countries", systemImage: region.isEmpty ? "checkmark" : "globe")
        }

        ForEach(availableRegionCodes, id: \.self) { code in
          Button { region = code } label: {
            if region == code {
              Label(countryDisplayName(for: code), systemImage: "checkmark")
            } else {
              Text(countryDisplayName(for: code))
            }
          }
        }
      } label: {
        organizerButtonContent(
          systemImage: "globe",
          title: "Country: \(region.isEmpty ? "All" : countryDisplayName(for: region))"
        )
      }
      .buttonStyle(.plain)

      Menu {
        ForEach(LiveTVSortMode.allCases) { mode in
          Button { sortMode = mode } label: {
            if sortMode == mode {
              Label(mode.title, systemImage: "checkmark")
            } else {
              Text(mode.title)
            }
          }
        }
      } label: {
        organizerButtonContent(systemImage: "arrow.up.arrow.down", title: "Sort: \(sortMode.title)")
      }
      .buttonStyle(.plain)
    }
  }

  private func organizerButtonContent(systemImage: String, title: String) -> some View {
    HStack(spacing: 7) {
      Image(systemName: systemImage)
        .font(.system(size: 12, weight: .bold))
      Text(title)
        .font(.caption.weight(.bold))
        .lineLimit(1)
      Spacer(minLength: 4)
      Image(systemName: "chevron.down")
        .font(.system(size: 10, weight: .heavy))
    }
    .foregroundStyle(.white.opacity(0.78))
    .padding(.horizontal, 11)
    .frame(maxWidth: .infinity)
    .frame(height: 36)
    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(.white.opacity(0.10), lineWidth: 1)
    }
  }

  private func countryDisplayName(for code: String) -> String {
    Locale.current.localizedString(forRegionCode: code) ?? code
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
      LazyVStack(alignment: .leading, spacing: 10) {
        liveNowSection(rows: Array(rows.prefix(3)), programs: programs)
          .padding(.bottom, 10)

        channelGuideHeader
          .padding(.bottom, 2)

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
          .onAppear {
            if channel.id == rows.last?.id {
              loadMoreChannelsIfNeeded()
            }
          }
        }

        if hiddenCount > 0 {
          Button(action: loadMoreChannelsIfNeeded) {
            HStack(spacing: 8) {
              Text("Showing \(rows.count.formatted()) of \(visibleChannelCount.formatted())")
              Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .heavy))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.72))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.white.opacity(0.05), in: Capsule())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 2)
      .padding(.bottom, 148)
    }
    .scrollIndicators(.hidden)
  }

  private func liveNowSection(rows: [CachedStream], programs: [Int: LiveProgram]) -> some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack {
        Text("Live Now")
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(.white)

        Spacer()

        Button {
          withAnimation(.snappy) {
            selectedCategoryId = nil
            showFavoritesOnly = false
            showRecentOnly = false
          }
        } label: {
          HStack(spacing: 3) {
            Text("View all")
            Image(systemName: "chevron.right")
              .font(.system(size: 9, weight: .heavy))
          }
          .font(.caption.weight(.bold))
          .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(rows, id: \.id) { channel in
            LiveNowChannelCard(
              channel: channel,
              program: programs[channel.id],
              isSelected: selectedChannel?.id == channel.id
            ) {
              select(channel)
            }
          }
        }
      }
      .scrollClipDisabled()
    }
  }

  private var channelGuideHeader: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(alignment: .lastTextBaseline) {
        Text("Channel Guide")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(.white)

        Spacer()

        Text("\(visibleChannelCount.formatted())")
          .font(.caption.weight(.bold))
          .foregroundStyle(.white.opacity(0.52))
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          guideActionPill(title: "Favorites", systemImage: "star", isSelected: showFavoritesOnly) {
            withAnimation(.snappy) {
              showFavoritesOnly.toggle()
            }
          }

          guideActionPill(title: "Recent", systemImage: "clock", isSelected: showRecentOnly) {
            withAnimation(.snappy) {
              showRecentOnly.toggle()
            }
          }

          guideActionPill(title: "Hide Duplicates", systemImage: "rectangle.stack.badge.minus", isSelected: hideDuplicateChannels) {
            withAnimation(.snappy) {
              hideDuplicateChannels.toggle()
            }
          }
        }
      }
      .scrollClipDisabled()
    }
  }

  private func guideActionPill(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: systemImage)
          .font(.system(size: 11, weight: .bold))
        Text(title)
          .font(.caption.weight(.bold))
      }
      .foregroundStyle(isSelected ? .white : .white.opacity(0.68))
      .padding(.horizontal, 11)
      .frame(height: 32)
      .background(isSelected ? .red.opacity(0.22) : .white.opacity(0.07), in: Capsule())
      .overlay {
        Capsule()
          .stroke(isSelected ? .red.opacity(0.55) : .white.opacity(0.10), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
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

  private func resetChannelPaging() {
    channelDisplayLimitCount = isSearching ? searchChannelPageSize : channelPageSize
  }

  private func loadMoreChannelsIfNeeded() {
    guard displayedChannels.count < visibleChannelCount else { return }
    let pageSize = isSearching ? searchChannelPageSize : channelPageSize
    channelDisplayLimitCount += pageSize
    rebuildDisplayedChannels()
    refreshVisibleEPGIfNeeded()
  }

  private func scheduleLiveTVRebuild() {
    rebuildTask?.cancel()
    rebuildTask = Task {
      try? await Task.sleep(nanoseconds: 180_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        resetChannelPaging()
        rebuildLiveTVCaches()
        selectFirstChannelIfNeeded(force: true)
        refreshVisibleEPGIfNeeded()
      }
    }
  }

  private func rebuildLiveTVCaches() {
    rebuildCategoryNameCache()
    rebuildCategoryOptionsCache()
    applyDefaultLiveTVCategoryIfNeeded()
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
      ("Sports", ["sport", "sports", "f1", "nba", "nfl", "mlb", "soccer"]),
      ("News", ["news"]),
      ("Movies", ["movie", "movies", "cinema"]),
      ("Kids", ["kid", "kids", "child", "children", "cartoon"]),
    ]

    var options: [LiveTVCategoryOption] = [
      LiveTVCategoryOption(id: nil, title: "All")
    ]

    for item in requested {
      guard let category = matchingCategory(keywords: item.1) else { continue }
      options.append(LiveTVCategoryOption(id: category.id, title: item.0))
    }

    categoryOptionsCache = options
  }

  private func applyDefaultLiveTVCategoryIfNeeded() {
    guard !showFavoritesOnly, !showRecentOnly, !isSearching else { return }

    let availableIds = Set(categoryOptionsCache.compactMap(\.id))
    if let selectedCategoryId, availableIds.contains(selectedCategoryId) {
      return
    }

    selectedCategoryId = categoryOptionsCache.first(where: { $0.title == "Sports" })?.id
      ?? categoryOptionsCache.first?.id
  }

  private func rebuildFavoriteChannelCache() {
    let favoriteIds = Set(favoriteChannels.map(\.id))
    guard !favoriteIds.isEmpty else {
      favoriteLiveChannelIds = []
      favoriteLiveChannelPreview = []
      favoriteLiveChannelCount = 0
      return
    }

    guard let realm = try? Realm() else {
      favoriteLiveChannelIds = favoriteIds
      favoriteLiveChannelPreview = []
      favoriteLiveChannelCount = favoriteIds.count
      return
    }

    let favorites = realm.objects(CachedStream.self)
      .filter("section == %@ AND id IN %@", KindMedia.live.rawValue, Array(favoriteIds))

    favoriteLiveChannelIds = favoriteIds
    favoriteLiveChannelPreview = Array(favorites.prefix(12))
    favoriteLiveChannelCount = favorites.count
  }

  private func rebuildDisplayedChannels() {
    if let smart = activeLiveSmartSection {
      let rows = smart.channels(country: userRegion.context.country, region: userRegion.context.region)
      displayedChannels = rows
      displayedChannelTotal = rows.count
      rebuildCurrentProgramCache(for: displayedChannels)
      return
    }

    let limit = channelDisplayLimit

    guard !hideDuplicateChannels else {
      rebuildDisplayedChannelsWithDuplicateCleanup(limit: limit)
      return
    }

    guard let results = makeLiveChannelQuery() else {
      displayedChannels = []
      displayedChannelTotal = 0
      rebuildCurrentProgramCache(for: [])
      return
    }

    let rows = Array(results.prefix(limit))
    displayedChannels = sortInMemoryIfNeeded(rows)
    displayedChannelTotal = results.count
    rebuildCurrentProgramCache(for: displayedChannels)
  }

  private func rebuildDisplayedChannelsWithDuplicateCleanup(limit: Int) {
    guard let results = makeLiveChannelQuery() else {
      displayedChannels = []
      displayedChannelTotal = 0
      rebuildCurrentProgramCache(for: [])
      return
    }

    var rows: [CachedStream] = []
    var seenDuplicateKeys = Set<String>()
    rows.reserveCapacity(limit)
    var total = 0

    for channel in results {
      let duplicateKey = TVChannelText.duplicateKey(channel.name)
      guard !seenDuplicateKeys.contains(duplicateKey) else { continue }
      seenDuplicateKeys.insert(duplicateKey)

      total += 1
      if rows.count < limit {
        rows.append(channel)
      }
    }

    displayedChannels = sortInMemoryIfNeeded(rows)
    displayedChannelTotal = total
    rebuildCurrentProgramCache(for: displayedChannels)
  }

  private func makeLiveChannelQuery() -> Results<CachedStream>? {
    guard let realm = try? Realm() else { return nil }

    var results = realm.objects(CachedStream.self)
      .filter("section == %@", KindMedia.live.rawValue)

    if let regionIds = regionChannelCategoryIds {
      results = results.filter("categoryId IN %@", Array(regionIds))
    }

    if showFavoritesOnly {
      guard !favoriteLiveChannelIds.isEmpty else { return nil }
      results = results.filter("id IN %@", Array(favoriteLiveChannelIds))
    }

    if showRecentOnly {
      let recentIds = recentLiveChannelIds
      guard !recentIds.isEmpty else { return nil }
      results = results.filter("id IN %@", recentIds)
    }

    if !isSearching, let selectedCategoryId {
      results = results.filter("categoryId == %@", selectedCategoryId)
    }

    if isSearching {
      results = applySearchFilter(to: results)
    }

    switch sortMode {
    case .az:
      results = results.sorted(byKeyPath: "name", ascending: true)
    case .liveNow:
      results = results
        .filter("NOT name CONTAINS[c] %@", "NO EVENT STREAMING")
        .sorted(byKeyPath: "name", ascending: true)
    case .playlist:
      break
    }

    return results
  }

  private func applySearchFilter(to results: Results<CachedStream>) -> Results<CachedStream> {
    let search = trimmedSearchText
    let matchingCategoryIds = categoryNameCache
      .filter { $0.value.localizedCaseInsensitiveContains(search) }
      .map(\.key)

    if matchingCategoryIds.isEmpty {
      return results.filter(
        "name CONTAINS[c] %@ OR streamType CONTAINS[c] %@",
        search,
        search
      )
    }

    return results.filter(
      "name CONTAINS[c] %@ OR streamType CONTAINS[c] %@ OR categoryId IN %@",
      search,
      search,
      matchingCategoryIds
    )
  }

  private func sortInMemoryIfNeeded(_ rows: [CachedStream]) -> [CachedStream] {
    switch sortMode {
    case .liveNow:
      return rows
    case .az:
      return rows
    case .playlist:
      return rows
    }
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
    var currentByStreamId: [Int: CachedEPGProgram] = [:]
    var nextByStreamId: [Int: CachedEPGProgram] = [:]

    for program in epgPrograms where streamIds.contains(program.streamId) {
      if program.startDate <= now, program.endDate > now {
        currentByStreamId[program.streamId] = program
      } else if program.startDate > now {
        if let existing = nextByStreamId[program.streamId] {
          if program.startDate < existing.startDate {
            nextByStreamId[program.streamId] = program
          }
        } else {
          nextByStreamId[program.streamId] = program
        }
      }
    }

    var values: [Int: LiveProgram] = [:]
    for streamId in streamIds {
      guard let current = currentByStreamId[streamId] else { continue }
      let next = nextByStreamId[streamId]
      values[streamId] = LiveProgram(
        title: current.title,
        startDate: current.startDate,
        endDate: current.endDate,
        nextTitle: next?.title,
        nextStartDate: next?.startDate,
        nextEndDate: next?.endDate
      )
    }

    currentProgramsByStreamId = values
  }

  private func scheduleSearchUpdate() {
    searchTask?.cancel()
    let value = searchText
    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedValue.isEmpty else {
      effectiveSearchText = ""
      resetChannelPaging()
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
        resetChannelPaging()
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
    rememberRecentChannel(channel)
    if !requestedEPGStreamIds.contains(channel.id), !hasFreshEPG(for: channel.id) {
      fetchEPG(for: [channel.id])
    }
  }

  private func playInline(_ channel: CachedStream) {
    withAnimation(.snappy) {
      selectedChannel = channel
      inlinePlayingChannelId = channel.id
    }
    rememberRecentChannel(channel)
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
    rememberRecentChannel(channel)
    selectedStreamURL = URL(string: channel.streamURL())
    DispatchQueue.main.async {
      showPlayer = true
    }
  }

  private func rememberRecentChannel(_ channel: CachedStream) {
    var ids = recentLiveChannelIds.filter { $0 != channel.id }
    ids.insert(channel.id, at: 0)
    recentLiveChannelIdsRaw = ids.prefix(30).map(String.init).joined(separator: ",")
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
    // `requestedEPGStreamIds` tracks in-flight fetches: skip ids already in flight
    // so we don't duplicate work, but never gate on a single global flag — that
    // silently dropped EPG fetches requested while another batch was running, so a
    // channel tapped mid-refresh could be left with no program info.
    let pending = streamIds.filter { !requestedEPGStreamIds.contains($0) }
    guard !pending.isEmpty else { return }

    pending.forEach { requestedEPGStreamIds.insert($0) }
    isRefreshingEPG = true

    Task {
      for streamId in pending {
        do {
          let response = try await fetchShortEPG(streamId: streamId)
          await cache(response.epgListings, streamId: streamId)
        } catch {
          print("EPG fetch failed for stream \(streamId): \(error)")
        }
      }

      await MainActor.run {
        // Clear the in-flight marks regardless of outcome: successful ids now have
        // fresh EPG (so `hasFreshEPG` keeps them from being re-fetched), while failed
        // ids become eligible to retry on the next select/scroll instead of sticking.
        pending.forEach { requestedEPGStreamIds.remove($0) }
        rebuildCurrentProgramCache(for: displayedChannels)
        isRefreshingEPG = !requestedEPGStreamIds.isEmpty
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
  let nextTitle: String?
  let nextStartDate: Date?
  let nextEndDate: Date?
}

private struct GuidePreviewPlayer: View {
  let channel: CachedStream?
  let program: LiveProgram?
  let categoryName: String
  let isPlayingInline: Bool
  let canCatchUp: Bool
  let onPlayInline: () -> Void
  let onFullscreen: () -> Void
  let onCatchUp: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      videoArea
      if channel != nil {
        footer
      }
    }
    .background(Color.white.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(.white.opacity(0.08), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
  }

  // MARK: - Video

  private var videoArea: some View {
    ZStack {
      Color.black

      if let channel {
        if isPlayingInline, let url = URL(string: channel.streamURL()) {
          VideoPlayerView(streamURL: url, id: channel.id, kind: .live, showsControls: false)
            .id(channel.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        } else if let imagePath = channel.getImage(), !imagePath.isEmpty, let url = URL(string: imagePath) {
          previewBackdrop
          AsyncImage(url: url, placeholder: {
            previewPlaceholder
          }, content: { image in
            image
              .resizable()
              .scaledToFit()
              .frame(maxWidth: 180, maxHeight: 78)
              .opacity(0.52)
          })
        } else {
          previewPlaceholder
        }
      } else {
        VStack(spacing: 8) {
          Image(systemName: "tv").font(.system(size: 30, weight: .semibold))
          Text("Select a channel").font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.6))
      }
    }
    .aspectRatio(1.95, contentMode: .fit)
    .frame(maxWidth: .infinity)
    .clipped()
    .overlay(alignment: .topLeading) {
      if channel != nil { liveBadge.padding(10) }
    }
    .overlay(alignment: .bottomTrailing) {
      if channel != nil { fullscreenButton.padding(10) }
    }
    .overlay {
      if channel != nil, !isPlayingInline { centerPlayButton }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      if isPlayingInline { onFullscreen() }
    }
  }

  private var liveBadge: some View {
    HStack(spacing: 5) {
      Circle().fill(.red).frame(width: 7, height: 7)
      Text("LIVE").font(.caption2.weight(.heavy)).foregroundStyle(.white)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 5)
    .background(.black.opacity(0.55), in: Capsule())
  }

  private var fullscreenButton: some View {
    Button(action: onFullscreen) {
      Image(systemName: "arrow.up.left.and.arrow.down.right")
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 34, height: 34)
        .background(.black.opacity(0.55), in: Circle())
    }
    .buttonStyle(.plain)
  }

  private var centerPlayButton: some View {
    Button(action: onPlayInline) {
      Image(systemName: "play.fill")
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(.white)
        .offset(x: 1)
        .frame(width: 62, height: 62)
        .background(.black.opacity(0.4), in: Circle())
        .overlay { Circle().stroke(.white.opacity(0.75), lineWidth: 2) }
    }
    .buttonStyle(.plain)
  }

  // MARK: - Footer (channel info + progress + catch-up)

  private var footer: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(spacing: 12) {
        logoSquare
        VStack(alignment: .leading, spacing: 3) {
          Text(channel.map { TVChannelText.cleanName($0.name) } ?? "")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
          Text(channel.map { TVChannelText.status(channelName: $0.name, program: program) } ?? "")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
            .lineLimit(1)
        }
        Spacer(minLength: 0)

        Button(action: {
          if canCatchUp { onCatchUp() }
        }) {
          HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
            Text("Catch-up")
          }
          .font(.caption.weight(.bold))
          .foregroundStyle(.white.opacity(canCatchUp ? 0.92 : 0.50))
          .padding(.horizontal, 10)
          .frame(height: 30)
          .background(.white.opacity(canCatchUp ? 0.10 : 0.05), in: Capsule())
          .overlay { Capsule().stroke(.white.opacity(0.12), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(!canCatchUp)
      }

      if let program {
        VStack(spacing: 6) {
          GeometryReader { geo in
            ZStack(alignment: .leading) {
              Capsule().fill(.white.opacity(0.15))
              Capsule().fill(.red).frame(width: geo.size.width * progressFraction(program))
            }
          }
          .frame(height: 4)

          HStack {
            Text(GuideTime.range(program.startDate, program.endDate))
            Spacer()
            Text(timeLeft(program))
          }
          .font(.caption.weight(.medium))
          .foregroundStyle(.white.opacity(0.5))
        }
      }
    }
    .padding(12)
  }

  private var logoSquare: some View {
    ZStack {
      if let channel, let imagePath = channel.getImage(), !imagePath.isEmpty, let url = URL(string: imagePath) {
        AsyncImage(url: url, placeholder: {
          logoFallback
        }, content: { image in
          image.resizable().scaledToFit().padding(6)
        })
      } else {
        logoFallback
      }
    }
    .frame(width: 42, height: 42)
    .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

  private var logoFallback: some View {
    Image(systemName: "tv")
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(.white.opacity(0.7))
  }

  private func progressFraction(_ program: LiveProgram) -> CGFloat {
    let total = program.endDate.timeIntervalSince(program.startDate)
    guard total > 0 else { return 0 }
    let elapsed = Date().timeIntervalSince(program.startDate)
    return min(max(elapsed / total, 0), 1)
  }

  private func timeLeft(_ program: LiveProgram) -> String {
    let remaining = program.endDate.timeIntervalSince(Date())
    guard remaining > 0 else { return "Ended" }
    let minutes = Int(remaining / 60)
    return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m left" : "\(minutes)m left"
  }

  private var previewPlaceholder: some View {
    VStack(spacing: 10) {
      Image(systemName: "play.rectangle").font(.system(size: 34, weight: .semibold))
      Text("Tap play to watch").font(.subheadline.weight(.semibold))
    }
    .foregroundStyle(.white.opacity(0.62))
  }

  private var previewBackdrop: some View {
    LinearGradient(
      colors: [
        .black,
        .red.opacity(0.16),
        .black.opacity(0.92),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
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
            .frame(width: 56, height: 56)
            .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

          VStack(alignment: .leading, spacing: 4) {
            Text(TVChannelText.cleanName(channel.name))
              .font(.system(size: 16, weight: .bold))
              .foregroundStyle(.white)
              .lineLimit(1)

            Text(TVChannelText.status(channelName: channel.name, program: program))
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.white.opacity(0.62))
              .lineLimit(1)

            Text(GuideTime.nowNextLine(program))
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.white.opacity(0.46))
              .lineLimit(1)

            HStack(spacing: 5) {
              Circle().fill(.red).frame(width: 6, height: 6)
              Text("LIVE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.red.opacity(0.9))
            }
          }

          Spacer(minLength: 4)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button(action: onToggleFavorite) {
        Image(systemName: isFavorite ? "star.fill" : "star")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(isFavorite ? .yellow : .white.opacity(0.68))
          .frame(width: 42, height: 42)
          .background(.white.opacity(0.07), in: Circle())
      }
      .buttonStyle(.plain)

      Button(action: onPlay) {
        Image(systemName: "play.fill")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 46, height: 46)
          .background(.red, in: Circle())
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 11)
    .frame(minHeight: 82)
    .background(fillColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(strokeColor, lineWidth: 1)
    }
  }
}

private struct LiveNowChannelCard: View {
  let channel: CachedStream
  let program: LiveProgram?
  let isSelected: Bool
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 9) {
        logo
          .frame(width: 42, height: 42)
          .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

        VStack(alignment: .leading, spacing: 4) {
          Text(TVChannelText.cleanName(channel.name))
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)

          Text(TVChannelText.status(channelName: channel.name, program: program))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.62))
            .lineLimit(1)

          HStack(spacing: 5) {
            Circle().fill(.red).frame(width: 5, height: 5)
            Text("LIVE")
              .font(.system(size: 9, weight: .heavy))
              .foregroundStyle(.red)
          }

          GeometryReader { geo in
            ZStack(alignment: .leading) {
              Capsule().fill(.white.opacity(0.12))
              Capsule()
                .fill(.red)
                .frame(width: geo.size.width * progressFraction)
            }
          }
          .frame(height: 3)
        }
      }
      .padding(9)
      .frame(width: 188, height: 78)
      .background(isSelected ? .red.opacity(0.15) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
          .stroke(isSelected ? .red.opacity(0.55) : .white.opacity(0.08), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
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
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white.opacity(0.7))
    }
  }

  private var progressFraction: CGFloat {
    guard let program else { return 0.2 }
    let total = program.endDate.timeIntervalSince(program.startDate)
    guard total > 0 else { return 0.2 }
    let elapsed = Date().timeIntervalSince(program.startDate)
    return min(max(elapsed / total, 0.08), 1)
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
  let showRecentOnly: Bool
  let onSelect: (LiveTVCategoryOption) -> Void
  let onFavorites: () -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(options, id: \.stableId) { option in
          let isSelected = !showFavoritesOnly && !showRecentOnly && selectedCategoryId == option.id

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

        Button(action: onFavorites) {
          HStack(spacing: 6) {
            Image(systemName: "star")
              .font(.system(size: 11, weight: .bold))
            Text("Favorites")
          }
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(showFavoritesOnly ? .white : .white.opacity(0.72))
          .padding(.horizontal, 14)
          .frame(height: 36)
          .background(showFavoritesOnly ? .red : .white.opacity(0.07), in: Capsule())
          .overlay {
            Capsule().stroke(.white.opacity(showFavoritesOnly ? 0.16 : 0.10), lineWidth: 1)
          }
        }
        .buttonStyle(.plain)
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
  static func matches(_ channel: CachedStream, categoryName: String, programTitle: String?, search: String) -> Bool {
    let query = normalizedSearch(search)
    guard !query.isEmpty else { return true }

    let searchableText = [
      channel.name,
      channel.streamType,
      categoryName,
      programTitle ?? "",
    ]
    .joined(separator: " ")

    return normalizedSearch(searchableText).contains(query)
  }

  static func hasNoEvent(_ name: String) -> Bool {
    name.localizedCaseInsensitiveContains("no event streaming")
  }

  static func duplicateKey(_ name: String) -> String {
    normalizedSearch(cleanName(name))
      .replacingOccurrences(of: " hd", with: "")
      .replacingOccurrences(of: " fhd", with: "")
      .replacingOccurrences(of: " 4k", with: "")
      .replacingOccurrences(of: " 8k", with: "")
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

  static func nowNextLine(_ program: LiveProgram?) -> String {
    guard let program else {
      return "Now Live"
    }

    let now = "Now \(range(program.startDate, program.endDate))"
    guard let nextStartDate = program.nextStartDate,
          let nextEndDate = program.nextEndDate
    else {
      return now
    }

    return "\(now) • Next \(range(nextStartDate, nextEndDate))"
  }

  static func string(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
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
