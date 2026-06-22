import IPTVComponents
import IPTVModels
import RealmSwift
import SwiftUI

private struct MovieHomeSections {
  var featured: CachedStream?
  var trending: [CachedStream] = []
  var bestReviewed: [CachedStream] = []
  var newlyAdded: [CachedStream] = []
  var international: [CachedStream] = []
  var genreRails: [(genre: String, movies: [CachedStream])] = []
}

public struct VodView: View {
  @State private var showPlayer: Bool = false
  @State private var selectedStreamURL: URL? = nil
  @State private var selectedPlaybackContext: PlaybackProgressContext?
  @State private var selectedKind: KindMedia = .vod
  @State private var selectedMovieForDetails: CachedStream?
  @State private var showMovieDetails = false
  @State private var showErrorAlert: Bool = false
  @State private var errorMessage: String = ""

  @State var progress: Double = 0.0
  @State var isLoading: Bool = false
  @State private var selectedCategoryId: String?

  private let kindMedia: KindMedia
  @ObservedResults(CategoryEntity.self, where: ({ $0.section == KindMedia.vod.rawValue })) var categories
  @ObservedResults(CachedStream.self, where: ({ $0.section == KindMedia.vod.rawValue }), sortDescriptor: SortDescriptor(keyPath: "added", ascending: false)) var movies
  @ObservedResults(CachedPlaybackProgress.self, sortDescriptor: SortDescriptor(keyPath: "updatedAt", ascending: false)) var continueItems
  @AppStorage("contentRegion") private var region: String = ""
  @ObservedObject private var userRegion = UserRegionProvider.shared

  // MARK: - Smart sections (auto country). Computed into @State on data/region
  // changes — never per-render — so scrolling and tab switches just read arrays
  // instead of re-running Realm queries on the main thread.

  @State private var sections = MovieHomeSections()
  @State private var sectionRefreshTask: Task<Void, Never>?

  private var smartCountry: String? { userRegion.context.country }

  // Category ids belonging to the selected region (nil = all regions).
  private var regionCategoryIds: [String]? {
    guard !region.isEmpty else { return nil }
    let ids = Array(categories.filter { RegionTag.code(from: $0.name) == region }.map { $0.id })
    // If this section has no categories for the chosen region, don't filter.
    return ids.isEmpty ? nil : ids
  }

  // Movies constrained to the selected region (indexed query, so it's cheap).
  private var regionMovies: Results<CachedStream> {
    guard let ids = regionCategoryIds, !ids.isEmpty else { return movies }
    return movies.filter("categoryId IN %@", ids)
  }

  private var featuredMovie: CachedStream? {
    regionMovies.first
  }

  // Movie genre rails, populated as background enrichment fills CachedStream.genre.
  private func computeGenreRails() -> [(genre: String, movies: [CachedStream])] {
    var order: [String] = []
    var map: [String: [CachedStream]] = [:]

    var scanned = 0
    for movie in regionMovies {
      guard scanned < 1200 else { break }
      scanned += 1

      guard let raw = movie.genre, !raw.isEmpty,
            let primary = splitGenres(raw).first
      else { continue }
      if map[primary] == nil { order.append(primary) }
      map[primary, default: []].append(movie)
    }

    let ranked = order
      .compactMap { key -> (String, [CachedStream])? in
        guard let list = map[key], list.count >= 5 else { return nil }
        return (key, list)
      }
      .sorted { $0.1.count > $1.1.count }

    return ranked.prefix(8).map { ($0.0, Array($0.1.prefix(20))) }
  }

