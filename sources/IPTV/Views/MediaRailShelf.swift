//
//  MediaRailShelf.swift
//  IPTV
//
//  A reusable horizontal "rail" of poster cards for the Home screen
//  (Recently Added, Trending, Because you watched, …).
//

import IPTVModels
import Foundation
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
        .overlay(alignment: .topLeading) {
          if let rating = ratingText(stream) {
            metadataBadge(systemImage: "star.fill", text: rating)
              .padding(6)
          }
        }
        .overlay(alignment: .topTrailing) {
          if let year = yearText(stream) {
            metadataBadge(systemImage: nil, text: year)
              .padding(6)
          }
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
    MovieArtworkView(stream: stream, preferBackdrop: false) {
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

  private func ratingText(_ stream: CachedStream) -> String? {
    guard let rating = Double(stream.rating ?? ""), rating > 0 else { return nil }
    return String(format: "%.1f", rating)
  }

  private func yearText(_ stream: CachedStream) -> String? {
    if let year = stream.year, year > 0 {
      return "\(year)"
    }
    if let year = StreamYearExtractor.year(from: stream.name) {
      return "\(year)"
    }
    return nil
  }

  private func metadataBadge(systemImage: String?, text: String) -> some View {
    HStack(spacing: 3) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(.system(size: 8, weight: .black))
      }
      Text(text)
        .font(.system(size: 9, weight: .heavy))
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 6)
    .frame(height: 18)
    .background(.black.opacity(0.64), in: Capsule())
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

struct MovieArtworkView<Placeholder: View>: View {
  let stream: CachedStream?
  var preferBackdrop = false
  @ViewBuilder let placeholder: () -> Placeholder

  @State private var fetchedPosterPath: String?
  @State private var fetchedBackdropPath: String?

  private var preferredPath: String? {
    if preferBackdrop {
      return clean(fetchedBackdropPath) ?? clean(stream?.tmdbImage) ?? clean(fetchedPosterPath) ?? clean(stream?.streamIcon)
    }
    return clean(stream?.tmdbImage) ?? clean(fetchedPosterPath) ?? clean(stream?.streamIcon) ?? clean(fetchedBackdropPath)
  }

  var body: some View {
    Group {
      if let url = imageURL {
        AsyncImage(url: url, placeholder: {
          placeholder()
        }, content: { image in
          image.resizable().scaledToFill()
        })
      } else {
        placeholder()
      }
    }
    .task(id: stream?.id) {
      await fetchBetterArtworkIfNeeded()
    }
  }

  private var imageURL: URL? {
    guard let preferredPath else { return nil }
    if let url = URL(string: preferredPath) {
      return url
    }
    return URL(string: preferredPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
  }

  private func fetchBetterArtworkIfNeeded() async {
    guard let stream,
          stream.kindMedia == .vod,
          fetchedPosterPath == nil,
          fetchedBackdropPath == nil,
          clean(stream.tmdbImage) == nil
    else {
      return
    }

    guard let info = try? await APIManager.shared.fetchVodInfo(streamId: stream.id) else {
      return
    }

    await MainActor.run {
      fetchedPosterPath = clean(info.poster)
      fetchedBackdropPath = clean(info.backdrop)
    }

    if let poster = clean(info.poster) {
      await cachePoster(poster, for: stream.id)
    }
  }

  @MainActor
  private func cachePoster(_ poster: String, for streamId: Int) async {
    guard let realm = try? await Realm(),
          let movie = realm.objects(CachedStream.self).where({ $0.id == streamId }).first,
          clean(movie.tmdbImage) == nil
    else {
      return
    }

    try? realm.write {
      movie.tmdbImage = poster
    }
  }

  private func clean(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty
    else {
      return nil
    }
    return value
  }
}
