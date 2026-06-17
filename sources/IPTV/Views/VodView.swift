import IPTVComponents
import IPTVModels
import RealmSwift
import SwiftUI

public struct VodView: View {
  @State private var showPlayer: Bool = false
  @State private var selectedStreamURL: URL? = nil
  @State private var showErrorAlert: Bool = false
  @State private var errorMessage: String = ""

  @State var progress: Double = 0.0
  @State var isLoading: Bool = false
  @State private var selectedCategoryId: String?

  private let kindMedia: KindMedia
  @ObservedResults(CategoryEntity.self, where: ({ $0.section == KindMedia.vod.rawValue })) var categories
  @ObservedResults(CachedStream.self, where: ({ $0.section == KindMedia.vod.rawValue }), sortDescriptor: SortDescriptor(keyPath: "added", ascending: false)) var movies

  private var visibleCategories: [CategoryEntity] {
    guard let selectedCategoryId else {
      return Array(categories)
    }

    return categories.filter { $0.id == selectedCategoryId }
  }

  private var featuredMovie: CachedStream? {
    movies.first
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
                currentID = featuredMovie.id
                selectedStreamURL = URL(string: featuredMovie.streamURL())
                showPlayer = true
              }
            }
            .padding(.horizontal, -16)
            .padding(.top, -8)

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
      .fullScreenCover(isPresented: Binding(get: {
        showPlayer && selectedStreamURL != nil
      }, set: { showPlayer = $0 })) {
        if let streamURL = selectedStreamURL {
          ViewPlayerContent(mediaURL: streamURL, id: currentID, kind: .vod)
            .ignoresSafeArea()
        }
      }
    }
  }

  @State private var currentID: Int = 9999

  @ViewBuilder
  private func makeSectionFavori() -> some View {
    Section {
      FavoriMovieShelf(kindMedia: kindMedia) { stream in
        currentID = stream.id
        selectedStreamURL = URL(string: stream.streamURL())
        showPlayer = true
      }
    }
  }

  @ViewBuilder
  private func makeSection(for category: CategoryEntity) -> some View {
    Section {
      MovieShelf(category: category, kindMedia: kindMedia) { stream in
        currentID = stream.id
        selectedStreamURL = URL(string: stream.streamURL())
        showPlayer = true
      }
    }
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
