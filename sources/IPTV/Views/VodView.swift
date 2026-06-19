import IPTVComponents
import IPTVModels
import RealmSwift
import SwiftUI

public struct VodView: View {
  @State private var showPlayer: Bool = false
  @State private var selectedStreamURL: URL? = nil
  @State private var selectedPlaybackContext: PlaybackProgressContext?
  @State private var selectedKind: KindMedia = .vod
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

  // Category ids belonging to the selected region (nil = all regions).
  private var regionCategoryIds: [String]? {
    guard !region.isEmpty else { return nil }
    return categories.filter { RegionTag.code(from: $0.name) == region }.map { $0.id }
  }

  // Movies constrained to the selected region (indexed query, so it's cheap).
  private var regionMovies: Results<CachedStream> {
    guard let ids = regionCategoryIds, !ids.isEmpty else { return movies }
    return movies.filter("categoryId IN %@", ids)
  }

  private var visibleCategories: [CategoryEntity] {
    let scoped: [CategoryEntity]
    if let ids = regionCategoryIds {
      let allowed = Set(ids)
      scoped = categories.filter { allowed.contains($0.id) }
    } else {
      scoped = Array(categories)
    }

    guard let selectedCategoryId else {
      return Array(scoped.prefix(12))
    }
    return scoped.filter { $0.id == selectedCategoryId }
  }

  private var featuredMovie: CachedStream? {
    regionMovies.first
  }

  // Newest first — `movies` is already sorted by `added` descending.
  private var recentlyAddedMovies: [CachedStream] {
    Array(regionMovies.prefix(20))
  }

  // Proxy for "trending": top-rated among the most recent additions
  // (bounded so we never sort the entire library on every render).
  private var trendingMovies: [CachedStream] {
    let pool = Array(regionMovies.prefix(250))
    return Array(pool.sorted { ratingValue($0) > ratingValue($1) }.prefix(18))
  }

  // Recommend more from the category of whatever the user last watched.
  private var becauseYouWatched: (title: String, streams: [CachedStream])? {
    guard let anchorItem = continueItems.first(where: { $0.kind == KindMedia.vod.rawValue }),
          let anchor = movies.where({ $0.id == anchorItem.mediaId }).first,
          !anchor.categoryId.isEmpty
    else {
      return nil
    }

    let related = movies
      .where { $0.categoryId == anchor.categoryId }
      .filter { $0.id != anchor.id }

    guard related.count >= 3 else { return nil }
    return ("Because you watched \(anchor.name.formatted())", Array(related.prefix(18)))
  }

  private func ratingValue(_ stream: CachedStream) -> Double {
    Double(stream.rating ?? "") ?? 0
  }

  // Movie genre rails, populated as background enrichment fills CachedStream.genre.
  private var movieGenreRails: [(genre: String, movies: [CachedStream])] {
    var order: [String] = []
    var map: [String: [CachedStream]] = [:]

    for movie in regionMovies.prefix(1200) {
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

  public init(kindMedia: KindMedia) {
    self.kindMedia = kindMedia
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 24) {
          if categories.count == 0 || movies.count == 0 {
            LibraryEmptyStateView(
              systemImage: "film.stack",
              title: categories.count == 0 ? "No movie categories yet" : "No movies loaded yet",
              message: "Add your Xtream playlist in Settings, then tap Save & Load Playlist."
            )
            .padding(.top, 48)
          } else {
            FeaturedMovieHeroView(movie: featuredMovie) {
              if let featuredMovie {
                openMovie(featuredMovie)
              }
            }
            .padding(.horizontal, -16)
            .padding(.top, -8)

            homeLastWatchedSection

            MediaRailShelf(title: "Recently Added", streams: recentlyAddedMovies) { stream in
              openMovie(stream)
            }

            MediaRailShelf(title: "Trending Now", streams: trendingMovies) { stream in
              openMovie(stream)
            }

            if let because = becauseYouWatched {
              MediaRailShelf(title: because.title, streams: because.streams) { stream in
                openMovie(stream)
              }
            }

            if !movieGenreRails.isEmpty {
              ForEach(movieGenreRails, id: \.genre) { rail in
                MediaRailShelf(title: rail.genre, streams: rail.movies) { stream in
                  openMovie(stream)
                }
              }
            } else {
              ForEach(visibleCategories, id: \.id) { category in
                makeSection(for: category)
              }
            }
          }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
      }
      .background {
        HeroHeaderView(belowFold: true)
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
    }
  }

  @ViewBuilder
  private var homeLastWatchedSection: some View {
    let items = continueItems
      .filter { $0.kind == KindMedia.vod.rawValue || $0.kind == KindMedia.series.rawValue }
      .prefix(12)

    ContinueWatchingShelf(
      title: "Last Watched",
      items: Array(items)
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
      openMovie(stream)
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
