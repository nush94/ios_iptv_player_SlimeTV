//
//  SmartRankingEngine.swift
//  IPTV
//
//  The personalization scoring formula (req 9). Split into a *base* score that
//  depends only on the item + the user's region (computed in the background and
//  stored as `forYouScore`), and *dynamic* bonuses for Favorites / Continue
//  Watching that change often and are applied at query/display time instead of
//  being baked into the stored score.
//

import Foundation

struct RankingContext: Equatable {
  let country: String?   // user's country, uppercased ISO-3166
  let language: String?  // user's language, uppercased ISO-639-1
  let region: String?    // user's region/state code
}

enum SmartRankingEngine {
  // Dynamic bonuses — applied where the item is displayed, not stored.
  static let favoriteBonus = 1000
  static let continueWatchingBonus = 900

  /// Stored "For You" base score. Higher = more relevant to this user.
  static func baseScore(
    country: String?,
    language: String?,
    region: String?,
    rating: Double,
    voteCount: Int,
    isTrendingInUserCountry: Bool,
    hasMetadata: Bool,
    context: RankingContext
  ) -> Int {
    var score = 0

    if let country, let userCountry = context.country,
       country.caseInsensitiveCompare(userCountry) == .orderedSame {
      score += 300
    }
    if let language, let userLanguage = context.language,
       language.caseInsensitiveCompare(userLanguage) == .orderedSame {
      score += 250
    }
    if isTrendingInUserCountry {
      score += 200
    }
    if rating >= 7.0, voteCount >= 100 {
      score += 150
    }
    if let region, let userRegion = context.region,
       region.caseInsensitiveCompare(userRegion) == .orderedSame {
      score += 100
    }
    if !hasMetadata {
      score -= 50
    }
    // Different language/country gets no bonus, so it naturally ranks lower.

    return score
  }

  /// Final score for display ordering: stored base + the dynamic bonuses.
  static func displayScore(base: Int, isFavorite: Bool, isContinueWatching: Bool) -> Int {
    var score = base
    if isFavorite { score += favoriteBonus }
    if isContinueWatching { score += continueWatchingBonus }
    return score
  }
}
