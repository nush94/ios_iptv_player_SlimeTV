//
//  SeriesEpisodeEnricher.swift
//  IPTV
//
//  The bulk `get_series` listing has no episode data, so a "show" might be a
//  real series or a metadata-only placeholder. This backfills each show's
//  episode count from `get_series_info` once and records it on CachedSeries so
//  the Shows rails can hide shows that have nothing to play. Runs in the
//  background, resumes across launches (only unchecked shows are processed).
//

import Foundation
import IPTVModels
import RealmSwift

enum SeriesEpisodeEnricher {
  private static var isRunning = false
  /// How many `get_series_info` lookups run concurrently per batch.
  private static let batchSize = 6
  /// Cap the work — checking the most-recent shows first covers what the rails
  /// display without firing a request for every show in a huge catalog.
  private static let maxToCheck = 1200

  static func enrichIfNeeded() {
    guard !isRunning else { return }
    isRunning = true
    Task.detached(priority: .utility) {
      await run()
      isRunning = false
    }
  }

  private static func run() async {
    let pending = await pendingSeriesIDs()
    guard !pending.isEmpty else { return }

    for batch in pending.chunked(into: batchSize) {
      let results = await withTaskGroup(of: (Int, Int?).self) { group in
        for id in batch {
          group.addTask {
            // nil = lookup failed (leave unchecked so it retries and stays
            // visible); a number (incl. 0) = a real answer we can record.
            (id, try? await episodeCount(seriesId: id))
          }
        }
        var values: [(Int, Int?)] = []
        for await pair in group { values.append(pair) }
        return values
      }

      await persist(results)
      await Task.yield()
    }
  }

  @MainActor
  private static func pendingSeriesIDs() -> [Int] {
    guard let realm = try? Realm() else { return [] }
    return realm.objects(CachedSeries.self)
      .where { $0.section == KindMedia.series.rawValue && $0.episodesChecked == false }
      .sorted(byKeyPath: "lastModified", ascending: false)
      .prefix(maxToCheck)
      .map(\.id)
  }

  private static func episodeCount(seriesId: Int) async throws -> Int {
    let apiURL = "\(APIManager.shared.baseURL)&action=get_series_info&series_id=\(seriesId)"
    let detail: SeriesDetail = try await withCheckedThrowingContinuation { continuation in
      APIManager.shared.fetchSeriesDetails(from: apiURL) { continuation.resume(with: $0) }
    }
    guard let episodes = detail.episodes else { return 0 }
    return episodes.values.reduce(0) { $0 + $1.count }
  }

  @MainActor
  private static func persist(_ results: [(Int, Int?)]) {
    let resolved = results.compactMap { id, count in count.map { (id, $0) } }
    guard !resolved.isEmpty, let realm = try? Realm() else { return }
    try? realm.write {
      for (id, count) in resolved {
        guard let serie = realm.objects(CachedSeries.self).where({ $0.id == id }).first else { continue }
        serie.episodeCount = count
        serie.episodesChecked = true
      }
    }
  }
}
