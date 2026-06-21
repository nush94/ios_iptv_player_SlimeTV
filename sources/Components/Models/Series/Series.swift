//
//  Series.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 11/11/2024.
//

import Foundation

public struct Series: Identifiable, Decodable, Sendable {
  public let id: Int
  public let name: String
  public let seriesID: Int
  public let cover: String?
  public let plot: String?
  public let cast: String?
  public let director: String?
  public let genre: String?
  public let releaseDate: String?
  public let lastModified: Date
  public let rating: Double?
  public let rating5Based: Double?
  public let backdropPaths: [String]
  public let youtubeTrailer: String?
  public let tmdb: String?
  public let episodeRunTime: Int?
  public let categoryID: String
  public let categoryIDs: [Int]

  enum CodingKeys: String, CodingKey {
    case id = "num"
    case name
    case seriesID = "series_id"
    case cover
    case plot
    case cast
    case director
    case genre
    case releaseDate
    case lastModified = "last_modified"
    case rating
    case rating5Based = "rating_5based"
    case backdropPaths = "backdrop_path"
    case youtubeTrailer = "youtube_trailer"
    case tmdb
    case episodeRunTime = "episode_run_time"
    case categoryID = "category_id"
    case categoryIDs = "category_ids"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let decodedSeriesID = container.decodeFlexibleInt(forKey: .seriesID)
      ?? container.decodeFlexibleInt(forKey: .id)
    let decodedNumber = container.decodeFlexibleInt(forKey: .id) ?? decodedSeriesID

    guard let decodedSeriesID,
          let decodedName = container.decodeFlexibleString(forKey: .name)
    else {
      throw DecodingError.dataCorruptedError(
        forKey: .seriesID,
        in: container,
        debugDescription: "Series is missing a usable series_id or name"
      )
    }

    self.id = decodedSeriesID
    self.name = decodedName
    self.seriesID = decodedNumber ?? decodedSeriesID
    self.cover = container.decodeFlexibleString(forKey: .cover)
    self.plot = container.decodeFlexibleString(forKey: .plot)
    self.cast = container.decodeFlexibleString(forKey: .cast)
    self.director = container.decodeFlexibleString(forKey: .director)
    self.genre = container.decodeFlexibleString(forKey: .genre)
    self.releaseDate = container.decodeFlexibleString(forKey: .releaseDate)

    if let timestamp = container.decodeFlexibleDouble(forKey: .lastModified) {
      self.lastModified = Date(timeIntervalSince1970: timestamp)
    } else {
      self.lastModified = .distantPast
    }

    self.rating = container.decodeFlexibleDouble(forKey: .rating)
    self.rating5Based = container.decodeFlexibleDouble(forKey: .rating5Based)
    self.backdropPaths = (try? container.decodeIfPresent([String].self, forKey: .backdropPaths)) ?? []
    self.youtubeTrailer = container.decodeFlexibleString(forKey: .youtubeTrailer)
    self.tmdb = container.decodeFlexibleString(forKey: .tmdb)
    self.episodeRunTime = container.decodeFlexibleInt(forKey: .episodeRunTime)
    self.categoryID = container.decodeFlexibleString(forKey: .categoryID) ?? ""
    self.categoryIDs = (try? container.decodeIfPresent([Int].self, forKey: .categoryIDs)) ?? []
  }

  public init(id: Int, name: String, seriesID: Int, cover: String? = nil, plot: String? = nil, cast: String? = nil, director: String? = nil, genre: String? = nil, releaseDate: String? = nil, lastModified: Date, rating: Double? = nil, rating5Based: Double? = nil, backdropPaths: [String], youtubeTrailer: String? = nil, tmdb: String, episodeRunTime: Int, categoryID: String, categoryIDs: [Int]) {
    self.id = id
    self.name = name
    self.seriesID = seriesID
    self.cover = cover
    self.plot = plot
    self.cast = cast
    self.director = director
    self.genre = genre
    self.releaseDate = releaseDate
    self.lastModified = lastModified
    self.rating = rating
    self.rating5Based = rating5Based
    self.backdropPaths = backdropPaths
    self.youtubeTrailer = youtubeTrailer
    self.tmdb = tmdb
    self.episodeRunTime = episodeRunTime
    self.categoryID = categoryID
    self.categoryIDs = categoryIDs
  }

