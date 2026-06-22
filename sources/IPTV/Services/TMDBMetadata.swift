//
//  TMDBMetadata.swift
//  IPTV
//
//  TMDB title-matching + details, used by MetadataEnricher to enrich playlist
//  items (req 7-8). Search finds the best matching TMDB id for a cleaned title;
//  details returns the full metadata (overview, genres, rating, votes,
//  popularity, original language, production country).
//

import Foundation
import IPTVModels

struct TMDBSearchResponse: Decodable {
  let results: [TMDBSearchItem]
}

struct TMDBSearchItem: Decodable {
  let id: Int
  let title: String?
  let name: String?
  let originalTitle: String?
  let originalName: String?
  let popularity: Double?

  var displayTitle: String { title ?? name ?? "" }
  var originalTitleAny: String { originalTitle ?? originalName ?? "" }

  enum CodingKeys: String, CodingKey {
    case id, title, name, popularity
    case originalTitle = "original_title"
    case originalName = "original_name"
  }
}

struct TMDBGenre: Decodable { let name: String }
struct TMDBCountry: Decodable {
  let iso31661: String
  enum CodingKeys: String, CodingKey { case iso31661 = "iso_3166_1" }
}

struct TMDBDetail: Decodable {
  let id: Int
  let overview: String?
  let posterPath: String?
  let voteAverage: Double?
  let voteCount: Int?
  let popularity: Double?
  let originalLanguage: String?
  let releaseDate: String?
  let firstAirDate: String?
  let genres: [TMDBGenre]?
  let productionCountries: [TMDBCountry]?
  let originCountry: [String]?

  enum CodingKeys: String, CodingKey {
    case id, overview, popularity, genres
    case posterPath = "poster_path"
    case voteAverage = "vote_average"
    case voteCount = "vote_count"
    case originalLanguage = "original_language"
    case releaseDate = "release_date"
    case firstAirDate = "first_air_date"
    case productionCountries = "production_countries"
    case originCountry = "origin_country"
  }
}

extension TMDBAPIManager {
  /// Best-matching TMDB id for a cleaned title, or nil when nothing matches
  /// closely enough (so the item is kept but ranked lower, req 17).
  func bestMatchID(title: String, year: Int?, isMovie: Bool) async throws -> Int? {
    var query = [
      URLQueryItem(name: "api_key", value: Self.apiKey),
      URLQueryItem(name: "query", value: title),
      URLQueryItem(name: "include_adult", value: "false"),
    ]
    if let year {
      query.append(URLQueryItem(name: isMovie ? "year" : "first_air_date_year", value: String(year)))
    }
    guard let url = Self.url(path: isMovie ? "search/movie" : "search/tv", query: query) else { return nil }

    let (data, _) = try await URLSession.shared.data(from: url)
    let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
    return Self.bestMatch(in: response.results, for: title)
  }

  func details(id: Int, isMovie: Bool) async throws -> TMDBDetail {
    guard let url = Self.url(
      path: isMovie ? "movie/\(id)" : "tv/\(id)",
      query: [URLQueryItem(name: "api_key", value: Self.apiKey)]
    ) else {
      throw NSError(domain: "TMDB invalid URL", code: -1)
    }
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(TMDBDetail.self, from: data)
  }

  private static func url(path: String, query: [URLQueryItem]) -> URL? {
    var components = URLComponents(string: "https://api.themoviedb.org/3/\(path)")
    components?.queryItems = query
    return components?.url
  }

  private static func bestMatch(in results: [TMDBSearchItem], for title: String) -> Int? {
    let target = title.normalizedForSearch
    guard !target.isEmpty else { return nil }

    // Prefer an exact normalized title match (most popular among ties).
    let exact = results.filter {
      $0.displayTitle.normalizedForSearch == target || $0.originalTitleAny.normalizedForSearch == target
    }
    if let best = exact.max(by: { ($0.popularity ?? 0) < ($1.popularity ?? 0) }) {
      return best.id
    }

    // Otherwise accept the top result only when it's a sensible partial match,
    // to avoid confidently mislabeling an item.
    if let first = results.first {
      let candidate = first.displayTitle.normalizedForSearch
      if !candidate.isEmpty, candidate.contains(target) || target.contains(candidate) {
        return first.id
      }
    }
    return nil
  }
}
