//
//  MovieShelf.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 11/11/2024.
//

import IPTVModels
import RealmSwift
import SwiftUI

public struct MovieShelf: View {
  @Namespace var mainNamespace
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private let ratio: CGFloat = 250 / 375
  private var column: Int {
    horizontalSizeClass == .compact ? 2 : 6
  }

  public var category: CategoryEntity
  public var kindMedia: KindMedia
  public var categoryId: String = "-1"
  @State private var addToFavori: Bool = false

  var openStream: (CachedStream) -> Void
  @ObservedResults(CachedStream.self) var streams: Results<CachedStream>

  var filteredStreams: Results<CachedStream> {
    streams.where { $0.section == kindMedia.rawValue && $0.categoryId == categoryId }
      .sorted(by: \.year, ascending: false)
  }

  private var displayStreams: [CachedStream] {
    Array(filteredStreams.prefix(50))
  }

  public init(category: CategoryEntity, kindMedia: KindMedia, openStream: @escaping (CachedStream) -> Void) {
    self.category = category
    self.kindMedia = kindMedia
    self.openStream = openStream
    self.categoryId = category.id
  }

  private func isFavorited(_ stream: CachedStream) -> Bool {
    guard let realm = try? Realm() else { return false }
    return !realm.objects(FavoriEntity.self)
      .where { $0.id == stream.id && $0.kind == kindMedia.rawValue }
      .isEmpty
  }

  @MainActor
  private func toggleFavori(stream: CachedStream) async {
    do {
      let realm = try await Realm()
      let existing = realm.objects(FavoriEntity.self)
        .where { $0.id == stream.id && $0.kind == kindMedia.rawValue }
      try realm.write {
        if existing.isEmpty {
          realm.add(FavoriEntity(
            id: stream.id,
            kind: kindMedia.rawValue,
            name: stream.name,
            streamIcon: stream.streamIcon,
            added: Date(),
            tmdb: stream.tmdb
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

  public var body: some View {
    Group {
      if !displayStreams.isEmpty {
        VStack {
          sectionHeader()
          ScrollView(.horizontal) {
            LazyHStack(spacing: 16) {
              ForEach(displayStreams) { stream in
                CustomButton(
                  action: {
                    DispatchQueue.main.async {
                      openStream(stream)
                    }
                  }, longPressAction: {
                    Task {
                      await toggleFavori(stream: stream)
                    }
                  }
                ) {
                  ZStack(alignment: .bottom) {
                    if let imageUrl = stream.getImage(), let url = URL(string: imageUrl) {
                      Thumbnail(imageUrl: url, ratio: ratio, column: column)
                    } else {
                      placeholder()
                    }

                    Text(stream.name.formatted())
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
                  let favorited = isFavorited(stream)
                  Button(role: favorited ? .destructive : nil) {
                    Task { await toggleFavori(stream: stream) }
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

                .id(stream.id)
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
}
