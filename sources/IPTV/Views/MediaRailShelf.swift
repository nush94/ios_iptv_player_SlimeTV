//
//  MediaRailShelf.swift
//  IPTV
//
//  A reusable horizontal "rail" of poster cards for the Home screen
//  (Recently Added, Trending, Because you watched, …).
//

import IPTVModels
import RealmSwift
import SwiftUI

struct MediaRailShelf: View {
  let title: String
  let streams: [CachedStream]
  var kindMedia: KindMedia = .vod
  let onTap: (CachedStream) -> Void

  private let cardWidth: CGFloat = 116
  private let posterRatio: CGFloat = 250.0 / 375.0 // width / height
  private var displayStreams: [CachedStream] {
    Array(streams.prefix(30))
  }

  var body: some View {
    if !displayStreams.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        Text(title)
          .font(.system(size: 21, weight: .bold))
          .foregroundStyle(.white)
          .lineLimit(1)

        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: 12) {
            ForEach(displayStreams, id: \.id) { stream in
              Button {
                onTap(stream)
              } label: {
                card(stream)
              }
              .buttonStyle(.plain)
              .contextMenu {
                let favorited = isFavorited(stream)
                Button(role: favorited ? .destructive : nil) {
                  Task { await toggleFavori(stream) }
                } label: {
                  Label(
                    favorited ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: favorited ? "star.slash" : "star"
                  )
                }
              }
            }
          }
          .padding(.vertical, 1)
        }
        .scrollClipDisabled()
      }
    }
  }

  private func card(_ stream: CachedStream) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      poster(stream)
        .frame(width: cardWidth, height: cardWidth / posterRatio)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(.white.opacity(0.08), lineWidth: 1)
        }

      Text(stream.name.formatted())
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white.opacity(0.82))
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .frame(width: cardWidth, alignment: .leading)
    }
  }

  @ViewBuilder
  private func poster(_ stream: CachedStream) -> some View {
    if let path = stream.getImage(), !path.isEmpty, let url = URL(string: path) {
      AsyncImage(url: url, placeholder: {
        placeholder
      }, content: { image in
        image.resizable().scaledToFill()
      })
    } else {
      placeholder
    }
  }

  private var placeholder: some View {
    ZStack {
      Color.white.opacity(0.06)
      Image(systemName: "film")
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.white.opacity(0.45))
    }
  }

  // MARK: - Favorites (hold to add/remove, consistent with the rest of the app)

  private func isFavorited(_ stream: CachedStream) -> Bool {
    guard let realm = try? Realm() else { return false }
    return !realm.objects(FavoriEntity.self)
      .where { $0.id == stream.id && $0.kind == kindMedia.rawValue }
      .isEmpty
  }

  @MainActor
  private func toggleFavori(_ stream: CachedStream) async {
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
    } catch {
      print("Favorite toggle failed: \(error)")
    }
  }
}
