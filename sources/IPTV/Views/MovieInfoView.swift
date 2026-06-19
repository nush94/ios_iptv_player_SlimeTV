//
//  MovieInfoView.swift
//  IPTV
//
//  Detailed info sheet for a VOD movie, sourced from the Xtream
//  `get_vod_info` endpoint (plot, cast, genre, duration, rating, …).
//

import IPTVModels
import RealmSwift
import SwiftUI

/// Lightweight, tolerant model for the Xtream `get_vod_info` `info` object.
/// IPTV payloads are messy (mixed types, missing keys), so we map from a
/// plain dictionary rather than relying on strict Decodable.
struct VodInfo {
  let plot: String?
  let cast: String?
  let director: String?
  let genre: String?
  let releaseDate: String?
  let duration: String?
  let durationSecs: Int?
  let rating: String?
  let country: String?
  let backdrop: String?
  let poster: String?
  let youtubeTrailer: String?

  init(from dict: [String: Any]) {
    func string(_ keys: String...) -> String? {
      for key in keys {
        if let value = dict[key] as? String, !value.isEmpty { return value }
        if let number = dict[key] as? NSNumber { return number.stringValue }
      }
      return nil
    }

    plot = string("plot", "description")
    cast = string("cast", "actors")
    director = string("director")
    genre = string("genre")
    releaseDate = string("releasedate", "release_date")
    duration = string("duration")
    rating = string("rating")
    country = string("country")
    poster = string("movie_image", "cover_big")
    youtubeTrailer = string("youtube_trailer", "youtubeTrailer", "trailer")

    if let secs = dict["duration_secs"] as? NSNumber {
      durationSecs = secs.intValue
    } else if let secsString = dict["duration_secs"] as? String {
      durationSecs = Int(secsString)
    } else {
      durationSecs = nil
    }

    if let array = dict["backdrop_path"] as? [String], let first = array.first {
      backdrop = first
    } else {
      backdrop = string("backdrop_path")
    }
  }

  var year: String? {
    guard let releaseDate, releaseDate.count >= 4 else { return nil }
    return String(releaseDate.prefix(4))
  }

  var runtimeText: String? {
    if let durationSecs, durationSecs > 0 {
      let minutes = durationSecs / 60
      let hours = minutes / 60
      let mins = minutes % 60
      return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }
    if let duration, !duration.isEmpty { return duration }
    return nil
  }

  var genres: [String] {
    (genre ?? "")
      .split(whereSeparator: { $0 == "," || $0 == "/" })
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  var castMembers: [String] {
    (cast ?? "")
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }
}

struct MovieInfoView: View {
  let movie: CachedStream

  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @ObservedResults(CachedPlaybackProgress.self, where: ({ $0.kind == KindMedia.vod.rawValue })) private var progressItems
  @State private var info: VodInfo?
  @State private var isLoading = true
  @State private var showPlayer = false

  private var trailerURL: URL? {
    TrailerLink.url(from: info?.youtubeTrailer)
  }

  private var movieProgress: CachedPlaybackProgress? {
    progressItems.first { $0.mediaId == movie.id }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        backdrop
        VStack(alignment: .leading, spacing: 20) {
          title
          metadataRow
          actionButtons
          progressSection
          plotSection
          castSection
          detailRows
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
      }
    }
    .background(Color.black.ignoresSafeArea())
    .preferredColorScheme(.dark)
    .overlay(alignment: .topTrailing) { closeButton }
    .task { await load() }
    .fullScreenCover(isPresented: $showPlayer) {
      if let url = URL(string: movie.streamURL()) {
        ViewPlayerContent(
          mediaURL: url,
          id: movie.id,
          kind: .vod,
          playbackContext: playbackContext
        )
          .ignoresSafeArea()
      }
    }
  }

  // MARK: - Sections

  private var backdrop: some View {
    ZStack(alignment: .bottom) {
      backdropImage
        .frame(height: 240)
        .frame(maxWidth: .infinity)
        .clipped()

      LinearGradient(
        colors: [.clear, .black.opacity(0.5), .black],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 240)
    }
  }

  @ViewBuilder
  private var backdropImage: some View {
    let path = info?.backdrop ?? info?.poster ?? movie.getImage()
    if let path, !path.isEmpty, let url = URL(string: path) {
      AsyncImage(url: url, placeholder: {
        Color.white.opacity(0.06)
      }, content: { image in
        image.resizable().scaledToFill()
      })
    } else {
      Color.white.opacity(0.06)
    }
  }

