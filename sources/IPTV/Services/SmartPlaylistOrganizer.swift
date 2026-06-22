//
//  SmartPlaylistOrganizer.swift
//  IPTV
//
//  Coordinates smart organization: keeps each item's stored "For You" score in
//  sync with the user's region, computed entirely off the main thread (req 13-14)
//  so the home sections can be fetched with simple sorted + LIMIT-ed queries
//  (req 15) instead of sorting 200K items on render. Favorites / Continue
//  Watching bonuses are applied at display time (see SmartRankingEngine).
//

import Foundation
import IPTVModels
import RealmSwift

extension Notification.Name {
  /// Posted after scores are recomputed so home tabs can refresh cached sections.
  static let smartSectionsDidUpdate = Notification.Name("smartSectionsDidUpdate")
}

enum SmartPlaylistOrganizer {
  private static var isRunning = false
  private static let scoringQueue = DispatchQueue(label: "com.iptv.smart.scoring", qos: .utility)

  /// Recompute + persist `forYouScore` for the whole library in the background.
  /// Safe to call repeatedly; no-ops while a run is in progress.
  @MainActor
  static func recomputeScores() {
    guard !isRunning else { return }
    isRunning = true
    let context = UserRegionProvider.shared.context
    scoringQueue.async {
      autoreleasepool {
        if let realm = try? Realm() {
          scoreStreams(realm, context: context)
          scoreSeries(realm, context: context)
        }
      }
      isRunning = false
      // Tell the home tabs to refresh their cached sections (debounced there).
      DispatchQueue.main.async {
        NotificationCenter.default.post(name: .smartSectionsDidUpdate, object: nil)
      }
    }
  }

  private static func scoreStreams(_ realm: Realm, context: RankingContext) {
    let results = realm.objects(CachedStream.self)
    try? realm.write {
      for item in results {
        item.forYouScore = SmartRankingEngine.baseScore(
          country: item.country.isEmpty ? nil : item.country,
          language: item.language.isEmpty ? nil : item.language,
          region: item.region.isEmpty ? nil : item.region,
          rating: Double(item.rating ?? "") ?? 0,
          voteCount: item.voteCount,
          isTrendingInUserCountry: isTrendingInUserCountry(country: item.country, trendingScore: item.trendingScore, context: context),
          hasMetadata: hasMetadata(item),
          context: context
        )
      }
    }
  }

  private static func scoreSeries(_ realm: Realm, context: RankingContext) {
    let results = realm.objects(CachedSeries.self)
    try? realm.write {
      for item in results {
        item.forYouScore = SmartRankingEngine.baseScore(
          country: item.country.isEmpty ? nil : item.country,
          language: item.language.isEmpty ? nil : item.language,
          region: item.region.isEmpty ? nil : item.region,
          rating: item.rating ?? item.rating5Based ?? 0,
          voteCount: item.voteCount,
          isTrendingInUserCountry: isTrendingInUserCountry(country: item.country, trendingScore: item.trendingScore, context: context),
          hasMetadata: hasMetadata(item),
          context: context
        )
      }
    }
  }

  /// "Trending in the user's country" (req 9/16): in TMDB's current trending set
  /// (`trendingScore > 0`, maintained by TrendingRefresher) AND in the user's country.
  private static func isTrendingInUserCountry(country: String, trendingScore: Double, context: RankingContext) -> Bool {
    guard trendingScore > 0, !country.isEmpty, let userCountry = context.country else {
      return false
    }
    return country.caseInsensitiveCompare(userCountry) == .orderedSame
  }

  private static func hasMetadata(_ item: CachedStream) -> Bool {
    guard !item.cleanTitle.isEmpty else { return false }
    return item.genre?.isEmpty == false || item.tmdbImage?.isEmpty == false || item.rating?.isEmpty == false
  }

  private static func hasMetadata(_ item: CachedSeries) -> Bool {
    !item.cleanTitle.isEmpty && (item.genre?.isEmpty == false || (item.rating ?? 0) > 0)
  }

  // MARK: - Section queries (req 15)
  //
  // Representative examples of the sorted + LIMIT-ed pattern the home tabs use.
  // Phase 2 builds the full catalog of sections (Featured For You, Trending In
  // Your Country, Best Reviewed, Newly Added, International, …) on top of these.

  @MainActor
  static func featured(_ section: KindMedia, limit: Int = 50) -> [CachedStream] {
    guard let realm = try? Realm() else { return [] }
    let results = realm.objects(CachedStream.self)
      .where { $0.section == section.rawValue }
      .sorted(byKeyPath: "forYouScore", ascending: false)
    return Array(results.prefix(limit))
  }

  @MainActor
  static func featuredShows(limit: Int = 50) -> [CachedSeries] {
    guard let realm = try? Realm() else { return [] }
    let results = realm.objects(CachedSeries.self)
      .where { $0.section == KindMedia.series.rawValue && $0.episodeCount > 0 }
      .sorted(byKeyPath: "forYouScore", ascending: false)
    return Array(results.prefix(limit))
  }
}