  // Transformable properties for CoreData compatibility
  var backdropPathsData: Data? {
    try? JSONEncoder().encode(backdropPaths)
  }

  var categoryIDsData: Data? {
    try? JSONEncoder().encode(categoryIDs)
  }

  // Transform data back to arrays
  static func decodeBackdropPaths(from data: Data?) -> [String] {
    guard let data else { return [] }
    return (try? JSONDecoder().decode([String].self, from: data)) ?? []
  }

  static func decodeCategoryIDs(from data: Data?) -> [Int] {
    guard let data else { return [] }
    return (try? JSONDecoder().decode([Int].self, from: data)) ?? []
  }
}

// Info sur la série
public struct SeriesInfo: Decodable {
  public let name: String
  public let cover: String
  public let plot: String?
  public let cast: String?
  public let director: String?
  public let genre: String?
  public let releaseDate: String?
  public let lastModified: Date?
  public let rating: FlexibleString?
  public let rating5Based: FlexibleString?
  public let tmdb: String
  public let backdropPaths: [String]
  public let youtubeTrailer: String?

  enum CodingKeys: String, CodingKey {
    case name
    case cover
    case plot
    case cast
    case director
    case genre
    case releaseDate
    case lastModified = "last_modified"
    case rating
    case rating5Based = "rating_5based"
    case tmdb
    case backdropPaths = "backdrop_path"
    case youtubeTrailer = "youtube_trailer"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.name = try container.decode(String.self, forKey: .name)
    self.cover = container.decodeFlexibleString(forKey: .cover) ?? ""
    self.plot = try container.decodeIfPresent(String.self, forKey: .plot)
    self.cast = try container.decodeIfPresent(String.self, forKey: .cast)
    self.director = try container.decodeIfPresent(String.self, forKey: .director)
    self.genre = try container.decodeIfPresent(String.self, forKey: .genre)
    self.releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)

    if let lastModifiedString = try? container.decode(String.self, forKey: .lastModified),
       let timestamp = Double(lastModifiedString) {
      self.lastModified = Date(timeIntervalSince1970: timestamp)
    } else if let lastModifiedDouble = try? container.decode(Double.self, forKey: .lastModified) {
      self.lastModified = Date(timeIntervalSince1970: lastModifiedDouble)
    } else {
      self.lastModified = nil
    }
    self.rating = try? container.decodeIfPresent(FlexibleString.self, forKey: .rating)
    self.rating5Based = try? container.decodeIfPresent(FlexibleString.self, forKey: .rating5Based)
    self.tmdb = container.decodeFlexibleString(forKey: .tmdb) ?? ""
    self.backdropPaths = (try? container.decodeIfPresent([String].self, forKey: .backdropPaths)) ?? []
    self.youtubeTrailer = try container.decodeIfPresent(String.self, forKey: .youtubeTrailer)
  }

  public init(name: String, cover: String, plot: String? = nil, cast: String? = nil, director: String? = nil, genre: String? = nil, releaseDate: String? = nil, lastModified: Date? = nil, rating: FlexibleString? = nil, rating5Based: FlexibleString? = nil, tmdb: String, backdropPaths: [String], youtubeTrailer: String? = nil) {
    self.name = name
    self.cover = cover
    self.plot = plot
    self.cast = cast
    self.director = director
    self.genre = genre
    self.releaseDate = releaseDate
    self.lastModified = lastModified
    self.rating = rating
    self.rating5Based = rating5Based
    self.tmdb = tmdb
    self.backdropPaths = backdropPaths
    self.youtubeTrailer = youtubeTrailer
  }
}

// Informations sur un épisode
public struct EpisodeInfo: Decodable {
  public let movieImage: String?

  enum CodingKeys: String, CodingKey {
    case movieImage = "movie_image"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.movieImage = try container.decodeIfPresent(String.self, forKey: .movieImage)
  }
}

