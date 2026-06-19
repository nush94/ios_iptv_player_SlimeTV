//
//  MovieGenreEnricher.swift
//  IPTV
//
//  The bulk VOD listing has no genre, so we backfill each movie's genre from
//  `get_vod_info` once and cache it on CachedStream.genre. Runs in the
//  background, resumes across launches (only nil-genre movies are processed).
//

import Foundation
import IPTVModels
import RealmSwift

enum MovieGenreEnricher {
  private static var isRunning = false
  /// How many genre lookups run concurrently per network batch.
  private static let batchSize = 8
  /// Accumulate results and write to Realm in larger groups, so the UI
  /// observing the movies collection re-renders ~10× less during enrichment.
  private static let persistEvery = 80
  /// Only enrich the most-recent movies — that's all the genre rails display.
  /// Without this cap a huge catalog (100k+) would trigger 100k+ API calls.
  private static let maxToEnrich = 1500

  static func enrichIfNeeded() {
    guard !isRunning else { return }
    isRunning = true
    Task.detached(priority: .utility) {
      await run()
      isRunning = false
    }
  }

  private static func run() async {
    let pending = await pendingMovieIDs()
    guard !pending.isEmpty else { return }

    var processedIds: [Int] = []
    var found: [Int: String] = [:]

    for batch in pending.chunked(into: batchSize) {
      await withTaskGroup(of: (Int, String?).self) { group in
        for id in batch {
          group.addTask {
            let info = try? await APIManager.shared.fetchVodInfo(streamId: id)
            return (id, info?.genre)
          }
        }
        for await (id, genre) in group {
          if let genre = genre?.trimmingCharacters(in: .whitespacesAndNewlines), !genre.isEmpty {
            found[id] = genre
          }
        }
      }

      processedIds.append(contentsOf: batch)

      if processedIds.count >= persistEvery {
        await persist(batch: processedIds, genres: found)
        processedIds.removeAll(keepingCapacity: true)
        found.removeAll(keepingCapacity: true)
      }
    }

    // Flush whatever's left in the final partial group.
    if !processedIds.isEmpty {
      await persist(batch: processedIds, genres: found)
    }
  }

  @MainActor
  private static func pendingMovieIDs() -> [Int] {
    guard let realm = try? Realm() else { return [] }
    return realm.objects(CachedStream.self)
      .where { $0.section == KindMedia.vod.rawValue && $0.genre == nil }
      .sorted(byKeyPath: "added", ascending: false)
      .prefix(maxToEnrich)
      .map { $0.id }
  }

  /// Writes found genres, and marks the rest of the batch as processed (empty
  /// string) so they aren't fetched again on the next pass.
  @MainActor
  private static func persist(batch: [Int], genres: [Int: String]) {
    guard let realm = try? Realm() else { return }
    try? realm.write {
      for id in batch {
        guard let movie = realm.objects(CachedStream.self).where({ $0.id == id }).first else { continue }
        movie.genre = genres[id] ?? ""
      }
    }
  }
}

extension Array {
  func chunked(into size: Int) -> [[Element]] {
    guard size > 0 else { return [self] }
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0 ..< Swift.min($0 + size, count)])
    }
  }
}
