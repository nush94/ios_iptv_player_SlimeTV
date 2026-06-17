//
//  FeaturedMovieHeroView.swift
//  IPTV
//

import IPTVModels
import SwiftUI

struct FeaturedMovieHeroView: View {
  let movie: CachedStream?
  let playAction: () -> Void

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .bottom) {
        heroImage
          .frame(width: proxy.size.width, height: proxy.size.height)
          .clipped()

        LinearGradient(
          colors: [.clear, .black.opacity(0.48), .black.opacity(0.96)],
          startPoint: .top,
          endPoint: .bottom
        )

        VStack(spacing: 16) {
          Spacer()

          Text(movie?.name.formatted() ?? "Your Movie Library")
            .font(.system(size: 38, weight: .heavy))
            .minimumScaleFactor(0.58)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .frame(width: max(proxy.size.width - 40, 1))
            .shadow(color: .black.opacity(0.55), radius: 12, x: 0, y: 4)

          HStack(spacing: 8) {
            if let year = movie?.year, year > 0 {
              Text("\(year)")
            }

            if let rating = movie?.rating, !rating.isEmpty {
              Text("•")
              Text(rating)
            }

            Text("•")
            Text("Movie")
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white.opacity(0.82))
          .frame(width: max(proxy.size.width - 40, 1))

          HStack(spacing: 22) {
            heroIconButton(title: "Favorites", systemImage: "star")

            Button(action: playAction) {
              HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("Play")
              }
              .font(.title3.weight(.bold))
              .foregroundStyle(.black)
              .padding(.horizontal, 28)
              .frame(height: 48)
              .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(movie == nil)
            .opacity(movie == nil ? 0.45 : 1)

            heroIconButton(title: "Info", systemImage: "info.circle")
          }
          .frame(width: max(proxy.size.width - 40, 1))
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
        .padding(.bottom, 24)
      }
    }
    .frame(height: 500)
    .frame(maxWidth: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: 0))
  }

  @ViewBuilder
  private var heroImage: some View {
    if let imageUrl = movie?.getImage(), let url = URL(string: imageUrl) {
      AsyncImage(url: url, placeholder: {
        fallbackHero
      }, content: { image in
        image
          .resizable()
          .scaledToFill()
      })
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()
    } else {
      fallbackHero
    }
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

  private func heroIconButton(title: String, systemImage: String) -> some View {
    Button {
    } label: {
      VStack(spacing: 5) {
        Image(systemName: systemImage)
          .font(.system(size: 30, weight: .regular))
        Text(title)
          .font(.footnote.weight(.medium))
      }
      .foregroundStyle(.white)
      .frame(width: 78)
    }
    .buttonStyle(.plain)
  }
}