  private func splitGenres(_ raw: String) -> [String] {
    raw.split(whereSeparator: { $0 == "," || $0 == "/" || $0 == "|" })
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  // MARK: - Section refresh

  private func recomputeSections() {
    var next = MovieHomeSections()
    next.featured = SmartSections.forYouMovies(limit: 1).first ?? featuredMovie
    next.trending = SmartSections.trendingMovies(country: smartCountry)
    next.bestReviewed = SmartSections.bestReviewedNewMovies()
    next.newlyAdded = SmartSections.newlyAddedMovies()
    next.international = SmartSections.internationalMovies(country: smartCountry)
    next.genreRails = computeGenreRails()
    sections = next
  }

  /// Coalesce bursts of background writes (enrichment/scoring/trending) into a
  /// single refresh rather than re-querying on every change.
  private func scheduleSectionRefresh() {
    sectionRefreshTask?.cancel()
    sectionRefreshTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 1_200_000_000)
      guard !Task.isCancelled else { return }
      recomputeSections()
    }
  }

  public init(kindMedia: KindMedia) {
    self.kindMedia = kindMedia
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 24) {
          if categories.first == nil || movies.first == nil {
            LibraryEmptyStateView(
              systemImage: "film.stack",
              title: categories.first == nil ? "No movie categories yet" : "No movies loaded yet",
              message: "Add your Xtream playlist in Settings, then tap Save & Load Playlist."
            )
            .padding(.top, 48)
          } else {
            // Featured For You (req 10)
            FeaturedMovieHeroView(movie: sections.featured) {
              if let movie = sections.featured { openMovie(movie) }
            }

            homeContinueWatchingSection

            if !sections.trending.isEmpty {
              MediaRailShelf(title: "Trending In Your Country", streams: sections.trending) { openMovie($0) }
            }

            MediaRailShelf(title: "Best Reviewed New Movies", streams: sections.bestReviewed) { openMovie($0) }

            MediaRailShelf(title: "Newly Added", streams: sections.newlyAdded) { openMovie($0) }

            if !sections.international.isEmpty {
              MediaRailShelf(title: "International Movies", streams: sections.international) { openMovie($0) }
            }

            // Genre rails kept below the personalized sections as a bonus.
            ForEach(sections.genreRails, id: \.genre) { rail in
              MediaRailShelf(title: rail.genre, streams: rail.movies) { openMovie($0) }
            }
          }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
      }
      .background {
        HeroHeaderView(belowFold: true)
      }
      .task {
        // Backfill movie genres in the background (resumes across launches);
        // without this the genre rails below stay empty for most of the catalog.
        MovieGenreEnricher.enrichIfNeeded()
        recomputeSections()
      }
      .onChange(of: userRegion.context) { recomputeSections() }
      .onChange(of: movies.count) { scheduleSectionRefresh() }
      .onReceive(NotificationCenter.default.publisher(for: .smartSectionsDidUpdate)) { _ in
        scheduleSectionRefresh()
      }
      .alert("Error", isPresented: $showErrorAlert) {
        Button("OK", role: .cancel) {
        }
      } message: {
        Text(errorMessage)
      }
      .fullScreenCover(isPresented: Binding(get: {
        showPlayer && selectedStreamURL != nil
      }, set: { showPlayer = $0 })) {
        if let streamURL = selectedStreamURL {
          ViewPlayerContent(
            mediaURL: streamURL,
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
    }
  }

  @ViewBuilder
  private var homeContinueWatchingSection: some View {
    let items = continueItems
      .filter { $0.kind == KindMedia.vod.rawValue || $0.kind == KindMedia.series.rawValue }
      .prefix(12)

    ContinueWatchingShelf(
      title: "Continue Watching",
      items: Array(items),
      style: .compactHome
    ) { item in
      openContinueItem(item)
    }
  }

  @State private var currentID: Int = 9999

  @ViewBuilder
  private func makeSectionFavori() -> some View {
    Section {
      FavoriMovieShelf(kindMedia: kindMedia) { stream in
        openFavoriteMovie(stream)
      }
    }
  }

  @ViewBuilder
  private func makeSection(for category: CategoryEntity) -> some View {
    Section {
      MovieShelf(category: category, kindMedia: kindMedia) { stream in
        openMovie(stream)
      }
    }
  }

  private func openMovie(_ stream: CachedStream) {
    selectedMovieForDetails = stream
    showMovieDetails = true
  }

  private func playMovie(_ stream: CachedStream) {
    let streamURL = stream.streamURL()
    currentID = stream.id
    selectedKind = .vod
    selectedStreamURL = URL(string: streamURL)
    selectedPlaybackContext = PlaybackProgressContext(
      mediaId: stream.id,
      kind: .vod,
      title: stream.name.formatted(),
      subtitle: movieSubtitle(stream),
      imageURL: stream.tmdbImage ?? stream.streamIcon,
      streamURL: streamURL
    )
    showPlayer = true
  }

  private func openContinueItem(_ item: CachedPlaybackProgress) {
    let itemKind = KindMedia(rawValue: item.kind) ?? .vod
    if itemKind == .vod, let stream = movies.where({ $0.id == item.mediaId }).first {
      playMovie(stream)
      return
    }

    currentID = item.mediaId
    selectedKind = itemKind
    selectedStreamURL = URL(string: item.streamURL)
    selectedPlaybackContext = PlaybackProgressContext(progress: item)
    showPlayer = true
  }

  private func openFavoriteMovie(_ stream: FavoriEntity) {
    if let movie = movies.where({ $0.id == stream.id }).first {
      openMovie(movie)
      return
    }

    let streamURL = stream.streamURL()
    currentID = stream.id
    selectedKind = .vod
    selectedStreamURL = URL(string: streamURL)
    selectedPlaybackContext = PlaybackProgressContext(
      mediaId: stream.id,
      kind: .vod,
      title: stream.name.formatted(),
      imageURL: stream.streamIcon,
      streamURL: streamURL
    )
    showPlayer = true
  }

  private func movieSubtitle(_ stream: CachedStream) -> String? {
    if let year = stream.year, year > 0 {
      return "\(year)"
    }
    if let rating = stream.rating, !rating.isEmpty, rating != "0" {
      return "Rating \(rating)"
    }
    return nil
  }

  private func loadCategories() async {
    do {
      let fetchedCategories = try await fetchCategories()

      await CacheManager.shared.cacheCategories(fetchedCategories, for: kindMedia.rawValue)

      for category in fetchedCategories {
        let streams = try await loadStreams(for: category.id)

        await MainActor.run {
          CacheManager.shared.cacheStreams(streams, for: kindMedia.rawValue)
        }
      }

      await MainActor.run {
        isLoading = false
      }
    } catch {
      await MainActor.run {
        errorMessage = error.localizedDescription
        showErrorAlert = true
        isLoading = false
      }
    }
  }

  private func fetchCategories() async throws -> [IPTVModels.Category] {
    let liveURL = URL(string: "\(APIManager.shared.baseURL)&action=get_vod_categories")!
    return try await withCheckedThrowingContinuation { continuation in
      APIManager.shared.fetchCategories(from: liveURL) { result in
        switch result {
        case let .success(categories):
          continuation.resume(returning: categories)
        case let .failure(error):
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func loadStreams(for categoryId: String) async throws -> [IPTVModels.Stream] {
    let apiURL = "\(APIManager.shared.baseURL)&action=get_vod_streams&category_id=\(categoryId)"
    return try await withCheckedThrowingContinuation { continuation in
      APIManager.shared.fetchStreams(for: apiURL) { result in
        switch result {
        case let .success(streams):
          continuation.resume(returning: streams)
        case let .failure(error):
          continuation.resume(throwing: error)
        }
      }
    }
  }
}

#Preview {
  VodView(kindMedia: .vod)
}
