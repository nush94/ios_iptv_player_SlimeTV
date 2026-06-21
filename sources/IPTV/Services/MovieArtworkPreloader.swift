//
//  MovieArtworkPreloader.swift
//  IPTV
//

import Foundation
import IPTVModels
import RealmSwift

enum MovieArtworkPreloader {
  private static let maxMoviesToPrepare = 90
  private static let batchSize = 6
  private static var isRunning = false

  /// Fire-and-forget pre-warm that does NOT block playlist import. Safe to call
  /// repeatedly — it no-ops while a run is already in progress.
  static func preloadInBackground() {
    guard !isRunning else { return }
    isRunning = true
    Task.detached(priority: .utility) {
      await preloadTopMovieArtwork()
      isRunning = false
    }
  }

  static func preloadTopMovieArtwork(progress: (@MainActor (String) -> Void)? = nil) async {
    let movies = await moviesNeedingArtwork()
    guard !movies.isEmpty else {
      await progress?("Posters ready.")
      return
    }

    var completed = 0
    for batch in movies.chunked(into: batchSize) {
      let updates = await withTaskGroup(of: MovieArtworkUpdate?.self) { group in
        for movie in batch {
          group.addTask {
            guard let info = try? await APIManager.shared.fetchVodInfo(streamId: movie.id) else {
              return nil
            }

            return MovieArtworkUpdate(
              id: movie.id,
              poster: clean(info.poster),
              genre: clean(info.genre),
              description: clean(info.plot),
              rating: clean(info.rating)
            )
          }
        }

        var values: [MovieArtworkUpdate] = []
        for await update in group {
          if let update { values.append(update) }
        }
        return values
      }

      await persist(updates)
      completed += batch.count
      await progress?("Preparing posters... \(completed)/\(movies.count)")
      await Task.yield()
    }
  }

  @MainActor
  private static func moviesNeedingArtwork() -> [MovieArtworkSeed] {
    guard let realm = try? Realm() else { return [] }
    let movies = realm.objects(CachedStream.self)
      .where { $0.section == KindMedia.vod.rawValue }
      .sorted(byKeyPath: "added", ascending: false)

    var values: [MovieArtworkSeed] = []
    for movie in movies {
      let needsArtwork = clean(movie.tmdbImage) == nil
      let needsDetails = clean(movie.genre) == nil || clean(movie.desc) == nil || clean(movie.rating) == nil
      guard needsArtwork || needsDetails else { continue }

      values.append(MovieArtworkSeed(id: movie.id))
      if values.count == maxMoviesToPrepare { break }
    }
    return values
  }

  @MainActor
  private static func persist(_ updates: [MovieArtworkUpdate]) async {
    guard !updates.isEmpty,
          let realm = try? await Realm()
    else {
      return
    }

    let updatesById = Dictionary(uniqueKeysWithValues: updates.map { ($0.id, $0) })
    try? realm.write {
      for (id, update) in updatesById {
        guard let movie = realm.objects(CachedStream.self).where({ $0.id == id }).first else { continue }
        if clean(movie.tmdbImage) == nil, let poster = update.poster {
          movie.tmdbImage = poster
        }
        if clean(movie.genre) == nil, let genre = update.genre {
          movie.genre = genre
        }
        if clean(movie.desc) == nil, let description = update.description {
          movie.desc = description
        }
        if clean(movie.rating) == nil, let rating = update.rating {
          movie.rating = rating
        }
      }
    }
  }

  private static func clean(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty,
          value != "0"
    else {
      return nil
    }
    return value
  }
}

private struct MovieArtworkSeed: Sendable {
  let id: Int
}

private struct MovieArtworkUpdate: Sendable {
  let id: Int
  let poster: String?
  let genre: String?
  let description: String?
  let rating: String?
}
