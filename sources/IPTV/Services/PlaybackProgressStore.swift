//
//  PlaybackProgressStore.swift
//  IPTV
//

import Foundation
import IPTVModels
import RealmSwift

struct PlaybackProgressContext: Identifiable, Equatable {
  let mediaId: Int
  let kind: KindMedia
  let title: String
  let subtitle: String?
  let imageURL: String?
  let streamURL: String
  let seasonNumber: Int
  let episodeNumber: Int

  var id: String {
    PlaybackProgressStore.id(for: mediaId, kind: kind)
  }

  init(
    mediaId: Int,
    kind: KindMedia,
    title: String,
    subtitle: String? = nil,
    imageURL: String? = nil,
    streamURL: String,
    seasonNumber: Int = 0,
    episodeNumber: Int = 0
  ) {
    self.mediaId = mediaId
    self.kind = kind
    self.title = title
    self.subtitle = subtitle
    self.imageURL = imageURL
    self.streamURL = streamURL
    self.seasonNumber = seasonNumber
    self.episodeNumber = episodeNumber
  }

  init(progress: CachedPlaybackProgress) {
    self.mediaId = progress.mediaId
    self.kind = KindMedia(rawValue: progress.kind) ?? .vod
    self.title = progress.title
    self.subtitle = progress.subtitle
    self.imageURL = progress.imageURL
    self.streamURL = progress.streamURL
    self.seasonNumber = progress.seasonNumber
    self.episodeNumber = progress.episodeNumber
  }
}

enum PlaybackProgressStore {
  static func id(for mediaId: Int, kind: KindMedia) -> String {
    "\(kind.rawValue)-\(mediaId)"
  }

  @MainActor
  static func resumeTimeMilliseconds(for mediaId: Int, kind: KindMedia) -> Int32? {
    guard let realm = try? Realm(),
          let progress = realm.object(
            ofType: CachedPlaybackProgress.self,
            forPrimaryKey: id(for: mediaId, kind: kind)
          ) else { return nil }

    let value = progress.progressMilliseconds
    guard value > 5_000, value < Int(Int32.max) else { return nil }
    return Int32(value)
  }

  @MainActor
  static func save(
    context: PlaybackProgressContext,
    progressMilliseconds: Int32,
    durationMilliseconds: Int32
  ) {
    guard context.kind == .vod || context.kind == .series else { return }

    let progress = max(Int(progressMilliseconds), 0)
    let duration = max(Int(durationMilliseconds), 0)
    guard duration > 60_000, progress > 10_000 else { return }

    if progress >= Int(Double(duration) * 0.92) || duration - progress < 60_000 {
      remove(mediaId: context.mediaId, kind: context.kind)
      return
    }

    do {
      let realm = try Realm()
      let item = CachedPlaybackProgress(
        mediaId: context.mediaId,
        kind: context.kind,
        title: context.title,
        subtitle: context.subtitle,
        imageURL: context.imageURL,
        streamURL: context.streamURL,
        progressMilliseconds: progress,
        durationMilliseconds: duration,
        seasonNumber: context.seasonNumber,
        episodeNumber: context.episodeNumber,
        updatedAt: Date()
      )

      try realm.write {
        realm.add(item, update: .modified)
      }
    } catch {
      print("Unable to save playback progress: \(error)")
    }
  }

  @MainActor
  static func remove(mediaId: Int, kind: KindMedia) {
    do {
      let realm = try Realm()
      guard let item = realm.object(
        ofType: CachedPlaybackProgress.self,
        forPrimaryKey: id(for: mediaId, kind: kind)
      ) else { return }

      try realm.write {
        realm.delete(item)
      }
    } catch {
      print("Unable to remove playback progress: \(error)")
    }
  }
}