public struct Episode: Decodable {
  public let id: String
  public let episodeNum: Int
  public let title: String
  public let containerExtension: String?
  public let added: Date?
  public let season: Int
  public let info: EpisodeInfo?

  enum CodingKeys: String, CodingKey {
    case id
    case episodeNum = "episode_num"
    case title
    case containerExtension = "container_extension"
    case added
    case season
    case info
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let decodedEpisodeNum = container.decodeFlexibleInt(forKey: .episodeNum) ?? 0

    self.id = container.decodeFlexibleString(forKey: .id) ?? UUID().uuidString
    self.episodeNum = decodedEpisodeNum
    self.title = container.decodeFlexibleString(forKey: .title) ?? "Episode \(max(decodedEpisodeNum, 1))"
    self.containerExtension = container.decodeFlexibleString(forKey: .containerExtension)
    if let addedTimestamp = container.decodeFlexibleDouble(forKey: .added) {
      self.added = Date(timeIntervalSince1970: addedTimestamp)
    } else {
      self.added = nil
    }
    self.season = container.decodeFlexibleInt(forKey: .season) ?? 0
    self.info = try? container.decodeIfPresent(EpisodeInfo.self, forKey: .info)
  }

  public init(
    id: String,
    episodeNum: Int,
    title: String,
    containerExtension: String?,
    added: Date?,
    season: Int,
    info: EpisodeInfo?
  ) {
    self.id = id
    self.episodeNum = episodeNum
    self.title = title
    self.containerExtension = containerExtension
    self.added = added
    self.season = season
    self.info = info
  }

  public func withFallbacks(season fallbackSeason: Int, episodeNumber fallbackEpisodeNumber: Int) -> Episode {
    Episode(
      id: id,
      episodeNum: episodeNum > 0 ? episodeNum : fallbackEpisodeNumber,
      title: title,
      containerExtension: containerExtension,
      added: added,
      season: season > 0 ? season : fallbackSeason,
      info: info
    )
  }
}

// Informations sur une saison
public struct Season: Decodable {
  public let name: String
  public let episodeCount: FlexibleString?
  public let overview: String?
  public let airDate: String?
  public let cover: String
  public let coverTMDB: String
  public let seasonNumber: Int
  public let coverBig: String
  public let releaseDate: String?
  public let duration: String?

  enum CodingKeys: String, CodingKey {
    case name
    case episodeCount = "episode_count"
    case overview
    case airDate = "air_date"
    case cover
    case coverTMDB = "cover_tmdb"
    case seasonNumber = "season_number"
    case coverBig = "cover_big"
    case releaseDate
    case duration
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.name = container.decodeFlexibleString(forKey: .name) ?? ""
    self.episodeCount = try? container.decodeIfPresent(FlexibleString.self, forKey: .episodeCount)
    self.overview = try container.decodeIfPresent(String.self, forKey: .overview)
    self.airDate = try container.decodeIfPresent(String.self, forKey: .airDate)
    self.cover = container.decodeFlexibleString(forKey: .cover) ?? ""
    self.coverTMDB = container.decodeFlexibleString(forKey: .coverTMDB) ?? ""
    self.seasonNumber = container.decodeFlexibleInt(forKey: .seasonNumber) ?? 0
    self.coverBig = container.decodeFlexibleString(forKey: .coverBig) ?? ""
    self.releaseDate = container.decodeFlexibleString(forKey: .releaseDate)
    self.duration = container.decodeFlexibleString(forKey: .duration)
  }
}

// Informations complètes sur une série
public struct SeriesDetail: Decodable {
  public let info: SeriesInfo
  public let seasons: [Season]
  public let episodes: [String: [Episode]]?

  enum CodingKeys: String, CodingKey {
    case info
    case seasons
    case episodes
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.info = (try? container.decode(SeriesInfo.self, forKey: .info)) ?? SeriesInfo(
      name: "",
      cover: "",
      tmdb: "",
      backdropPaths: []
    )
    if let seasonValues = try? container.decodeIfPresent([FailableDecodable<Season>].self, forKey: .seasons) {
      self.seasons = seasonValues.compactMap(\.value)
    } else {
      self.seasons = []
    }
    self.episodes = Self.decodeEpisodes(from: container)
  }

