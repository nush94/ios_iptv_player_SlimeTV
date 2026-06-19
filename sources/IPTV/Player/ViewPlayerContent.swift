//
//  ViewPlayerContent.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 10/11/2024.
//
import Foundation
import IPTVModels
import SwiftUI

struct ViewPlayerContent: View {
  @State private var isPlaying: Bool = false
  @State private var mediaURL: URL
  @State private var id: Int
  @State private var kind: KindMedia
  private let fallbackURLs: [URL]
  private let playbackContext: PlaybackProgressContext?

  public init(
    mediaURL: URL,
    id: Int,
    kind: KindMedia,
    fallbackURLs: [URL] = [],
    playbackContext: PlaybackProgressContext? = nil
  ) {
    self.mediaURL = mediaURL
    self.id = id
    self.kind = kind
    self.fallbackURLs = fallbackURLs
    self.playbackContext = playbackContext
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      VideoPlayerView(
        streamURL: mediaURL,
        id: id,
        kind: kind,
        fallbackURLs: fallbackURLs,
        resumeTimeMilliseconds: PlaybackProgressStore.resumeTimeMilliseconds(for: id, kind: kind),
        onPlaybackProgress: savePlaybackProgress
      )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .all)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ignoresSafeArea(edges: .all)
    .background(.black)
  }

  private func savePlaybackProgress(progressMilliseconds: Int32, durationMilliseconds: Int32) {
    guard let playbackContext else { return }
    Task { @MainActor in
      PlaybackProgressStore.save(
        context: playbackContext,
        progressMilliseconds: progressMilliseconds,
        durationMilliseconds: durationMilliseconds
      )
    }
  }
}
