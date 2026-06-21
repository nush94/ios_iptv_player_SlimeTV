//
//  FeaturedMovieHeroView.swift
//  IPTV
//

import IPTVModels
import RealmSwift
import SwiftUI

struct FeaturedMovieHeroView: View {
  let movie: CachedStream?
  let playAction: () -> Void

  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @ObservedResults(FavoriEntity.self) private var favorites
  @State private var showInfo = false

  private var isCompactHeight: Bool { verticalSizeClass == .compact }
  private var heroHeight: CGFloat { isCompactHeight ? 260 : 340 }
  private var titleSize: CGFloat { isCompactHeight ? 28 : 34 }

  private var isFavorite: Bool {
    guard let movie else { return false }
    return favorites.contains { $0.id == movie.id && $0.kind == KindMedia.vod.rawValue }
  }

  @MainActor
  private func toggleFavorite() {
    guard let movie else { return }
    do {
      let realm = try Realm()
      let existing = realm.objects(FavoriEntity.self)
        .where { $0.id == movie.id && $0.kind == KindMedia.vod.rawValue }
      try realm.write {
        if existing.isEmpty {
          realm.add(FavoriEntity(
            id: movie.id,
            kind: KindMedia.vod.rawValue,
            name: movie.name,
            streamIcon: movie.streamIcon,
            added: Date(),
            tmdb: movie.tmdb
          ))
        } else {
          realm.delete(existing)
        }
      }
    } catch {
      print("Favorite toggle failed: \(error)")
    }
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        heroImage
          .frame(width: proxy.size.width, height: proxy.size.height)
          .clipped()

        LinearGradient(
          colors: [.black.opacity(0.88), .black.opacity(0.58), .black.opacity(0.1)],
          startPoint: .leading,
          endPoint: .trailing
        )

        LinearGradient(
          colors: [.black.opacity(0.02), .black.opacity(0.55)],
          startPoint: .top,
          endPoint: .bottom
        )

        VStack(alignment: .leading, spacing: 12) {
          Text(movie?.name.formatted() ?? "Your Movie Library")
            .font(.system(size: titleSize, weight: .heavy))
            .minimumScaleFactor(0.58)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .foregroundStyle(.white)
            .frame(width: max(proxy.size.width * 0.58, 1), alignment: .leading)
            .shadow(color: .black.opacity(0.55), radius: 12, x: 0, y: 4)

          HStack(spacing: 8) {
            if let year = movie?.year, year > 0 {
              Text(verbatim: "\(year)")
            }

            if let rating = movie?.rating, !rating.isEmpty {
              Text("•")
              Text(rating)
            }

            Text("•")
            Text("4K")
          }
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.82))
          .frame(width: max(proxy.size.width * 0.62, 1), alignment: .leading)

          Text(heroDescription)
            .font(.system(size: 13, weight: .medium))
            .lineSpacing(3)
            .foregroundStyle(.white.opacity(0.76))
            .lineLimit(4)
            .frame(width: max(proxy.size.width * 0.58, 1), alignment: .leading)

          HStack(spacing: 18) {
            Button(action: playAction) {
              HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("Play")
              }
              .font(.system(size: 17, weight: .bold))
              .foregroundStyle(.white)
              .frame(width: 118, height: 48)
              .background(Color.red, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(movie == nil)
            .opacity(movie == nil ? 0.45 : 1)

            heroIconButton(
              title: "Favorite",
              systemImage: isFavorite ? "star.fill" : "star",
              tint: isFavorite ? .yellow : .white,
              action: toggleFavorite
            )
            .disabled(movie == nil)
            .opacity(movie == nil ? 0.45 : 1)

            heroIconButton(title: "Info", systemImage: "info.circle", action: {
              if movie != nil { showInfo = true }
            })
            .disabled(movie == nil)
            .opacity(movie == nil ? 0.45 : 1)
          }
          .frame(width: max(proxy.size.width - 40, 1), alignment: .leading)
        }
        .padding(20)
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
      }
    }
    .frame(height: heroHeight)
    .frame(maxWidth: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(.white.opacity(0.12), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    .sheet(isPresented: $showInfo) {
      if let movie {
        MovieInfoView(movie: movie)
      }
    }
  }

  @ViewBuilder
  private var heroImage: some View {
    MovieArtworkView(stream: movie, preferBackdrop: true) {
      fallbackHero
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
  }

  private var fallbackHero: some View {
    ZStack {
      Image("beach_landscape")
        .resizable()
        .scaledToFill()

      LinearGradient(
        colors: [.red.opacity(0.28), .black.opacity(0.15)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
  }

  private var heroDescription: String {
    if let desc = movie?.desc, !desc.isEmpty {
      return desc
    }
    return "Open details to read more, watch the trailer, and choose when to start playing."
  }

  private func heroIconButton(
    title: String,
    systemImage: String,
    tint: Color = .white,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 5) {
        Image(systemName: systemImage)
          .font(.system(size: 23, weight: .regular))
          .foregroundStyle(tint)
          .frame(width: 42, height: 42)
          .background(.black.opacity(0.34), in: Circle())
          .overlay {
            Circle()
              .stroke(.white.opacity(0.22), lineWidth: 1)
          }
        Text(title)
          .font(.caption2.weight(.medium))
          .foregroundStyle(.white)
      }
      .frame(width: 62)
    }
    .buttonStyle(.plain)
  }
}
