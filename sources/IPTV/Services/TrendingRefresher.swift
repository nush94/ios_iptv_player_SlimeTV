//
//  TrendingRefresher.swift
//  IPTV
//
//  Refreshes "trending" on a schedule (req 16): pulls TMDB's weekly trending
//  movie/show ids and flags the matched library items so the "Trending In Your
//  Country" sections and the +200 ranking bonus reflect what's actually hot —
//  not just a popularity proxy. Runs in the background, stale-gated so it only
//  hits the network every few hours. Re-scores when done.
//

import Foundation
import IPTVModels
import RealmSwift

enum TrendingRefresher {
  private static var isRunning = false
  private static let refreshInterval: TimeInterval = 12 * 3600
  private static let lastRefreshKey = "smartTrendingRefreshedAt"

  /// Refresh only if the cached trending data is older than `refreshInterval`.
  static func refreshIfStale() {
    let last = UserDefaults.standard.double(forKey: lastRefreshKey)
    guard Date().timeIntervalSince1970 - last > refreshInterval else { return }
    refresh()
  }

  static func refresh() {
    guard !isRunning, !TMDBAPIManager.apiKey.isEmpty else { return }
    isRunning = true
    Task.detached(priority: .utility) {
      let movieIDs = (try? await TMDBAPIManager.shared.trendingIDs(isMovie: true)) ?? []
      let showIDs = (try? await TMDBAPIManager.shared.trendingIDs(isMovie: false)) ?? []

      if !movieIDs.isEmpty || !showIDs.isEmpty {
        applyTrending(movieIDs: Set(movieIDs), showIDs: Set(showIDs))
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastRefreshKey)
        await MainActor.run { SmartPlaylistOrganizer.recomputeScores() }
      }
      isRunning = false
    }
  }

  /// Sets `trendingScore` (= popularity) on matched items that are in TMDB's
  /// trending set, and clears it on those that no longer are.
  private static func applyTrending(movieIDs: Set<Int>, showIDs: Set<Int>) {
    autoreleasepool {
      guard let realm = try? Realm() else { return }
      try? realm.write {
        for movie in realm.objects(CachedStream.self).where({ $0.tmdb != nil }) {
          let id = Int(movie.tmdb ?? "")
          movie.trendingScore = (id.map(movieIDs.contains) ?? false) ? movie.popularityScore : 0
        }
        for show in realm.objects(CachedSeries.self).where({ $0.tmdb != "" }) {
          let id = Int(show.tmdb)
          show.trendingScore = (id.map(showIDs.contains) ?? false) ? show.popularityScore : 0
        }
      }
    }
  }
}
