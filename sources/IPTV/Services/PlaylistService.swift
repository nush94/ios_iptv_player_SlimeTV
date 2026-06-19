//
//  PlaylistService.swift
//  IPTV
//
//  Playlist credential parsing + full library load, extracted from the
//  Settings screen so it can be reused by Manage Playlist / Advanced.
//

import Foundation
import IPTVModels
import RealmSwift

enum PlaylistLoadError: LocalizedError {
  case invalidURL

  var errorDescription: String? {
    "The Xtream server URL is not valid."
  }
}

struct XtreamCredentials {
  let host: String
  let username: String
  let password: String
}

enum PlaylistService {
  // MARK: - Full library load

  private static let loadConcurrency = 4

  @MainActor
  static func loadFullPlaylist(progress: (String) -> Void) async throws {
    progress("Checking playlist...")

    // These three must succeed (auth / connectivity). Everything below is
    // resilient — a single failing category is skipped, never aborts the load.
    let liveCategories = try await fetchCategories(action: "get_live_categories")
    let movieCategories = try await fetchCategories(action: "get_vod_categories")
    let seriesCategories = try await fetchCategories(action: "get_series_categories")

    clearCachedLibrary()

    // Live — one bulk call instead of one per category (793 → 1).
    await CacheManager.shared.cacheCategories(liveCategories, for: KindMedia.live.rawValue)
    progress("Loading Live…")
    let liveStreams = (try? await fetchAllStreams(action: "get_live_streams")) ?? []
    await cacheStreamsChunked(liveStreams, section: .live, label: "Live", progress: progress)

    // Movies — per-category in parallel. The full catalog can be hundreds of
    // thousands of items; decoding/storing it in per-category chunks avoids a
    // single massive decode while still loading everything for the Home rails.
    await CacheManager.shared.cacheCategories(movieCategories, for: KindMedia.vod.rawValue)
    await loadStreams(for: movieCategories, action: "get_vod_streams", section: .vod, label: "Movies", progress: progress)

    // Shows — try one bulk call first. Some Xtream providers do not support
    // bulk `get_series`, so fall back to category-by-category when needed.
    await CacheManager.shared.cacheCategories(seriesCategories, for: KindMedia.series.rawValue)
    progress("Loading Shows…")
    let allSeries = (try? await fetchAllSeries()) ?? []
    if allSeries.isEmpty {
      await loadSeries(for: seriesCategories, progress: progress)
    } else {
      await cacheSeriesChunked(allSeries, progress: progress)
    }
  }

  @MainActor
  private static func cacheStreamsChunked(
    _ streams: [IPTVModels.Stream],
    section: KindMedia,
    label: String,
    progress: (String) -> Void
  ) async {
    guard !streams.isEmpty else { return }
    var done = 0
    for chunk in streams.chunked(into: 1000) {
      CacheManager.shared.cacheStreams(chunk, for: section.rawValue)
      done += chunk.count
      progress("Loading \(label)… \(done.formatted())/\(streams.count.formatted())")
      await Task.yield()
    }
  }

  @MainActor
  private static func cacheSeriesChunked(_ series: [IPTVModels.Series], progress: (String) -> Void) async {
    guard !series.isEmpty else { return }
    var done = 0
    for chunk in series.chunked(into: 1000) {
      CacheManager.shared.cacheSeries(chunk, for: KindMedia.series.rawValue)
      done += chunk.count
      progress("Loading Shows… \(done.formatted())/\(series.count.formatted())")
      await Task.yield()
    }
  }

  /// Fetches each category's streams concurrently (bounded), caching as results
  /// arrive. Failed categories return empty and are simply skipped.
  @MainActor
  private static func loadStreams(
    for categories: [IPTVModels.Category],
    action: String,
    section: KindMedia,
    label: String,
    progress: (String) -> Void
  ) async {
    let ids = categories.map(\.id)
    guard !ids.isEmpty else { return }
    var done = 0

    for chunk in ids.chunked(into: loadConcurrency) {
      let batches = await withTaskGroup(of: [IPTVModels.Stream].self) { group -> [[IPTVModels.Stream]] in
        for id in chunk {
          group.addTask { (try? await fetchStreams(action: action, categoryId: id)) ?? [] }
        }
        var collected: [[IPTVModels.Stream]] = []
        for await streams in group { collected.append(streams) }
        return collected
      }

      for streams in batches where !streams.isEmpty {
        CacheManager.shared.cacheStreams(streams, for: section.rawValue)
        await Task.yield()
      }

      done += chunk.count
      progress("Loading \(label)… \(done)/\(ids.count)")
    }
  }

  @MainActor
  private static func loadSeries(for categories: [IPTVModels.Category], progress: (String) -> Void) async {
    let ids = categories.map(\.id)
    guard !ids.isEmpty else { return }
    var done = 0

    for chunk in ids.chunked(into: loadConcurrency) {
      let batches = await withTaskGroup(of: [IPTVModels.Series].self) { group -> [[IPTVModels.Series]] in
        for id in chunk {
          group.addTask { (try? await fetchSeries(categoryId: id)) ?? [] }
        }
        var collected: [[IPTVModels.Series]] = []
        for await series in group { collected.append(series) }
        return collected
      }

      for series in batches where !series.isEmpty {
        CacheManager.shared.cacheSeries(series, for: KindMedia.series.rawValue)
        await Task.yield()
      }

      done += chunk.count
      progress("Loading Shows… \(done)/\(ids.count)")
    }
  }

