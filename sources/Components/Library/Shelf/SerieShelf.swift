//
//  SerieShelf.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 11/11/2024.
//

import IPTVModels
import RealmSwift
import SwiftUI

public struct SerieShelf: View {
  @Namespace var mainNamespace
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let ratio: CGFloat = 250 / 375
  private var column: Int {
    horizontalSizeClass == .compact ? 2 : 6
  }

  public var category: CategoryEntity
  public var kindMedia: KindMedia
  @State private var addToFavori: Bool = false

  var openStream: (CachedSeries) -> Void
  @ObservedResults(CachedSeries.self) var streams: Results<CachedSeries>

  public var categoryId: String = "-1"

  public init(category: CategoryEntity, kindMedia: KindMedia, openStream: @escaping (CachedSeries) -> Void) {
    self.category = category
    self.kindMedia = kindMedia
    self.openStream = openStream
    self.categoryId = category.id
  }

  var filteredStreams: Results<CachedSeries> {
    streams.where { $0.section == kindMedia.rawValue && $0.categoryID == categoryId }
      .sorted(by: \.lastModified, ascending: false)
  }

  private var displayStreams: [CachedSeries] {
    Array(filteredStreams.prefix(50))
  }

  public var body: some View {
    Group {
      if !displayStreams.isEmpty {
        VStack {
          sectionHeader()
          ScrollView(.horizontal) {
            LazyHStack(spacing: 16) {
              ForEach(displayStreams) { serie in
                customButton(serie)
              }
            }
          }
          .scrollClipDisabled()
          .buttonStyle(.borderless)
        }
      }
    }
    .toast(isPresenting: $addToFavori, duration: 3) {
      AlertToast(type: .regular, title: "Added to favorites")
    }
  }

  @ViewBuilder
  private func customButton(_ serie: CachedSeries) -> some View {
    CustomButton(action: {
      openStream(serie)
    }, longPressAction: {
      Task {
        await toggleFavori(serie: serie)
      }
    }) {
      ZStack(alignment: .bottom) {
        if let imageUrl = serie.getImage(), let url = URL(string: imageUrl) {
          Thumbnail(imageUrl: url, ratio: ratio, column: column)
        } else {
          placeholder()
        }

        Text(serie.name.formatted())
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .foregroundStyle(.white)
          .font(.system(size: 14))
          .frame(maxWidth: .infinity, maxHeight: 64)
          .background(Color.black.opacity(0.5))
      }
      .aspectRatio(ratio, contentMode: .fit)
      .containerRelativeFrame(.horizontal, count: column, spacing: 40)
    }
    .contextMenu {
      let favorited = isFavorited(serie)
      Button(role: favorited ? .destructive : nil) {
        Task { await toggleFavori(serie: serie) }
      } label: {
        Label(
          favorited ? "Remove from Favorites" : "Add to Favorites",
          systemImage: favorited ? "star.slash" : "star"
        )
      }
    }
#if TARGET_OS_TV
    .prefersDefaultFocus(in: mainNamespace)
#endif
    .id(serie.id)
  }

  @ViewBuilder
  private func sectionHeader() -> some View {
    HStack {
      Text(category.name.formatted())
        .lineLimit(4)
        .multilineTextAlignment(.center)
        .font(.system(size: 23, weight: .bold))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private func placeholder() -> some View {
    Rectangle()
      .foregroundColor(.black)
      .opacity(0.2)
      .aspectRatio(ratio, contentMode: .fit)
      .containerRelativeFrame(.horizontal, count: column, spacing: 40)
  }

  private func isFavorited(_ serie: CachedSeries) -> Bool {
    guard let realm = try? Realm() else { return false }
    return !realm.objects(FavoriEntity.self)
      .where { $0.id == serie.id && $0.kind == kindMedia.rawValue }
      .isEmpty
  }

  @MainActor
  private func toggleFavori(serie: CachedSeries) async {
    do {
      let realm = try await Realm()
      let existing = realm.objects(FavoriEntity.self)
        .where { $0.id == serie.id && $0.kind == kindMedia.rawValue }
      try realm.write {
        if existing.isEmpty {
          realm.add(FavoriEntity(
            id: serie.id,
            kind: kindMedia.rawValue,
            name: serie.name,
            streamIcon: serie.cover,
            added: Date(),
            tmdb: serie.tmdb
          ))
        } else {
          realm.delete(existing)
        }
      }
      addToFavori = existing.isEmpty
    } catch {
      print("Erreur lors de la sauvegarde dans SwiftData: \(error)")
    }
  }
}
