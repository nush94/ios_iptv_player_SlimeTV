import IPTVComponents
import IPTVModels
import RealmSwift
import SwiftUI

private struct ShowHomeSections {
  var forYou: [CachedSeries] = []
  var trending: [CachedSeries] = []
  var bestReviewed: [CachedSeries] = []
  var newlyAdded: [CachedSeries] = []
  var international: [CachedSeries] = []
  var genreRails: [(genre: String, series: [CachedSeries])] = []
}

public struct SeriesView: View {
  @State private var showPlayer: Bool = false
  @State private var streamSelected: Int?

  @State private var showErrorAlert: Bool = false
  @State private var errorMessage: String = ""

  @State var progress: Double = 0.0
  @State var isLoading: Bool = false
  @State private var selectedCategoryId: String?

  private let kindMedia: KindMedia
  @ObservedResults(CategoryEntity.self, where: ({ $0.section == KindMedia.series.rawValue })) var categories
  @ObservedResults(CachedSeries.self, where: ({ $0.section == KindMedia.series.rawValue })) var series
  @AppStorage("contentRegion") private var region: String = ""
  @ObservedObject private var userRegion = UserRegionProvider.shared
  @ObservedResults(CachedPlaybackProgress.self, sortDescriptor: SortDescriptor(keyPath: "updatedAt", ascending: false)) private var continueItems
  @State private var showContinuePlayer = false
  @State private var continueStreamURL: URL?
  @State private var continuePlaybackContext: PlaybackProgressContext?
  @State private var continueID = 9999

  // MARK: - Smart sections (auto country). Cached in @State, refreshed on
  // data/region changes — not per-render — so scrolling/tab switches stay smooth.

  @State private var sections = ShowHomeSections()
  @State private var sectionRefreshTask: Task<Void, Never>?

  private var smartCountry: String? { userRegion.context.country }

  private var regionCategoryIds: [String]? {
    guard !region.isEmpty else { return nil }
    let ids = Array(categories.filter { RegionTag.code(from: $0.name) == region }.map { $0.id })
    // If this section has no categories for the chosen region, don't filter.
    return ids.isEmpty ? nil : ids
  }

  private var regionSeries: Results<CachedSeries> {
    // Hide shows confirmed to have no episodes from the provider; keep
    // not-yet-checked shows visible (they drop out as the background episode
    // check confirms them empty).
    let playable = series.filter("episodesChecked == false OR episodeCount > 0")
    guard let ids = regionCategoryIds, !ids.isEmpty else { return playable }
    return playable.filter("categoryID IN %@", ids)
  }

  // Group shows by genre (provider sends genre per series, e.g. "Comedy, Drama").
  // Each show can land in multiple genre rails. Only genres with enough titles show.
  private func computeGenreRails() -> [(genre: String, series: [CachedSeries])] {
    var order: [String] = []
    var map: [String: [CachedSeries]] = [:]

    var scanned = 0
    for serie in regionSeries {
      guard scanned < 1200 else { break }
      scanned += 1

      guard !SmartSections.isAdult(name: serie.name, genre: serie.genre) else { continue }
      guard let primary = genres(from: serie.genre).first else { continue }
      if map[primary] == nil { order.append(primary) }
      map[primary, default: []].append(serie)
    }

    return order
      .compactMap { key -> (String, [CachedSeries])? in
        guard let list = map[key], list.count >= 4 else { return nil }
        return (key, list)
      }
      .sorted { $0.1.count > $1.1.count }
      .prefix(8)
      .map { ($0.0, Array($0.1.prefix(20))) }
  }

