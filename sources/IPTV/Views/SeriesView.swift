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
    return categories.filter { RegionTag.code(from: $0.name) == region }.map { $0.id }
  }

  private var regionSeries: Results<CachedSeries> {
    guard let ids = regionCategoryIds, !ids.isEmpty else { return series }
    return series.filter("categoryID IN %@", ids)
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
    Array(regionSeries.prefix(30))
  }

  // Group shows by genre (provider sends genre per series, e.g. "Comedy, Drama").
  // Each show can land in multiple genre rails. Only genres with enough titles show.
  private var genreRails: [(genre: String, series: [CachedSeries])] {
    var order: [String] = []
    var map: [String: [CachedSeries]] = [:]

    for serie in regionSeries.prefix(1200) {
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

  public init(kindMedia: KindMedia) {
    self.kindMedia = kindMedia
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 24) {
          if series.count == 0 {
            LibraryEmptyStateView(
              systemImage: "rectangle.stack",
              title: "No shows loaded yet",
              message: "Reload your playlist in Settings so the app can import shows from this provider."
            )
            .padding(.top, 48)
          } else if !genreRails.isEmpty {
            ForEach(genreRails, id: \.genre) { rail in
              SeriesRailShelf(title: rail.genre, series: rail.series) { serie in
                streamSelected = serie.id
                showPlayer = true
              }
            }
          } else if !recentShows.isEmpty {
            SeriesRailShelf(title: "Shows", series: recentShows) { serie in
              streamSelected = serie.id
              showPlayer = true
            }
          } else {
            ForEach(visibleCategories, id: \.id) { category in
              makeSection(for: category)
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
      .navigationDestination(isPresented: $showPlayer, destination: {
        if let streamSelected {
          SerieDetailView(streamId: streamSelected)
        }
      })
    }
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
