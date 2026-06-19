//
//  ContinueWatchingShelf.swift
//  IPTV
//

import IPTVModels
import SwiftUI

struct ContinueWatchingShelf: View {
  let title: String
  let items: [CachedPlaybackProgress]
  let openItem: (CachedPlaybackProgress) -> Void

  var body: some View {
    if !items.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        Text(title)
          .font(.system(size: 23, weight: .bold))
          .foregroundStyle(.white)

        ScrollView(.horizontal, showsIndicators: false) {
          LazyHStack(spacing: 14) {
            ForEach(items) { item in
              Button {
                openItem(item)
              } label: {
                ContinueWatchingCard(item: item)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.trailing, 4)
        }
        .scrollClipDisabled()
      }
    }
  }
}

private struct ContinueWatchingCard: View {
  let item: CachedPlaybackProgress

  private var isSeries: Bool {
    item.kind == KindMedia.series.rawValue
  }

  private var cardSize: CGSize {
    isSeries ? CGSize(width: 190, height: 108) : CGSize(width: 132, height: 198)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ZStack(alignment: .bottomLeading) {
        artwork
          .frame(width: cardSize.width, height: cardSize.height)
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 5) {
            Image(systemName: "play.fill")
              .font(.system(size: 9, weight: .bold))
            Text("Resume")
              .font(.caption2.weight(.bold))
          }
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .background(.black.opacity(0.58), in: Capsule())

          progressBar
        }
        .padding(8)
      }

      Text(item.title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.white)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .frame(width: cardSize.width, alignment: .leading)

      if let subtitle = item.subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .font(.caption.weight(.medium))
          .foregroundStyle(.white.opacity(0.56))
          .lineLimit(1)
          .frame(width: cardSize.width, alignment: .leading)
      }
    }
    .frame(width: cardSize.width, alignment: .leading)
  }

  @ViewBuilder
  private var artwork: some View {
    if let imageURL = item.imageURL, let url = URL(string: imageURL) {
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
      LinearGradient(
        colors: [.white.opacity(0.14), .white.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      Image(systemName: isSeries ? "rectangle.stack" : "film")
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(.white.opacity(0.58))
    }
  }

  private var progressBar: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(.white.opacity(0.22))

        Capsule()
          .fill(.red)
          .frame(width: proxy.size.width * CGFloat(item.percentComplete))
      }
    }
    .frame(width: cardSize.width - 16, height: 4)
  }
}
