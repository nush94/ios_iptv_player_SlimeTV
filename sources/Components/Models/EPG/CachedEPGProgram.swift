//
//  CachedEPGProgram.swift
//  IPTVLibrary
//

import Foundation
import RealmSwift

public class CachedEPGProgram: Object, ObjectKeyIdentifiable {
  @Persisted(primaryKey: true) public var id: String
  @Persisted public var streamId: Int
  @Persisted public var title: String
  @Persisted public var programDescription: String
  @Persisted public var startDate: Date
  @Persisted public var endDate: Date
  @Persisted public var fetchedAt: Date

  public convenience init(
    streamId: Int,
    title: String,
    programDescription: String,
    startDate: Date,
    endDate: Date,
    fetchedAt: Date = Date()
  ) {
    self.init()
    self.streamId = streamId
    self.title = title
    self.programDescription = programDescription
    self.startDate = startDate
    self.endDate = endDate
    self.fetchedAt = fetchedAt
    self.id = "\(streamId)-\(Int(startDate.timeIntervalSince1970))-\(Int(endDate.timeIntervalSince1970))"
  }
}

public struct ShortEPGResponse: Decodable {
  public let epgListings: [EPGListing]

  enum CodingKeys: String, CodingKey {
    case epgListings = "epg_listings"
  }
}

public struct EPGListing: Decodable {
  public let title: String?
  public let description: String?
  public let startTimestamp: String?
  public let stopTimestamp: String?
  public let start: String?
  public let end: String?

  enum CodingKeys: String, CodingKey {
    case title
    case description
    case startTimestamp = "start_timestamp"
    case stopTimestamp = "stop_timestamp"
    case start
    case end
  }

  public var decodedTitle: String {
    guard let title else { return "Untitled Program" }
    return decodedBase64(title) ?? title
  }

  public var decodedDescription: String {
    guard let description else { return "" }
    return decodedBase64(description) ?? description
  }

  public var startDate: Date? {
    date(fromTimestamp: startTimestamp) ?? date(fromText: start)
  }

  public var endDate: Date? {
    date(fromTimestamp: stopTimestamp) ?? date(fromText: end)
  }

  private func decodedBase64(_ value: String) -> String? {
    guard let data = Data(base64Encoded: value),
          let decoded = String(data: data, encoding: .utf8),
          !decoded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return nil
    }

    return decoded
  }

  private func date(fromTimestamp value: String?) -> Date? {
    guard let value,
          let seconds = TimeInterval(value)
    else {
      return nil
    }

    return Date(timeIntervalSince1970: seconds)
  }

  private func date(fromText value: String?) -> Date? {
    guard let value else { return nil }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.date(from: value)
  }
}
