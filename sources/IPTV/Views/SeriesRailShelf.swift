//
//  SeriesRailShelf.swift
//  IPTV
//
//  Horizontal rail of show posters, used for genre-based Shows browsing.
//

import IPTVModels
import Foundation
import RealmSwift
import SwiftUI

struct SeriesRailShelf: View {
  let title: String
  let series: [CachedSeries]
  let onTap: (CachedSeries) -> Void

  private let cardWidth: CGFloat = 116
  private let posterRatio: CGFloat = 250.0 / 375.0
  private var displaySeries: [CachedSeries] {
    Array(series.prefix(30))
  }

  var body: some View {
    if !displaySeries.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        Text(title)
          .font(.system(size: 21, weight: .bold))
          .foregroundStyle(.white)
          .lineLimit(1)

        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: 12) {
            ForEach(displaySeries, id: \.id) { serie in
              Button {
                onTap(serie)
              } label: {
                card(serie)
              }
              .buttonStyle(.plain)
              .contextMenu {
                let favorited = isFavorited(serie)
                Button(role: favorited ? .destructive : nil) {
                  Task { await toggleFavori(serie) }
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

  private func card(_ serie: CachedSeries) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      poster(serie)
        .frame(width: cardWidth, height: cardWidth / posterRatio)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
          if let rating = ratingText(serie) {
            metadataBadge(systemImage: "star.fill", text: rating)
              .padding(6)
          }
        }
        .overlay(alignment: .topTrailing) {
          if let year = yearText(serie) {
            metadataBadge(systemImage: nil, text: year)
              .padding(6)
          }
        }

      Text(serie.name.formatted())
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white.opacity(0.82))
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .frame(width: cardWidth, alignment: .leading)
    }
  }

  @ViewBuilder
  private func poster(_ serie: CachedSeries) -> some View {
    if let path = serie.getImage(), !path.isEmpty, let url = URL(string: path) {
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
      Image(systemName: "play.tv")
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.white.opacity(0.45))
    }
  }

  private func ratingText(_ serie: CachedSeries) -> String? {
    let rating = serie.rating ?? serie.rating5Based ?? 0
    guard rating > 0 else { return nil }
    return String(format: "%.1f", rating)
  }

  private func yearText(_ serie: CachedSeries) -> String? {
    if let year = StreamYearExtractor.year(from: serie.releaseDate) {
      return "\(year)"
    }
    if let year = StreamYearExtractor.year(from: serie.name) {
      return "\(year)"
    }

    let year = Calendar.current.component(.year, from: serie.lastModified)
    return year > 1900 ? "\(year)" : nil
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

  private func isFavorited(_ serie: CachedSeries) -> Bool {
    guard let realm = try? Realm() else { return false }
    return !realm.objects(FavoriEntity.self)
      .where { $0.id == serie.id && $0.kind == KindMedia.series.rawValue }
      .isEmpty
  }

  @MainActor
  private func toggleFavori(_ serie: CachedSeries) async {
    do {
      let realm = try await Realm()
      let existing = realm.objects(FavoriEntity.self)
        .where { $0.id == serie.id && $0.kind == KindMedia.series.rawValue }
      try realm.write {
        if existing.isEmpty {
          realm.add(FavoriEntity(
            id: serie.id,
            kind: KindMedia.series.rawValue,
            name: serie.name,
            streamIcon: serie.cover,
            added: Date(),
            tmdb: serie.tmdb
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
