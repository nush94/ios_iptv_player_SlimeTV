//
//  SerieDetailView.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 14/11/2024.
//

import IPTVComponents
import IPTVModels
import RealmSwift
import SwiftUI

struct SerieDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  @State var streamId: Int
  @State var serieDetail: SeriesDetail?
  @State var urlTmdbString: String?
  @State private var loadErrorMessage: String?
  @State private var showPlayer = false
  @State private var selectedStreamURL: URL?
  @State private var selectedPlaybackContext: PlaybackProgressContext?
  @State private var currentID = 9999
  @State private var allSeasons: [Int] = []
  @State private var selectedSeason: Int?

  @ObservedResults(CachedSeries.self) var series
  @ObservedResults(FavoriEntity.self) private var favorites
  @ObservedResults(CachedPlaybackProgress.self, where: ({ $0.kind == KindMedia.series.rawValue })) private var progressItems

  var filteredSerie: CachedSeries? {
    series.where { $0.id == streamId }.first
  }

  private var episodesBySeason: [Int: [Episode]] {
    guard let episodes = serieDetail?.episodes else { return [:] }
    var values: [Int: [Episode]] = [:]

    for (key, seasonEpisodes) in episodes {
      let fallbackSeason = Int(key) ?? seasonEpisodes.first?.season ?? 0
      guard fallbackSeason > 0 else { continue }
      values[fallbackSeason, default: []].append(contentsOf: seasonEpisodes.map {
        $0.withFallbacks(season: fallbackSeason, episodeNumber: max($0.episodeNum, 1))
      })
    }

    return values.mapValues { episodes in
      episodes.sorted {
        if $0.episodeNum == $1.episodeNum {
          return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        return $0.episodeNum < $1.episodeNum
      }
    }
  }

  private func episodes(for season: Int) -> [Episode] {
    episodesBySeason[season] ?? []
  }

  private var orderedEpisodes: [Episode] {
    allSeasons.flatMap { episodes(for: $0) }
  }

  private var progressByEpisodeId: [Int: CachedPlaybackProgress] {
    var values: [Int: CachedPlaybackProgress] = [:]
    let ids = Set(orderedEpisodes.compactMap { Int($0.id) })
    for item in progressItems where ids.contains(item.mediaId) {
      values[item.mediaId] = item
    }
    return values
  }

  private var resumeEpisode: Episode? {
    let progressById = progressByEpisodeId
    return orderedEpisodes
      .compactMap { episode -> (Episode, Date)? in
        guard let id = Int(episode.id),
              let progress = progressById[id]
        else { return nil }
        return (episode, progress.updatedAt)
      }
      .sorted { $0.1 > $1.1 }
      .first?
      .0
  }

  private var nextEpisode: Episode? {
    let episodes = orderedEpisodes
    guard !episodes.isEmpty else { return nil }

    guard let resumeEpisode,
          let currentIndex = episodes.firstIndex(where: { $0.id == resumeEpisode.id })
    else {
      return episodes.first
    }

    let nextIndex = episodes.index(after: currentIndex)
    guard nextIndex < episodes.endIndex else { return nil }
    return episodes[nextIndex]
  }

  private var trailerURL: URL? {
    TrailerLink.url(from: serieDetail?.info.youtubeTrailer ?? filteredSerie?.youtubeTrailer)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        backdrop

        VStack(alignment: .leading, spacing: 18) {
          title
          metadataRow
          actionButtons
          playbackActions
          plotSection
          detailRows
          seasonSection
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
      }
    }
    .background(Color.black.ignoresSafeArea())
    .preferredColorScheme(.dark)
    .navigationBarBackButtonHidden(true)
    .toolbar(.hidden, for: .navigationBar)
    .overlay(alignment: .topLeading) { backButton }
    .fullScreenCover(isPresented: Binding(get: {
      showPlayer && selectedStreamURL != nil
    }, set: { showPlayer = $0 })) {
      if let streamURL = selectedStreamURL {
        ViewPlayerContent(
          mediaURL: streamURL,
          id: currentID,
          kind: .series,
          playbackContext: selectedPlaybackContext
        )
          .ignoresSafeArea()
      }
    }
    .task { await viewDidLoad() }
  }

  // MARK: - Header

  private var backdrop: some View {
    ZStack(alignment: .bottom) {
      backdropImage
        .frame(height: 230)
        .frame(maxWidth: .infinity)
        .clipped()

      LinearGradient(
        colors: [.clear, .black.opacity(0.5), .black],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 230)
    }
  }

  @ViewBuilder
  private var backdropImage: some View {
    let path = urlTmdbString ?? serieDetail?.info.backdropPaths.first ?? filteredSerie?.getImage()
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
    Text(filteredSerie?.name.formatted() ?? "")
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

  private var favoriteButton: some View {
    Button(action: toggleFavorite) {
      HStack(spacing: 8) {
        Image(systemName: isFavorite ? "heart.fill" : "heart")
          .foregroundStyle(isFavorite ? .red : .white)
        Text(isFavorite ? "In Favorites" : "Add to Favorites")
          .foregroundStyle(.white)
      }
      .font(.system(size: 15, weight: .semibold))
      .padding(.horizontal, 16)
      .frame(height: 44)
      .background(.white.opacity(0.10), in: Capsule())
    }
    .buttonStyle(.plain)
  }

  private var actionButtons: some View {
    HStack(spacing: 10) {
      favoriteButton

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
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .frame(height: 44)
      .background(.red.opacity(0.9), in: Capsule())
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var playbackActions: some View {
    if resumeEpisode != nil || nextEpisode != nil {
      VStack(spacing: 10) {
        if let resumeEpisode {
          episodeActionButton(
            title: "Resume Episode",
            subtitle: episodeSubtitle(resumeEpisode),
            systemImage: "play.circle.fill",
            tint: .white,
            foreground: .black
          ) {
            play(resumeEpisode)
          }
        }

        if let nextEpisode, nextEpisode.id != resumeEpisode?.id {
          episodeActionButton(
            title: resumeEpisode == nil ? "Start Watching" : "Next Episode",
            subtitle: episodeSubtitle(nextEpisode),
            systemImage: "forward.end.fill",
            tint: .red,
            foreground: .white
          ) {
            play(nextEpisode)
          }
        }
      }
    }
  }

  private func episodeActionButton(
    title: String,
    subtitle: String,
    systemImage: String,
    tint: Color,
    foreground: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: systemImage)
          .font(.system(size: 18, weight: .bold))
          .frame(width: 38, height: 38)
          .background(foreground.opacity(0.14), in: Circle())

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.system(size: 16, weight: .bold))
          Text(subtitle)
            .font(.caption.weight(.semibold))
            .opacity(0.72)
            .lineLimit(1)
        }

        Spacer()
      }
      .foregroundStyle(foreground)
      .padding(.horizontal, 14)
      .frame(height: 58)
      .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var plotSection: some View {
    if let plot = serieDetail?.info.plot ?? filteredSerie?.plot, !plot.isEmpty {
      Text(plot)
        .font(.callout)
        .foregroundStyle(.white.opacity(0.82))
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder
  private var detailRows: some View {
    if let cast = filteredSerie?.cast ?? serieDetail?.info.cast, !cast.isEmpty {
      detailRow(label: "Cast", value: cast)
    }
    if let director = filteredSerie?.director ?? serieDetail?.info.director, !director.isEmpty {
      detailRow(label: "Director", value: director)
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

  // MARK: - Seasons & episodes

  @ViewBuilder
  private var seasonSection: some View {
    if !allSeasons.isEmpty {
      let season = selectedSeason ?? allSeasons.first ?? 0

      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Text("Episodes")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
          Spacer()
          Text("\(episodes(for: season).count) episodes")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.5))
        }

        if allSeasons.count > 1 {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
              ForEach(allSeasons, id: \.self) { value in
                seasonChip(value, isSelected: value == season)
              }
            }
            .padding(.vertical, 1)
          }
        }

        LazyVStack(spacing: 10) {
          ForEach(episodes(for: season), id: \.id) { episode in
            episodeRow(episode)
          }
        }
      }
      .padding(.top, 4)
    } else if serieDetail != nil || loadErrorMessage != nil {
      VStack(alignment: .leading, spacing: 8) {
        Text("Episodes")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(.white)

        Text(loadErrorMessage ?? "No playable episodes were found for this show from your playlist provider.")
          .font(.callout)
          .foregroundStyle(.white.opacity(0.62))
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.top, 4)
    }
  }

  private func seasonChip(_ season: Int, isSelected: Bool) -> some View {
    Button {
      withAnimation(.snappy) { selectedSeason = season }
    } label: {
      Text("Season \(season)")
        .font(.subheadline.weight(isSelected ? .bold : .medium))
        .foregroundStyle(isSelected ? .white : .white.opacity(0.82))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background {
          Capsule()
            .fill(isSelected ? .red.opacity(0.9) : .white.opacity(0.08))
            .overlay {
              Capsule().stroke(.white.opacity(isSelected ? 0.18 : 0.1), lineWidth: 1)
            }
        }
    }
    .buttonStyle(.plain)
  }

  private func episodeRow(_ episode: Episode) -> some View {
    Button {
      play(episode)
    } label: {
      HStack(spacing: 12) {
        episodeThumbnail(episode)

        VStack(alignment: .leading, spacing: 4) {
          Text(episodeTitle(episode))
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          Text("Episode \(episode.episodeNum)")
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.5))

          if let progress = progress(for: episode) {
            DetailProgressBar(progress: progress.percentComplete)
              .padding(.top, 3)
          }
        }

        Spacer(minLength: 8)

        Image(systemName: "play.fill")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(.black)
          .frame(width: 32, height: 32)
          .background(.white, in: Circle())
      }
      .padding(10)
      .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(.white.opacity(0.08), lineWidth: 1)
      }
      .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func episodeThumbnail(_ episode: Episode) -> some View {
    if let imageUrl = episode.info?.movieImage, !imageUrl.isEmpty, let url = URL(string: imageUrl) {
      AsyncImage(url: url, placeholder: {
        thumbnailPlaceholder
      }, content: { image in
        image.resizable().scaledToFill()
      })
      .frame(width: 116, height: 66)
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    } else {
      thumbnailPlaceholder
    }
  }

  private var thumbnailPlaceholder: some View {
    Image(systemName: "play.tv")
      .font(.system(size: 20, weight: .semibold))
      .foregroundStyle(.white.opacity(0.6))
      .frame(width: 116, height: 66)
      .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

  private var backButton: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "chevron.left")
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 38, height: 38)
        .background(.black.opacity(0.55), in: Circle())
    }
    .buttonStyle(.plain)
    .padding(.top, 12)
    .padding(.leading, 16)
  }

  // MARK: - Derived values

  private var ratingText: String? {
    if let rating = serieDetail?.info.rating?.value, !rating.isEmpty, rating != "0" {
      return rating
    }
    if let rating = filteredSerie?.rating, rating > 0 {
      return String(format: "%.1f", rating)
    }
    return nil
  }

  private var metadataParts: [String] {
    var parts: [String] = []
    if let year = seriesYear {
      parts.append(year)
    }
    if let genre = (filteredSerie?.genre ?? serieDetail?.info.genre)?
      .split(separator: ",").first?
      .trimmingCharacters(in: .whitespaces), !genre.isEmpty {
      parts.append(genre)
    }
    return parts
  }

  private var seriesYear: String? {
    let date = filteredSerie?.releaseDate ?? serieDetail?.info.releaseDate
    guard let date, date.count >= 4 else { return nil }
    return String(date.prefix(4))
  }

  private func episodeTitle(_ episode: Episode) -> String {
    let cleaned = episode.title
      .replacingOccurrences(of: filteredSerie?.name ?? "", with: "")
      .trimmingCharacters(in: CharacterSet(charactersIn: " -_"))
    return cleaned.isEmpty ? "Episode \(episode.episodeNum)" : cleaned
  }

  private var isFavorite: Bool {
    favorites.contains { $0.id == streamId && $0.kind == KindMedia.series.rawValue }
  }

  private func progress(for episode: Episode) -> CachedPlaybackProgress? {
    guard let id = Int(episode.id) else { return nil }
    return progressByEpisodeId[id]
  }

  // MARK: - Actions

  private func openTrailer() {
    guard let trailerURL else { return }
    openURL(trailerURL)
  }

  private func play(_ episode: Episode) {
    currentID = Int(episode.id) ?? 9999
    let streamURL = episode.streamURL()
    selectedStreamURL = URL(string: streamURL)
    selectedPlaybackContext = PlaybackProgressContext(
      mediaId: currentID,
      kind: .series,
      title: episodeTitle(episode),
      subtitle: episodeSubtitle(episode),
      imageURL: episode.info?.movieImage ?? filteredSerie?.cover,
      streamURL: streamURL,
      seasonNumber: episode.season,
      episodeNumber: episode.episodeNum
    )
    showPlayer = true
  }

  private func episodeSubtitle(_ episode: Episode) -> String {
    let showName = filteredSerie?.name.formatted() ?? serieDetail?.info.name.formatted() ?? "Show"
    return "\(showName) - S\(episode.season) E\(episode.episodeNum)"
  }

  @MainActor
  private func toggleFavorite() {
    guard let serie = filteredSerie else { return }
    do {
      let realm = try Realm()
      let existing = realm.objects(FavoriEntity.self)
        .where { $0.id == streamId && $0.kind == KindMedia.series.rawValue }
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

  // MARK: - Data

  private func viewDidLoad() async {
    do {
      let detail = try await loadSerieDetail()
      serieDetail = detail
      loadErrorMessage = nil
      recordEpisodeCount(detail)
    } catch {
      loadErrorMessage = "Could not load seasons for this show. Try reloading the playlist in Settings."
      print("Series detail load failed: \(error)")
    }
    if let stream = filteredSerie {
      urlTmdbString = await stream.getTmdbImage()
    }
    allSeasons = seasonNumbers()
    selectedSeason = resumeEpisode?.season ?? allSeasons.first
  }

  /// Records this show's episode count on its CachedSeries so the Shows rails
  /// can hide shows with nothing to play. Opening a show is a free, authoritative
  /// signal (we already fetched the full detail), so mark it checked here too.
  private func recordEpisodeCount(_ detail: SeriesDetail) {
    let count = detail.episodes?.values.reduce(0) { $0 + $1.count } ?? 0
    guard let realm = try? Realm(),
          let serie = realm.objects(CachedSeries.self).where({ $0.id == streamId }).first,
          !serie.episodesChecked || serie.episodeCount != count
    else { return }
    try? realm.write {
      serie.episodeCount = count
      serie.episodesChecked = true
    }
  }

  private func loadSerieDetail() async throws -> SeriesDetail {
    let detailId = streamId > 0 ? streamId : (filteredSerie?.seriesID ?? streamId)
    let apiURL = "\(APIManager.shared.baseURL)&action=get_series_info&series_id=\(detailId)"
    return try await withCheckedThrowingContinuation { continuation in
      APIManager.shared.fetchSeriesDetails(from: apiURL) { result in
        continuation.resume(with: result)
      }
    }
  }

  private func seasonNumbers() -> [Int] {
    let episodeSeasons = Set(episodesBySeason.keys)
    let declaredSeasons = Set(serieDetail?.seasons.map(\.seasonNumber).filter { $0 > 0 } ?? [])
    return episodeSeasons
      .union(declaredSeasons)
      .sorted()
      .filter { !episodes(for: $0).isEmpty || episodeSeasons.contains($0) }
  }
}
