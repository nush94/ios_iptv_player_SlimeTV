//
//  LiveView.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 10/11/2024.
//

import IPTVComponents
import IPTVModels
import RealmSwift
import SwiftUI

public struct LiveView: View {
  @ObservedObject var useCase: LiveUseCase
  @State private var belowFold = false
  private var showcaseHeight: CGFloat = 800

  @State private var selectedCategoryId: String?
  @State private var showPlayer: Bool = false
  @State private var selectedStreamURL: URL? = nil

  @State private var showErrorAlert: Bool = false
  @State private var errorMessage: String = ""

  public var kindMedia: KindMedia

  @ObservedResults(CategoryEntity.self, where: ({ $0.section == KindMedia.live.rawValue })) var categories
  @ObservedResults(CachedStream.self, where: ({ $0.section == KindMedia.live.rawValue })) var channels

  private var visibleCategories: [CategoryEntity] {
    guard let selectedCategoryId else {
      return Array(categories)
    }

    return categories.filter { $0.id == selectedCategoryId }
  }

  public init(kindMedia: KindMedia) {
    self.kindMedia = kindMedia
    self.useCase = LiveUseCase(
      kindMedia: kindMedia,
      apiManager: APIManager.shared,
      cacheManager: CacheManager.shared
    )
  }

  public var body: some View {
    NavigationStack {
      ScrollView(.vertical) {
        LazyVStack(alignment: .leading, spacing: 24) {
          if categories.count == 0 || channels.count == 0 {
            LibraryEmptyStateView(
              systemImage: "sparkles.tv",
              title: categories.count == 0 ? "No live categories yet" : "No channels loaded yet",
              message: "Add your Xtream playlist in Settings, then tap Save & Load Playlist."
            )
            .padding(.top, 48)
          } else {
            makeSectionFavori()

            ForEach(visibleCategories, id: \.id) { category in
              makeSection(for: category)
            }
            .frame(maxWidth: .infinity)
          }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
      }
      .background(alignment: .top) {
        HeroHeaderView(belowFold: true)
      }
      .frame(maxHeight: .infinity, alignment: .top)
      .alert("Error", isPresented: $useCase.showErrorAlert) {
        Button("OK", role: .cancel) {
        }
      } message: {
        Text(errorMessage)
      }
      .fullScreenCover(isPresented: Binding(get: {
        showPlayer && selectedStreamURL != nil
      }, set: { showPlayer = $0 })) {
        GeometryReader { _ in
          ViewPlayerContent(mediaURL: selectedStreamURL!, id: currentID, kind: .live)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        }
      }
    }
  }

  @State private var currentID: Int = 9999

  @ViewBuilder
  private func makeSectionFavori() -> some View {
    Section {
      FavoriLiveShelf(kindMedia: kindMedia) { stream in
        currentID = stream.id
        selectedStreamURL = URL(string: stream.streamURL())
        showPlayer = true
      }
    }
  }

  @ViewBuilder
  func makeSection(for category: CategoryEntity) -> some View {
    Section {
      LiveShelf(category: category, kindMedia: kindMedia) { stream in
        currentID = stream.id
        selectedStreamURL = URL(string: stream.streamURL())
        showPlayer = true
      }
    }
    .id(category.id)
  }
}