  static func refreshUserInfo() {
    APIManager.shared.fetchInfoUser(from: "\(APIManager.shared.baseURL)&action=get_infos") { result in
      switch result {
      case let .success(userInfo):
        UserDefaults.standard.set(userInfo.userInfo.expDate.formatted(), forKey: "expDate")
        UserDefaults.standard.set(userInfo.userInfo.status, forKey: "status")
        UserDefaults.standard.synchronize()
      case let .failure(failure):
        print(failure)
      }
    }
  }

  static func clearCachedLibrary() {
    do {
      let realm = try Realm()
      try realm.write {
        realm.delete(realm.objects(CategoryEntity.self))
        realm.delete(realm.objects(CachedStream.self))
        realm.delete(realm.objects(CachedSeries.self))
      }
    } catch {
      print("Error clearing library: \(error)")
    }
  }

  // MARK: - Credential parsing

  static func parseXtreamURL(_ value: String) -> XtreamCredentials? {
    let normalizedValue = value.contains("://") ? value : "http://\(value)"
    guard let components = URLComponents(string: normalizedValue),
          let scheme = components.scheme,
          let host = components.host
    else {
      return nil
    }

    let port = components.port.map { ":\($0)" } ?? ""
    let serverURL = "\(scheme)://\(host)\(port)"
    var username = queryValue(named: "username", in: components) ?? queryValue(named: "user", in: components) ?? ""
    var password = queryValue(named: "password", in: components) ?? queryValue(named: "pass", in: components) ?? ""

    if username.isEmpty || password.isEmpty {
      let pathParts = components.path.split(separator: "/").map(String.init)
      if pathParts.count >= 3, ["live", "movie", "series"].contains(pathParts[0].lowercased()) {
        username = pathParts[1]
        password = pathParts[2]
      } else if pathParts.count >= 2, !pathParts[0].hasSuffix(".php") {
        username = pathParts[0]
        password = pathParts[1]
      }
    }

    guard !username.isEmpty, !password.isEmpty else { return nil }
    return XtreamCredentials(host: serverURL, username: username, password: password)
  }

  static func normalizedServerURL(_ value: String) -> String {
    var normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if !normalizedValue.contains("://") {
      normalizedValue = "http://\(normalizedValue)"
    }
    while normalizedValue.hasSuffix("/") {
      normalizedValue.removeLast()
    }
    return normalizedValue
  }

  /// Strips the scheme/port for a compact, human-readable host summary.
  static func displayHost(_ value: String) -> String {
    var host = value
    if let range = host.range(of: "://") {
      host = String(host[range.upperBound...])
    }
    if let slash = host.firstIndex(of: "/") {
      host = String(host[..<slash])
    }
    if let colon = host.firstIndex(of: ":") {
      host = String(host[..<colon])
    }
    return host
  }

  // MARK: - Private API helpers

  private static func fetchCategories(action: String) async throws -> [IPTVModels.Category] {
    guard let url = URL(string: "\(APIManager.shared.baseURL)&action=\(action)") else {
      throw PlaylistLoadError.invalidURL
    }
    return try await withCheckedThrowingContinuation { continuation in
      APIManager.shared.fetchCategories(from: url) { result in
        continuation.resume(with: result)
      }
    }
  }

  private static func fetchStreams(action: String, categoryId: String) async throws -> [IPTVModels.Stream] {
    let apiURL = "\(APIManager.shared.baseURL)&action=\(action)&category_id=\(categoryId)"
    return try await withCheckedThrowingContinuation { continuation in
      APIManager.shared.fetchStreams(for: apiURL) { result in
        continuation.resume(with: result)
      }
    }
  }

  private static func fetchSeries(categoryId: String) async throws -> [IPTVModels.Series] {
    let apiURL = "\(APIManager.shared.baseURL)&action=get_series&category_id=\(categoryId)"
    return try await withCheckedThrowingContinuation { continuation in
      APIManager.shared.fetchSeries(for: apiURL) { result in
        continuation.resume(with: result)
      }
    }
  }

  private static func queryValue(named name: String, in components: URLComponents) -> String? {
    components.queryItems?
      .first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?
      .value
  }

  // MARK: - Bulk (no category_id) fetch with lossy decoding

  /// Fetches ALL streams for a content type in one request. Decodes leniently
  /// so a single malformed item in tens of thousands doesn't drop the whole list.
  private static func fetchAllStreams(action: String) async throws -> [IPTVModels.Stream] {
    let data = try await rawData(action: action)
    let items = try JSONDecoder().decode([FailableDecodable<IPTVModels.Stream>].self, from: data)
    return items.compactMap(\.value).filter { !$0.name.contains("#####") }
  }

  private static func fetchAllSeries() async throws -> [IPTVModels.Series] {
    let data = try await rawData(action: "get_series")
    let items = try JSONDecoder().decode([FailableDecodable<IPTVModels.Series>].self, from: data)
    return items.compactMap(\.value).filter { !$0.name.contains("#####") }
  }

  private static func rawData(action: String) async throws -> Data {
    guard let url = URL(string: "\(APIManager.shared.baseURL)&action=\(action)") else {
      throw PlaylistLoadError.invalidURL
    }
    return try await withCheckedThrowingContinuation { continuation in
      APIManager.shared.fetchData(from: url) { continuation.resume(with: $0) }
    }
  }
}

/// Decodes an element, yielding nil instead of throwing — lets a bulk array
/// decode skip malformed entries instead of failing entirely.
private struct FailableDecodable<T: Decodable>: Decodable {
  let value: T?

  init(from decoder: Decoder) throws {
    value = try? T(from: decoder)
  }
}