  public init(info: SeriesInfo, seasons: [Season], episodes: [String: [Episode]]?) {
    self.info = info
    self.seasons = seasons
    self.episodes = episodes
  }

  private static func decodeEpisodes(from container: KeyedDecodingContainer<CodingKeys>) -> [String: [Episode]]? {
    if let groupedEpisodes = decodeGroupedEpisodes(from: container) {
      return groupedEpisodes
    }

    if let flatEpisodes = try? container.decodeIfPresent([FailableDecodable<Episode>].self, forKey: .episodes) {
      var decoded: [String: [Episode]] = [:]
      for (index, value) in flatEpisodes.enumerated() {
        guard let episode = value.value else { continue }
        let fallbackSeason = episode.season > 0 ? episode.season : 1
        let normalized = episode.withFallbacks(season: fallbackSeason, episodeNumber: index + 1)
        decoded[String(normalized.season), default: []].append(normalized)
      }
      return decoded.isEmpty ? nil : decoded
    }

    return nil
  }

  private static func decodeGroupedEpisodes(from container: KeyedDecodingContainer<CodingKeys>) -> [String: [Episode]]? {
    guard let episodesContainer = try? container.nestedContainer(
      keyedBy: DynamicCodingKey.self,
      forKey: .episodes
    ) else { return nil }

    var decoded: [String: [Episode]] = [:]
    let seasonKeys = episodesContainer.allKeys.sorted { lhs, rhs in
      let lhsSeason = seasonNumber(from: lhs.stringValue) ?? Int.max
      let rhsSeason = seasonNumber(from: rhs.stringValue) ?? Int.max
      if lhsSeason == rhsSeason {
        return lhs.stringValue < rhs.stringValue
      }
      return lhsSeason < rhsSeason
    }

    for (keyIndex, key) in seasonKeys.enumerated() {
      guard let episodeValues = try? episodesContainer.decode(
        [FailableDecodable<Episode>].self,
        forKey: key
      ) else { continue }

      let fallbackSeason = seasonNumber(from: key.stringValue) ?? keyIndex + 1
      let episodes = episodeValues.enumerated().compactMap { index, value in
        value.value?.withFallbacks(season: fallbackSeason, episodeNumber: index + 1)
      }

      if !episodes.isEmpty {
        decoded[String(fallbackSeason), default: []].append(contentsOf: episodes)
      }
    }

    return decoded.isEmpty ? nil : decoded
  }
}

private struct DynamicCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = Int(stringValue)
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}

private struct FailableDecodable<Value: Decodable>: Decodable {
  let value: Value?

  init(from decoder: Decoder) throws {
    self.value = try? Value(from: decoder)
  }
}

private func seasonNumber(from key: String) -> Int? {
  if let value = Int(key), value > 0 {
    return value
  }

  let digits = key.split { !$0.isNumber }.first.map(String.init)
  guard let value = digits.flatMap(Int.init), value > 0 else { return nil }
  return value
}

private extension KeyedDecodingContainer {
  func decodeFlexibleString(forKey key: Key) -> String? {
    if let value = try? decode(String.self, forKey: key) {
      return value
    }
    if let value = try? decode(Int.self, forKey: key) {
      return String(value)
    }
    if let value = try? decode(Double.self, forKey: key) {
      return String(value)
    }
    return nil
  }

  func decodeFlexibleInt(forKey key: Key) -> Int? {
    if let value = try? decode(Int.self, forKey: key) {
      return value
    }
    if let value = try? decode(Double.self, forKey: key) {
      return Int(value)
    }
    if let value = try? decode(String.self, forKey: key) {
      return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return nil
  }

  func decodeFlexibleDouble(forKey key: Key) -> Double? {
    if let value = try? decode(Double.self, forKey: key) {
      return value
    }
    if let value = try? decode(Int.self, forKey: key) {
      return Double(value)
    }
    if let value = try? decode(String.self, forKey: key) {
      return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return nil
  }
}