  private func genres(from raw: String?) -> [String] {
    (raw ?? "")
      .split(whereSeparator: { $0 == "," || $0 == "/" || $0 == "|" })
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  // MARK: - Section refresh

  private func recomputeSections() {
    var next = ShowHomeSections()
    next.forYou = SmartSections.forYouShows()
    next.trending = SmartSections.trendingShows(country: smartCountry)
    next.bestReviewed = SmartSections.bestReviewedShows()
    next.newlyAdded = SmartSections.newlyAddedShows()
    next.international = SmartSections.internationalShows(country: smartCountry)
    next.genreRails = computeGenreRails()
    sections = next
  }

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
          if regionSeries.first == nil {
            LibraryEmptyStateView(
              systemImage: "rectangle.stack",
              title: "No shows loaded yet",
              message: "Reload your playlist in Settings so the app can import shows from this provider."
            )
            .padding(.top, 48)
          } else {
            // Featured For You (req 11)
            SeriesRailShelf(title: "Featured For You", series: sections.forYou) { openSeries($0) }

            continueWatchingSection

            if !sections.trending.isEmpty {
              SeriesRailShelf(title: "Trending Shows In Your Country", series: sections.trending) { openSeries($0) }
            }

            SeriesRailShelf(title: "Best Reviewed Shows", series: sections.bestReviewed) { openSeries($0) }

            SeriesRailShelf(title: "Newly Added", series: sections.newlyAdded) { openSeries($0) }

            if !sections.international.isEmpty {
              SeriesRailShelf(title: "International Shows", series: sections.international) { openSeries($0) }
            }

            // Genre rails kept below the personalized sections as a bonus.
            ForEach(sections.genreRails, id: \.genre) { rail in
              SeriesRailShelf(title: rail.genre, series: rail.series) { openSeries($0) }
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
        // Backfill episode counts so shows with nothing to play drop out of the
        // rails (resumes across launches; only unchecked shows are processed).
        SeriesEpisodeEnricher.enrichIfNeeded()
        recomputeSections()
      }
      .onChange(of: userRegion.context) { recomputeSections() }
      .onChange(of: series.count) { scheduleSectionRefresh() }
      .onReceive(NotificationCenter.default.publisher(for: .smartSectionsDidUpdate)) { _ in
        scheduleSectionRefresh()
      }
      .alert("Error", isPresented: $showErrorAlert) {
        Button("OK", role: .cancel) {
        }
      } message: {
        Text(errorMessage)
      }
      .navigationDestination(isPresented: $showPlayer, destination: {
        if let streamSelected {
          SerieDetailView(streamId: streamSelected)
        }
      })
      .fullScreenCover(isPresented: Binding(get: {
        showContinuePlayer && continueStreamURL != nil
      }, set: { showContinuePlayer = $0 })) {
        if let continueStreamURL {
          ViewPlayerContent(
            mediaURL: continueStreamURL,
            id: continueID,
            kind: .series,
            playbackContext: continuePlaybackContext
          )
          .ignoresSafeArea()
        }
      }
    }
  }

  @ViewBuilder
  private var continueWatchingSection: some View {
    let items = continueItems
      .filter { $0.kind == KindMedia.series.rawValue }
      .prefix(12)
    ContinueWatchingShelf(title: "Continue Watching", items: Array(items), style: .compactHome) { item in
      openContinueItem(item)
    }
  }

  private func openContinueItem(_ item: CachedPlaybackProgress) {
    continueID = item.mediaId
    continueStreamURL = URL(string: item.streamURL)
    continuePlaybackContext = PlaybackProgressContext(progress: item)
    showContinuePlayer = true
  }

  private func openSeries(_ serie: CachedSeries) {
    streamSelected = serie.id
    showPlayer = true
  }

  @ViewBuilder
  private func makeSectionFavori() -> some View {
    Section {
      FavoriSerieShelf(kindMedia: kindMedia) { stream in
        streamSelected = stream.id
        showPlayer = true
      }
    }
  }

  @ViewBuilder
  private func makeSection(for category: CategoryEntity) -> some View {
    Section {
      SerieShelf(category: category, kindMedia: kindMedia) { stream in
        streamSelected = stream.id
        showPlayer = true
      }
    }
  }

  private func loadCategories() async {
    do {
      let fetchedCategories = try await fetchCategories()

      await CacheManager.shared.cacheCategories(fetchedCategories, for: kindMedia.rawValue)

      for category in fetchedCategories {
        let series = try await loadSeries(for: category.id)

        await MainActor.run {
          CacheManager.shared.cacheSeries(series, for: kindMedia.rawValue)
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
    let action = "get_series_categories"

    let liveURL = URL(string: "\(APIManager.shared.baseURL)&action=\(action)")!
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

  private func loadSeries(for categoryId: String) async throws -> [Series] {
    let action = "get_series"

    let apiURL = "\(APIManager.shared.baseURL)&action=\(action)&category_id=\(categoryId)"
    return try await withCheckedThrowingContinuation { continuation in
      APIManager.shared.fetchSeries(for: apiURL) { result in
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
