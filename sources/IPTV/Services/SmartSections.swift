//
//  SmartSections.swift
//  IPTV
//
//  The home sections (req 10-12), each a sorted + LIMIT-ed Realm query over the
//  scores/metadata computed by the Smart Organizer — never loading or sorting the
//  whole catalog (req 13, 15). Favorites / Continue Watching are separate shelves
//  the tabs already render, so they aren't repeated here.
//

import Foundation
import IPTVModels
import RealmSwift

/// All accessors are synchronous Realm reads meant to be called from the main
/// thread (SwiftUI view bodies), matching the rest of the app's Realm usage.
enum SmartSections {
  static let limit = 40

  private static let vod = KindMedia.vod.rawValue
  private static let series = KindMedia.series.rawValue
  private static let live = KindMedia.live.rawValue

  private static var newCutoffYear: Int {
    max(Calendar.current.component(.year, from: Date()) - 2, 2024)
  }

  // MARK: - Movies (req 10)

  static func forYouMovies(limit: Int = limit) -> [CachedStream] {
    streams(NSPredicate(format: "section == %@", vod), sortedBy: "forYouScore", limit: limit)
  }

  static func trendingMovies(country: String?, limit: Int = limit) -> [CachedStream] {
    guard let country, !country.isEmpty else { return [] }
    return streams(
      NSPredicate(format: "section == %@ AND country ==[c] %@ AND trendingScore > 0", vod, country),
      sortedBy: "trendingScore", limit: limit
    )
  }

  static func bestReviewedNewMovies(limit: Int = limit) -> [CachedStream] {
    streams(
      NSPredicate(format: "section == %@ AND ratingValue > 0 AND voteCount >= 50 AND year >= %d", vod, newCutoffYear),
      sortedBy: "ratingValue", limit: limit
    )
  }

  static func newlyAddedMovies(limit: Int = limit) -> [CachedStream] {
    streams(NSPredicate(format: "section == %@", vod), sortedBy: "added", limit: limit)
  }

  static func internationalMovies(country: String?, limit: Int = limit) -> [CachedStream] {
    streams(internationalPredicate(section: vod, country: country), sortedBy: "popularityScore", limit: limit)
  }

  // MARK: - Shows (req 11)

  static func forYouShows(limit: Int = limit) -> [CachedSeries] {
    shows(playable(series), sortedBy: "forYouScore", limit: limit)
  }

