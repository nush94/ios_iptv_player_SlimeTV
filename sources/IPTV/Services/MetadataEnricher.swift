//
//  MetadataEnricher.swift
//  IPTV
//
//  Matches movies/shows against TMDB and enriches them with country, language,
//  rating, vote count, popularity, genre, poster, and overview (req 7-8). Runs in
//  the background, capped and resumable (only `metadataChecked == false` items),
//  most-recent first. Items that don't match are kept and simply marked checked,
//  so they rank lower (req 17) rather than disappearing. Re-scores when done.
//

import Foundation
import IPTVModels
import RealmSwift

enum MetadataEnricher {
  private static var isRunning = false
  private static let batchSize = 4
  private static let maxToEnrich = 1500

  static func enrichIfNeeded() {
    guard !isRunning, !TMDBAPIManager.apiKey.isEmpty else { return }
    isRunning = true
    Task.detached(priority: .utility) {
      await run()
      isRunning = false
    }
  }

  private static func run() async {
    let movies = await pendingMovies()
    if !movies.isEmpty { await enrich(movies, isMovie: true) }

    let shows = await pendingShows()
    if !shows.isEmpty { await enrich(shows, isMovie: false) }

    if !movies.isEmpty || !shows.isEmpty {
      await MainActor.run { SmartPlaylistOrganizer.recomputeScores() }
    }
  }

  // MARK: - Pending work (most-recent first)

  private struct PendingItem: Sendable {
    let id: Int
    let title: String
    let year: Int?
  }

  @MainActor
  private static func pendingMovies() -> [PendingItem] {
    guard let realm = try? Realm() else { return [] }
    let movies = realm.objects(CachedStream.self)
      .where { $0.section == KindMedia.vod.rawValue && $0.metadataChecked == false }
      .sorted(byKeyPath: "added", ascending: false)
    return movies.prefix(maxToEnrich).map {
      PendingItem(id: $0.id, title: $0.cleanTitle.isEmpty ? $0.name : $0.cleanTitle, year: $0.year)
    }
  }

  @MainActor
  private static func pendingShows() -> [PendingItem] {
    guard let realm = try? Realm() else { return [] }
    let shows = realm.objects(CachedSeries.self)
      .where { $0.section == KindMedia.series.rawValue && $0.metadataChecked == false }
      .sorted(byKeyPath: "lastModified", ascending: false)
    return shows.prefix(maxToEnrich).map {
      PendingItem(id: $0.id, title: $0.cleanTitle.isEmpty ? $0.name : $0.cleanTitle, year: nil)
    }
  }

  // MARK: - Match + persist

  private static func enrich(_ items: [PendingItem], isMovie: Bool) async {
    for batch in items.chunked(into: batchSize) {
      let results = await withTaskGroup(of: (Int, MatchResult).self) { group in
        for item in batch {
          group.addTask { (item.id, await resolve(item, isMovie: isMovie)) }
        }
        var collected: [(Int, MatchResult)] = []
        for await result in group { collected.append(result) }
        return collected
      }
      await persist(results, isMovie: isMovie)
      await Task.yield()
    }
  }

  private static func resolve(_ item: PendingItem, isMovie: Bool) async -> MatchResult {
    do {
      guard let id = try await TMDBAPIManager.shared.bestMatchID(title: item.title, year: item.year, isMovie: isMovie) else {
        return .noMatch
      }
      let detail = try await TMDBAPIManager.shared.details(id: id, isMovie: isMovie)
      return .matched(ResolvedMetadata(detail: detail, id: id, isMovie: isMovie))
    } catch {
      return .failed
    }
  }

  @MainActor
  private static func persist(_ results: [(Int, MatchResult)], isMovie: Bool) {
    guard let realm = try? Realm() else { return }
    try? realm.write {
      for (id, result) in results {
        if isMovie {
          guard let movie = realm.objects(CachedStream.self).where({ $0.id == id }).first else { continue }
          apply(result, to: movie)
        } else {
          guard let show = realm.objects(CachedSeries.self).where({ $0.id == id }).first else { continue }
          apply(result, to: show)
        }
      }
    }
  }

  private static func apply(_ result: MatchResult, to movie: CachedStream) {
    switch result {
    case .failed:
      return // leave unchecked so it retries on the next run
    case .noMatch:
      movie.metadataChecked = true
    case let .matched(meta):
      movie.metadataChecked = true
      if let country = meta.country { movie.country = country }
      if let language = meta.language { movie.language = language }
      movie.voteCount = meta.voteCount
      movie.popularityScore = meta.popularity
      movie.tmdb = String(meta.tmdbId)
      if meta.rating > 0 {
        movie.ratingValue = meta.rating
        if movie.rating?.isEmpty != false { movie.rating = String(format: "%.1f", meta.rating) }
      }
      if let genre = meta.genre, movie.genre?.isEmpty != false { movie.genre = genre }
      if let poster = meta.posterURL, movie.tmdbImage?.isEmpty != false { movie.tmdbImage = poster }
      if let overview = meta.overview, movie.desc?.isEmpty != false { movie.desc = overview }
      if let year = meta.year, (movie.year ?? 0) == 0 { movie.year = year }
    }
  }

  private static func apply(_ result: MatchResult, to show: CachedSeries) {
    switch result {
    case .failed:
      return
    case .noMatch:
      show.metadataChecked = true
    case let .matched(meta):
      show.metadataChecked = true
      if let country = meta.country { show.country = country }
      if let language = meta.language { show.language = language }
      show.voteCount = meta.voteCount
      show.popularityScore = meta.popularity
      show.tmdb = String(meta.tmdbId)
      if meta.rating > 0, (show.rating ?? 0) == 0 { show.rating = meta.rating }
      if let genre = meta.genre, show.genre?.isEmpty != false { show.genre = genre }
      if let poster = meta.posterURL, show.cover?.isEmpty != false { show.cover = poster }
      if let overview = meta.overview, show.plot?.isEmpty != false { show.plot = overview }
    }
  }
}

private enum MatchResult: Sendable {
  case matched(ResolvedMetadata)
  case noMatch
  case failed
}

private struct ResolvedMetadata: Sendable {
  let tmdbId: Int
  let country: String?
  let language: String?
  let voteCount: Int
  let popularity: Double
  let rating: Double
  let genre: String?
  let posterURL: String?
  let overview: String?
  let year: Int?

  init(detail: TMDBDetail, id: Int, isMovie: Bool) {
    tmdbId = id
    country = (detail.productionCountries?.first?.iso31661 ?? detail.originCountry?.first)?.uppercased()
    language = detail.originalLanguage?.uppercased()
    voteCount = detail.voteCount ?? 0
    popularity = detail.popularity ?? 0
    rating = detail.voteAverage ?? 0
    let names = detail.genres?.map(\.name).filter { !$0.isEmpty } ?? []
    genre = names.isEmpty ? nil : names.joined(separator: ", ")
    posterURL = detail.posterPath.map { "https://image.tmdb.org/t/p/w500\($0)" }
    let overviewText = detail.overview?.trimmingCharacters(in: .whitespacesAndNewlines)
    overview = (overviewText?.isEmpty == false) ? overviewText : nil
    let dateString = isMovie ? detail.releaseDate : detail.firstAirDate
    year = dateString.flatMap { Int($0.prefix(4)) }
  }
}