  private var title: some View {
    Text(movie.name.formatted())
      .font(.system(size: 26, weight: .heavy))
      .foregroundStyle(.white)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var metadataRow: some View {
    HStack(spacing: 8) {
      if let ratingText {
        HStack(spacing: 4) {
          Image(systemName: "star.fill")
            .font(.system(size: 12))
            .foregroundStyle(.yellow)
          Text(ratingText)
        }

        if !metadataParts.isEmpty {
          Text("•").foregroundStyle(.white.opacity(0.4))
        }
      }

      ForEach(Array(metadataParts.enumerated()), id: \.offset) { index, part in
        if index > 0 {
          Text("•").foregroundStyle(.white.opacity(0.4))
        }
        Text(part)
      }
    }
    .font(.subheadline.weight(.semibold))
    .foregroundStyle(.white.opacity(0.82))
  }

  private var ratingText: String? {
    if let rating = info?.rating, !rating.isEmpty { return rating }
    if let rating = movie.rating, !rating.isEmpty { return rating }
    return nil
  }

  private var metadataParts: [String] {
    var parts: [String] = []
    if let year = info?.year ?? movie.year.flatMap({ $0 > 0 ? String($0) : nil }) {
      parts.append(year)
    }
    if let runtime = info?.runtimeText {
      parts.append(runtime)
    }
    if let firstGenre = info?.genres.first {
      parts.append(firstGenre)
    }
    return parts
  }

  private var playButton: some View {
    Button {
      showPlayer = true
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "play.fill")
        Text(movieProgress == nil ? "Play" : "Resume")
      }
      .font(.system(size: 17, weight: .bold))
      .foregroundStyle(.black)
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var actionButtons: some View {
    HStack(spacing: 10) {
      playButton

      if trailerURL != nil {
        trailerButton
      }
    }
  }

  private var trailerButton: some View {
    Button(action: openTrailer) {
      HStack(spacing: 8) {
        Image(systemName: "play.rectangle.fill")
        Text("Trailer")
      }
      .font(.system(size: 17, weight: .bold))
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var progressSection: some View {
    if let movieProgress {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Continue Watching")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.52))
          Spacer()
          Text("\(Int(movieProgress.percentComplete * 100))%")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.62))
        }

        DetailProgressBar(progress: movieProgress.percentComplete)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(.white.opacity(0.08), lineWidth: 1)
      }
    }
  }

  private var playbackContext: PlaybackProgressContext {
    PlaybackProgressContext(
      mediaId: movie.id,
      kind: .vod,
      title: movie.name.formatted(),
      subtitle: metadataParts.first,
      imageURL: info?.poster ?? movie.tmdbImage ?? movie.streamIcon,
      streamURL: movie.streamURL()
    )
  }

  @ViewBuilder
  private var plotSection: some View {
    if isLoading, info == nil {
      ProgressView()
        .tint(.white)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    } else if let plot = info?.plot, !plot.isEmpty {
      Text(plot)
        .font(.callout)
        .foregroundStyle(.white.opacity(0.82))
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder
  private var castSection: some View {
    let members = info?.castMembers ?? []
    if !members.isEmpty {
      detailRow(label: "Cast", value: members.prefix(6).joined(separator: ", "))
    }
  }

  @ViewBuilder
  private var detailRows: some View {
    if let director = info?.director, !director.isEmpty {
      detailRow(label: "Director", value: director)
    }
    if !(info?.genres.isEmpty ?? true) {
      detailRow(label: "Genres", value: info!.genres.joined(separator: ", "))
    }
    if let country = info?.country, !country.isEmpty {
      detailRow(label: "Country", value: country)
    }
  }

  private func detailRow(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(label.uppercased())
        .font(.caption2.weight(.bold))
        .foregroundStyle(.white.opacity(0.45))
      Text(value)
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.85))
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var closeButton: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "xmark")
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 34, height: 34)
        .background(.black.opacity(0.55), in: Circle())
    }
    .buttonStyle(.plain)
    .padding(.top, 14)
    .padding(.trailing, 16)
  }

  // MARK: - Data

  private func openTrailer() {
    guard let trailerURL else { return }
    openURL(trailerURL)
  }

  private func load() async {
    defer { isLoading = false }
    info = try? await APIManager.shared.fetchVodInfo(streamId: movie.id)
  }
}