  static func trendingShows(country: String?, limit: Int = limit) -> [CachedSeries] {
    guard let country, !country.isEmpty else { return [] }
    let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      playable(series),
      NSPredicate(format: "country ==[c] %@ AND trendingScore > 0", country),
    ])
    return shows(predicate, sortedBy: "trendingScore", limit: limit)
  }

  static func bestReviewedShows(limit: Int = limit) -> [CachedSeries] {
    let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      playable(series),
      NSPredicate(format: "rating > 0 AND voteCount >= 50"),
    ])
    return shows(predicate, sortedBy: "rating", limit: limit)
  }

  static func newlyAddedShows(limit: Int = limit) -> [CachedSeries] {
    shows(playable(series), sortedBy: "lastModified", limit: limit)
  }

  static func internationalShows(country: String?, limit: Int = limit) -> [CachedSeries] {
    let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
      playable(series),
      internationalPredicate(section: nil, country: country),
    ])
    return shows(predicate, sortedBy: "popularityScore", limit: limit)
  }

  // MARK: - Live TV (req 12)
  //
  // Live metadata is weak (no TMDB), so country/keywords come from the channel
  // name via TitleCleaner — best effort.

  private static let newsKeywords = ["news", "cnn", "bbc", "fox news", "msnbc", "al jazeera"]
  private static let sportsKeywords = ["sport", "espn", "bein", "dazn", "sky sports", "tnt sports"]

  static func localChannels(country: String?, region: String?, limit: Int = limit) -> [CachedStream] {
    if let region, !region.isEmpty {
      let byRegion = streams(NSPredicate(format: "section == %@ AND region ==[c] %@", live, region), sortedBy: "forYouScore", limit: limit)
      if !byRegion.isEmpty { return byRegion }
    }
    return nationalChannels(country: country, sortedBy: "forYouScore", limit: limit)
  }

  static func newsChannels(country: String?, limit: Int = limit) -> [CachedStream] {
    streams(liveKeywordPredicate(newsKeywords, country: country), sortedBy: "forYouScore", limit: limit)
  }

  static func sportsChannels(country: String?, limit: Int = limit) -> [CachedStream] {
    streams(liveKeywordPredicate(sportsKeywords, country: country), sortedBy: "forYouScore", limit: limit)
  }

  static func nationalChannels(country: String?, limit: Int = limit) -> [CachedStream] {
    nationalChannels(country: country, sortedBy: "name", limit: limit)
  }

  static func internationalChannels(country: String?, limit: Int = limit) -> [CachedStream] {
    streams(internationalPredicate(section: live, country: country), sortedBy: "forYouScore", limit: limit)
  }

  private static func nationalChannels(country: String?, sortedBy key: String, limit: Int) -> [CachedStream] {
    let all = NSPredicate(format: "section == %@", live)
    guard let country, !country.isEmpty else {
      return streams(all, sortedBy: key, limit: limit)
    }
    let inCountry = streams(
      NSPredicate(format: "section == %@ AND country ==[c] %@", live, country),
      sortedBy: key, limit: limit
    )
    if !inCountry.isEmpty { return inCountry }
    // The user's detected country isn't represented in this playlist (e.g. a US
    // device with a CA/EN playlist) — show the top available channels instead of
    // a blank list.
    return streams(all, sortedBy: key, limit: limit)
  }

  // MARK: - Adult content filter (keep adult clips off the home page)

  static let adultNameTerms = ["[x]", "xxx", "+18", "18+", "porn", "woodman"]
  static let adultGenreTerms = ["adult", "xxx", "porn", "erotic", "hentai"]

  static func isAdult(name: String, genre: String?) -> Bool {
    let lowerName = name.lowercased()
    if adultNameTerms.contains(where: { lowerName.contains($0) }) { return true }
    if let lowerGenre = genre?.lowercased(), adultGenreTerms.contains(where: { lowerGenre.contains($0) }) { return true }
    return false
  }

  private static var adultExclusion: NSPredicate {
    let matches = adultNameTerms.map { NSPredicate(format: "name CONTAINS[c] %@", $0) }
      + adultGenreTerms.map { NSPredicate(format: "genre CONTAINS[c] %@", $0) }
    return NSCompoundPredicate(notPredicateWithSubpredicate: NSCompoundPredicate(orPredicateWithSubpredicates: matches))
  }

  // MARK: - Shared helpers

  private static func streams(_ predicate: NSPredicate, sortedBy key: String, limit: Int) -> [CachedStream] {
    guard let realm = try? Realm() else { return [] }
    let combined = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, adultExclusion])
    let results = realm.objects(CachedStream.self).filter(combined)
      .sorted(byKeyPath: key, ascending: key == "name")
    return Array(results.prefix(limit))
  }

  private static func shows(_ predicate: NSPredicate, sortedBy key: String, limit: Int) -> [CachedSeries] {
    guard let realm = try? Realm() else { return [] }
    let combined = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, adultExclusion])
    let results = realm.objects(CachedSeries.self).filter(combined)
      .sorted(byKeyPath: key, ascending: false)
    return Array(results.prefix(limit))
  }

  /// Shows that have episodes, or haven't been checked yet (optimistic — matches
  /// the Shows tab's episode filter).
  private static func playable(_ section: String) -> NSPredicate {
    NSPredicate(format: "section == %@ AND (episodesChecked == NO OR episodeCount > 0)", section)
  }

  private static func internationalPredicate(section: String?, country: String?) -> NSPredicate {
    var parts: [NSPredicate] = [NSPredicate(format: "country != ''")]
    if let section { parts.append(NSPredicate(format: "section == %@", section)) }
    if let country, !country.isEmpty { parts.append(NSPredicate(format: "country !=[c] %@", country)) }
    return NSCompoundPredicate(andPredicateWithSubpredicates: parts)
  }

  private static func liveKeywordPredicate(_ keywords: [String], country: String?) -> NSPredicate {
    let keywordOr = NSCompoundPredicate(orPredicateWithSubpredicates: keywords.map {
      NSPredicate(format: "name CONTAINS[c] %@", $0)
    })
    var parts = [NSPredicate(format: "section == %@", live), keywordOr]
    if let country, !country.isEmpty {
      parts.append(NSPredicate(format: "country ==[c] %@", country))
    }
    return NSCompoundPredicate(andPredicateWithSubpredicates: parts)
  }
}
