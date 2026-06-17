import IPTVComponents
import IPTVModels
import RealmSwift
import SwiftUI

public struct SeriesView: View {
  @State private var showPlayer: Bool = false
  @State private var selectedStreamURL: URL?
  @State private var streamSelected: Int?

  @State private var showErrorAlert: Bool = false
  @State private var errorMessage: String = ""

  @State var progress: Double = 0.0
  @State var isLoading: Bool = false
  @State private var selectedCategoryId: String?

  private let kindMedia: KindMedia
  @ObservedResults(CategoryEntity.self, where: ({ $0.section == KindMedia.series.rawValue })) var categories
  @ObservedResults(CachedSeries.self, where: ({ $0.section == KindMedia.series.rawValue })) var series

  private var visibleCategories: [CategoryEntity] {
    guard let selectedCategoryId else {
      return Array(categories)
    }

    return categories.filter { $0.id == selectedCategoryId }
  }

  public init(kindMedia: KindMedia) {
    self.kindMedia = kindMedia
  }

  public var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 24) {
          if categories.count == 0 || series.count == 0 {
            LibraryEmptyStateView(
              systemImage: "rectangle.stack",
              title: categories.count == 0 ? "No series categories yet" : "No shows loaded yet",
              message: "Add your Xtream playlist in Settings, then tap Save & Load Playlist."
            )
            .padding(.top, 48)
          } else {
            makeSectionFavori()

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
