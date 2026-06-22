//
//  CachedStream.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 11/11/2024.
//

import RealmSwift
import SwiftUI

public class CachedStream: Object, ObjectKeyIdentifiable {
  @Persisted public var identifier: ObjectId
  @Persisted(primaryKey: true) public var id: Int
  @Persisted public var name: String
  /// Normalized form of `name` (lowercased, no spaces/punctuation) for
  /// space/punctuation-insensitive search. Populated in `init`.
  @Persisted public var searchName: String
  @Persisted public var streamType: String
  @Persisted public var streamIcon: String
  @Persisted(indexed: true) public var added: Date
  @Persisted public var rating: String?
  @Persisted public var desc: String?
  @Persisted public var tmdb: String?
  @Persisted public var tmdbImage: String?
  @Persisted(indexed: true) public var section: String
  @Persisted(indexed: true) public var categoryId: String
  @Persisted public var year: Int?
  @Persisted public var genre: String?
  @Persisted public var isFavorite: Bool
  @Persisted public var containerExtension: String
  @Persisted public var tvArchive: Bool
  @Persisted public var archiveDays: Int
  // Smart organizer metadata + scores (req 3). cleanTitle/country/language are
  // filled by TitleCleaner at import; voteCount/trending/popularity by TMDB
  // enrichment; forYouScore by SmartPlaylistOrganizer (indexed for sorted,
  // LIMIT-ed section queries).
  @Persisted public var cleanTitle: String
  @Persisted public var country: String
  @Persisted public var region: String
  @Persisted public var language: String
  @Persisted public var voteCount: Int
  @Persisted public var trendingScore: Double
  @Persisted public var popularityScore: Double
  /// Numeric rating (0-10) for sorted "Best Reviewed" queries — `rating` is a
  /// free-form provider string, so this is the queryable form.
  @Persisted public var ratingValue: Double
  @Persisted(indexed: true) public var forYouScore: Int
  /// Whether TMDB enrichment has been attempted (resumable matching).
  @Persisted public var metadataChecked: Bool

  public var kindMedia: KindMedia {
    KindMedia(rawValue: section) ?? .vod
  }

  public convenience init(id: Int, name: String, streamType: String, streamIcon: String, section: String, added: Date, categoryId: String, rating: String? = nil, desc: String? = nil, tmdb: String? = nil, tmdbImage: String? = nil, year: Int?, containerExtension: String? = "mkv", tvArchive: Bool = false, archiveDays: Int = 0) {
    self.init()
    self.id = id
    self.name = name
    self.searchName = name.normalizedForSearch
    self.streamType = streamType
    self.streamIcon = streamIcon
    self.section = section
    self.added = added
    self.rating = rating
    self.desc = desc
    self.tmdb = tmdb
    self.tmdbImage = tmdbImage
    self.categoryId = categoryId
    self.year = year
    self.isFavorite = false
    self.containerExtension = containerExtension ?? "mkv"
    self.tvArchive = tvArchive
    self.archiveDays = archiveDays
  }

  public func getImage() -> String? {
    return streamIcon
  }
}
