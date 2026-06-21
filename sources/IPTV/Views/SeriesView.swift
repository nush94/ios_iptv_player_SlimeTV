import IPTVComponents
import IPTVModels
import RealmSwift
import SwiftUI

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

  private var recentShows: [CachedSeries] {
    limitedSeries(30)
  }

  private var currentYear: Int {
    Calendar.current.component(.year, from: Date())
  }

  private var newShowCutoffYear: Int {
    max(currentYear - 2, 2024)
  }

  private var newShows: [CachedSeries] {
    let pool = scannedSeries(900)
      .filter { seriesYear($0) >= newShowCutoffYear }

    let ranked = pool.sorted {
      let firstYear = seriesYear($0)
      let secondYear = seriesYear($1)
      if firstYear != secondYear { return firstYear > secondYear }
      return $0.lastModified > $1.lastModified
    }

    return Array(ranked.prefix(24))
  }

  private var bestReviewedNewShows: [CachedSeries] {
    let pool = scannedSeries(1200)
      .filter { seriesYear($0) >= newShowCutoffYear && ratingValue($0) > 0 }

    let ranked = pool.sorted {
      let firstRating = ratingValue($0)
      let secondRating = ratingValue($1)
      if firstRating != secondRating { return firstRating > secondRating }

      let firstYear = seriesYear($0)
      let secondYear = seriesYear($1)
      if firstYear != secondYear { return firstYear > secondYear }

      return $0.lastModified > $1.lastModified
    }

    return Array(ranked.prefix(24))
  }

  // Group shows by genre (provider sends genre per series, e.g. "Comedy, Drama").
  // Each show can land in multiple genre rails. Only genres with enough titles show.
  private var genreRails: [(genre: String, series: [CachedSeries])] {
    var order: [String] = []
    var map: [String: [CachedSeries]] = [:]

    var scanned = 0
    for serie in regionSeries {
      guard scanned < 1200 else { break }
      scanned += 1

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

  private func limitedSeries(_ limit: Int) -> [CachedSeries] {
    guard limit > 0 else { return [] }
    var values: [CachedSeries] = []
    values.reserveCapacity(limit)

    for serie in regionSeries {
      values.append(serie)
      if values.count == limit { break }
    }

    return values
  }

  private func scannedSeries(_ limit: Int) -> [CachedSeries] {
    limitedSeries(limit)
  }

  private func ratingValue(_ serie: CachedSeries) -> Double {
    serie.rating ?? serie.rating5Based ?? 0
  }

  private func seriesYear(_ serie: CachedSeries) -> Int {
    if let year = StreamYearExtractor.year(from: serie.releaseDate) {
      return year
    }
    if let year = StreamYearExtractor.year(from: serie.name) {
      return year
    }

    let year = Calendar.current.component(.year, from: serie.lastModified)
    return year > 1900 ? year : 0
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
            SeriesRailShelf(title: "Best Reviewed New Shows", series: bestReviewedNewShows) { serie in
              openSeries(serie)
            }

            SeriesRailShelf(title: "New Shows", series: newShows) { serie in
              openSeries(serie)
            }

            if !genreRails.isEmpty {
              ForEach(genreRails, id: \.genre) { rail in
                SeriesRailShelf(title: rail.genre, series: rail.series) { serie in
                  openSeries(serie)
                }
              }
            } else if !recentShows.isEmpty {
              SeriesRailShelf(title: "Shows", series: recentShows) { serie in
                openSeries(serie)
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
      .task {
        // Backfill episode counts so shows with nothing to play drop out of the
        // rails (resumes across launches; only unchecked shows are processed).
        SeriesEpisodeEnricher.enrichIfNeeded()
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
    }
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
