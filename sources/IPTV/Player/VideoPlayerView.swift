//
//  VideoPlayerView.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 10/11/2024.
//

import AVKit
import IPTVModels
import SwiftUI

struct VideoPlayerView: UIViewControllerRepresentable {
  @State private var isPlaying: Bool = false
  let streamURL: URL
  let id: Int
  let kind: KindMedia
  let fallbackURLs: [URL]
  let resumeTimeMilliseconds: Int32?
  let onPlaybackProgress: ((Int32, Int32) -> Void)?

  init(
    streamURL: URL,
    id: Int,
    kind: KindMedia,
    fallbackURLs: [URL] = [],
    resumeTimeMilliseconds: Int32? = nil,
    onPlaybackProgress: ((Int32, Int32) -> Void)? = nil
  ) {
    self.streamURL = streamURL
    self.id = id
    self.kind = kind
    self.fallbackURLs = fallbackURLs
    self.resumeTimeMilliseconds = resumeTimeMilliseconds
    self.onPlaybackProgress = onPlaybackProgress
  }

  @MainActor
  func makeUIViewController(context _: Context) -> UIViewController {
    let controller = VPlayerController()
    controller.setupPlayer(
      with: streamURL,
      id: id,
      kind: kind,
      fallbackURLs: fallbackURLs,
      resumeTimeMilliseconds: resumeTimeMilliseconds,
      onPlaybackProgress: onPlaybackProgress
    )
    controller.modalPresentationStyle = .fullScreen
    controller.additionalSafeAreaInsets = .zero
    return controller
  }

  func updateUIViewController(_: VPlayerController, context _: Context) {
  }

  func updateUIViewController(_: UIViewController, context _: Context) {
  }

  func makeUIView(context _: Context) -> UIView {
    let view = UIView(frame: .zero)
    view.translatesAutoresizingMaskIntoConstraints = false
    view.backgroundColor = .black
    view.coverWholeSuperview()
    return view
  }
}
