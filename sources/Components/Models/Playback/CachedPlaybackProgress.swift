//
//  CachedPlaybackProgress.swift
//  IPTV
//

import Foundation
import RealmSwift

public class CachedPlaybackProgress: Object, ObjectKeyIdentifiable {
  @Persisted(primaryKey: true) public var id: String
  @Persisted public var mediaId: Int
  @Persisted public var kind: String
  @Persisted public var title: String
  @Persisted public var subtitle: String?
  @Persisted public var imageURL: String?
  @Persisted public var streamURL: String
  @Persisted public var progressMilliseconds: Int
  @Persisted public var durationMilliseconds: Int
  @Persisted public var seasonNumber: Int
  @Persisted public var episodeNumber: Int
  @Persisted public var updatedAt: Date

  public convenience init(
    mediaId: Int,
    kind: KindMedia,
    title: String,
    subtitle: String? = nil,
    imageURL: String? = nil,
    streamURL: String,
    progressMilliseconds: Int,
    durationMilliseconds: Int,
    seasonNumber: Int = 0,
    episodeNumber: Int = 0,
    updatedAt: Date = Date()
  ) {
    self.init()
    self.id = "\(kind.rawValue)-\(mediaId)"
    self.mediaId = mediaId
    self.kind = kind.rawValue
    self.title = title
    self.subtitle = subtitle
    self.imageURL = imageURL
    self.streamURL = streamURL
    self.progressMilliseconds = progressMilliseconds
    self.durationMilliseconds = durationMilliseconds
    self.seasonNumber = seasonNumber
    self.episodeNumber = episodeNumber
    self.updatedAt = updatedAt
  }

  public var percentComplete: Double {
    guard durationMilliseconds > 0 else { return 0 }
    return min(max(Double(progressMilliseconds) / Double(durationMilliseconds), 0), 1)
  }
}
