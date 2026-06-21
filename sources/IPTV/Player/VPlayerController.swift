//
//  PlayerController.swift
//  IPTV
//
//  Created by Tarik ALAOUI on 10/11/2024.
//

import AVFoundation
import AVKit
import UIKit
#if os(tvOS)
import TVVLCKit
#endif
#if os(iOS)
import MobileVLCKit
#endif
#if os(iOS) && canImport(GoogleCast)
import GoogleCast
#endif

import FontAwesome
import IPTVModels

class VPlayerController: UIViewController, VLCMediaPlayerDelegate, ObservableObject {
  var mediaPlayer = VLCMediaPlayer()

  @Published var currentTimeString: String = "00:00"
  @Published var videoLength: Int32 = 100 // setting some positive value to avoid div by zero and NAN exceptions
  @Published var videoCurrentTime: Int32 = 0
  @Published var percentagePlayedSoFar: Float = 0.0
  @Published var videoLengthString: String = "--:--"

  // UI Elements
  private let playPauseButton = UIButton(type: .system)
  private let forwardButton = UIButton(type: .system)
  private let rewindButton = UIButton(type: .system)
  private let closeButton = UIButton(type: .system)
  private let audioTrackButton = UIButton(type: .system)
  private let subtitlesButton = UIButton(type: .system)
  private let settingsButton = UIButton(type: .system)
#if os(iOS)
  private let airplayButton = AVRoutePickerView()
#endif

  private let progressLabel = UILabel()
  private let progressSlider = UISlider()
  private let videoContainerView = UIView(frame: .zero) // Conteneur pour la vidéo
  private let controlsContainerView = UIView() // Conteneur pour la vidéo
  private let backGround = UIView()
#if os(iOS) && canImport(GoogleCast)
  private let castButton = GCKUICastButton()
  private var sessionManager: GCKSessionManager {
    GCKCastContext.sharedInstance().sessionManager
  }

  private var mediaInformation: GCKMediaInformation?
#endif

  private enum Constants {
    static let fontSize: CGFloat = 14
  }

  private var controlsVisible = true
  private var hideControlsTimer: Timer?
  private var currentPlaybackRate: Float = 1.0
  private var currentVideoMode: VideoMode = .fit
  private var currentAspectRatioPointer: UnsafeMutablePointer<CChar>?
  private var isSeeking = false
  private var resumeTimeMilliseconds: Int32?
  /// When false (small inline preview), the transport control overlay is hidden.
  var showsControls = true
  private var didApplyResumeTime = false
  private var lastInlineVideoBounds: CGSize = .zero
  var onPlaybackProgress: ((Int32, Int32) -> Void)?

  private var playerTimeChangedNotification: NSObjectProtocol?
  private var playerStateChangedNotification: NSObjectProtocol?

  private var retryCount = 0
  private let maxRetries = 5

  // Source failover: ordered candidate URLs for the same channel/title.
  private var mediaURLs: [URL] = []
  private var currentSourceIndex = 0
  private var sourceWatchdog: Timer?
  private let sourceStartTimeout: TimeInterval = 12

  private lazy var sourceStatusLabel: UILabel = {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = .systemFont(ofSize: 14, weight: .semibold)
    label.textColor = .white
    label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    label.textAlignment = .center
    label.layer.cornerRadius = 16
    label.clipsToBounds = true
    label.alpha = 0
    return label
  }()

  private enum VideoMode: Equatable {
    case fit
    case fill
    case original

    var title: String {
      switch self {
      case .fit:
        return "Fit to Screen"
      case .fill:
        return "Fill Screen"
      case .original:
        return "Original Size"
      }
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.layoutMargins = .zero
    view.backgroundColor = .black
    configureAudioSession()
    DispatchQueue.main.async {
      self.setupBackground()
      self.setupPlayer()
      self.setupUI()
      self.setupActions()
      self.showControls()
      self.setupRemoteInteraction()
#if os(iOS) && canImport(GoogleCast)
      self.sessionManager.add(self)
#endif
    }
    playerStateChangedNotification = NotificationCenter.default.addObserver(
      forName: Notification.Name(rawValue: VLCMediaPlayerStateChanged),
      object: mediaPlayer,
      queue: nil,
      using: playerStateChanged
    )

    playerTimeChangedNotification = NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: VLCMediaPlayerTimeChanged), object: mediaPlayer, queue: nil, using: playerTimeChanged)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    guard !showsControls else { return }
    let bounds = videoContainerView.bounds.size
    guard bounds.width > 0, bounds.height > 0, bounds != lastInlineVideoBounds else { return }
    lastInlineVideoBounds = bounds
    setVideoMode(.fill)
  }

  private func configureAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Audio session setup failed: \(error)")
    }
  }

  func setupPlayer(
    with mediaURL: URL,
    id _: Int,
    kind _: KindMedia,
    fallbackURLs: [URL] = [],
    showsControls: Bool = true,
    resumeTimeMilliseconds: Int32? = nil,
    onPlaybackProgress: ((Int32, Int32) -> Void)? = nil
  ) {
    self.showsControls = showsControls
    self.resumeTimeMilliseconds = resumeTimeMilliseconds
    self.onPlaybackProgress = onPlaybackProgress

    // Build the ordered candidate list (the tapped source first, then backups),
    // de-duplicated while preserving order.
    var ordered: [URL] = []
    for url in [mediaURL] + fallbackURLs where !ordered.contains(url) {
      ordered.append(url)
    }
    mediaURLs = ordered
    currentSourceIndex = 0
    retryCount = 0

    playCurrentSource()
  }

  private func playCurrentSource() {
    guard currentSourceIndex < mediaURLs.count else { return }
    let url = mediaURLs[currentSourceIndex]

    let media = VLCMedia(url: url)
    media.addOptions([
      "file-caching": "3000",
      "live-caching": "1000",
      "network-caching": "3000",
      "http-reconnect": "1",
      "rtsp-caching": "3000",
    ])
    print("Playing source \(currentSourceIndex + 1)/\(mediaURLs.count): \(url)")

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.mediaPlayer.media = media
      self.mediaPlayer.play()
      self.mediaPlayer.perform(Selector(("setTextRendererFontSize:")), with: Constants.fontSize)
      self.startSourceWatchdog()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        self.applyResumeTimeIfNeeded()
      }
    }
  }

  func mediaPlayerStateChanged(_: Notification) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      switch mediaPlayer.state {
      case .playing:
        onSourcePlaying()
      case .stopped:
        print("Lecture arrêtée.")
      case .ended:
        reportPlaybackEnded()
        print("Lecture terminée.")
      case .error:
        print("Erreur détectée, basculement de source...")
        failover(reason: "error")
      default:
        break
      }
    }
  }

  // MARK: - Source failover

  /// A source started playing successfully — clear watchdog/status and reset retries.
  private func onSourcePlaying() {
    cancelSourceWatchdog()
    retryCount = 0
    hideSourceStatus()
  }

  /// The current source failed (error or never started). Move to the next
  /// candidate if one exists, otherwise retry the last one a few times.
  private func failover(reason: String) {
    cancelSourceWatchdog()

    if currentSourceIndex + 1 < mediaURLs.count {
      currentSourceIndex += 1
      print("Failover (\(reason)) -> source \(currentSourceIndex + 1)/\(mediaURLs.count)")
      showSourceStatus("Switching to source \(currentSourceIndex + 1)…")
      mediaPlayer.stop()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
        self?.playCurrentSource()
      }
      return
    }

    guard retryCount < maxRetries else {
      showSourceStatus("Stream unavailable", autoHide: false)
      return
    }
    retryCount += 1
    mediaPlayer.stop()
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
      self?.playCurrentSource()
    }
  }

  private func startSourceWatchdog() {
    sourceWatchdog?.invalidate()
    // Only watch for a stall if there is another source to fall back to.
    guard currentSourceIndex + 1 < mediaURLs.count else { return }
    sourceWatchdog = Timer.scheduledTimer(withTimeInterval: sourceStartTimeout, repeats: false) { [weak self] _ in
      guard let self else { return }
      if self.mediaPlayer.state != .playing {
        self.failover(reason: "timeout")
      }
    }
  }

  private func cancelSourceWatchdog() {
    sourceWatchdog?.invalidate()
    sourceWatchdog = nil
  }

  private func showSourceStatus(_ text: String, autoHide: Bool = true) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      if self.sourceStatusLabel.superview == nil {
        self.view.addSubview(self.sourceStatusLabel)
        NSLayoutConstraint.activate([
          self.sourceStatusLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
          self.sourceStatusLabel.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 16),
          self.sourceStatusLabel.heightAnchor.constraint(equalToConstant: 32),
        ])
      }
      self.sourceStatusLabel.text = "   \(text)   "
      self.view.bringSubviewToFront(self.sourceStatusLabel)
      UIView.animate(withDuration: 0.2) { self.sourceStatusLabel.alpha = 1 }
      if autoHide {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
          self?.hideSourceStatus()
        }
      }
    }
  }

  private func hideSourceStatus() {
    UIView.animate(withDuration: 0.25) { [weak self] in
      self?.sourceStatusLabel.alpha = 0
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    reportPlaybackProgress()
    mediaPlayer.stop()
    mediaPlayer.media = nil
    mediaPlayer.drawable = nil
    cancelSourceWatchdog()
    unregisterObservers()
  }

  deinit {
    if mediaPlayer.isPlaying {
      mediaPlayer.stop()
      mediaPlayer.media = nil
      mediaPlayer.drawable = nil
    }
    free(currentAspectRatioPointer)
  }

  func playerStateChanged(_: Notification) {
    guard let length = mediaPlayer.media?.length else { return }
    videoLength = length.intValue
    videoLengthString = length.stringValue
    DispatchQueue.main.async { [weak self] in
      self?.applyResumeTimeIfNeeded()
      self?.updateProgressSlider()
    }
  }

  func playerTimeChanged(_: Notification) {
    currentTimeString = mediaPlayer.time.stringValue
    videoCurrentTime = mediaPlayer.time.intValue
    percentagePlayedSoFar = Float(videoCurrentTime) / Float(videoLength)

    DispatchQueue.main.async { [weak self] in
      self?.progressLabel.text = String(format: "%@ / %@", self?.currentTimeString ?? "00:00", self?.videoLengthString ?? "00:00")
      self?.applyResumeTimeIfNeeded()
      self?.updateProgressSlider()
    }
  }

  func unregisterObservers() {
    NotificationCenter.default.removeObserver(playerTimeChangedNotification as Any)
    NotificationCenter.default.removeObserver(playerStateChangedNotification as Any)
  }

  private func setupBackground() {
    view.addSubview(backGround)
    backGround.translatesAutoresizingMaskIntoConstraints = false
    backGround.backgroundColor = .black
    backGround.isUserInteractionEnabled = false
    NSLayoutConstraint.activate([
      backGround.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      backGround.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      backGround.topAnchor.constraint(equalTo: view.topAnchor),
      backGround.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }

  // MARK: - Player Setup

  private func setupPlayer() {
    videoContainerView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(videoContainerView)
    controlsContainerView.backgroundColor = .black.withAlphaComponent(0.4)
    controlsContainerView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(controlsContainerView)

    mediaPlayer.setDeinterlaceFilter(nil)
    mediaPlayer.drawable = videoContainerView
    mediaPlayer.delegate = self

    NSLayoutConstraint.activate([
      videoContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
      videoContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
      videoContainerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
      videoContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
    ])
    videoContainerView.isUserInteractionEnabled = false
    videoContainerView.coverWholeSuperview()

    NSLayoutConstraint.activate([
      controlsContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      controlsContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      controlsContainerView.topAnchor.constraint(equalTo: view.topAnchor),
      controlsContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    controlsContainerView.isUserInteractionEnabled = true
  }

#if os(iOS) && canImport(GoogleCast)
  private func setupMediaCast(mediaURL: URL, id: Int, kind _: KindMedia) {
    GCKCastContext.sharedInstance().presentDefaultExpandedMediaControls()

    var metadata = GCKMediaMetadata()
    metadata.setString("Big Buck Bunny (2008)", forKey: kGCKMetadataKeyTitle)
    metadata.setString(
      "Big Buck Bunny tells the story of a giant rabbit with a heart bigger than " +
        "himself. When one sunny day three rodents rudely harass him, something " +
        "snaps... and the rabbit ain't no bunny anymore! In the typical cartoon " +
        "tradition he prepares the nasty rodents a comical revenge.",
      forKey: kGCKMetadataKeySubtitle
    )
    metadata.addImage(GCKImage(
      url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg")!,
      width: 480,
      height: 360
    ))

    /* Loading media to cast by creating a media request */
    let mediaInfoBuilder = GCKMediaInformationBuilder(contentURL: mediaURL)
    mediaInfoBuilder.contentID = String(id)
    mediaInfoBuilder.streamType = GCKMediaStreamType.none
    // mediaInfoBuilder.contentType = "video/mp4"
    mediaInfoBuilder.metadata = metadata
    mediaInformation = mediaInfoBuilder.build()

    /* Configuring the media request */
    let mediaLoadRequestDataBuilder = GCKMediaLoadRequestDataBuilder()
    mediaLoadRequestDataBuilder.mediaInformation = mediaInformation

    if let request = sessionManager.currentSession?.remoteMediaClient?.loadMedia(with: mediaLoadRequestDataBuilder.build()) {
      request.delegate = self
    }
  }
#endif

  // MARK: - UI Setup

  private func setupUI() {
    controlsContainerView.backgroundColor = .black.withAlphaComponent(0.18)

    configureGlassButton(closeButton, systemName: "chevron.backward", size: 52, pointSize: 23)
    configureGlassButton(settingsButton, systemName: "slider.horizontal.3", size: 52, pointSize: 22)
    configureGlassButton(rewindButton, systemName: "gobackward.30", size: 58, pointSize: 25)
    configureGlassButton(playPauseButton, systemName: "pause.fill", size: 70, pointSize: 30, backgroundAlpha: 0.82)
    configureGlassButton(forwardButton, systemName: "goforward.30", size: 58, pointSize: 25)
#if os(iOS) && canImport(GoogleCast)
    castButton.frame = CGRectMake(0, 0, 24, 24)
    castButton.tintColor = UIColor.gray
#endif
#if os(iOS)
    airplayButton.tintColor = .white
    airplayButton.activeTintColor = .systemRed
    airplayButton.prioritizesVideoDevices = true
    airplayButton.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      airplayButton.widthAnchor.constraint(equalToConstant: 30),
      airplayButton.heightAnchor.constraint(equalToConstant: 30),
    ])
#endif
    progressLabel.textAlignment = .center
    progressLabel.text = String(format: "%@ / %@", currentTimeString, videoLengthString)
    progressLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .medium)
    progressLabel.textColor = .white
    progressLabel.adjustsFontSizeToFitWidth = true
    progressLabel.minimumScaleFactor = 0.75
    progressLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    progressSlider.minimumValue = 0
    progressSlider.maximumValue = 1
    progressSlider.value = 0
    progressSlider.minimumTrackTintColor = .white
    progressSlider.maximumTrackTintColor = .white.withAlphaComponent(0.22)
    progressSlider.thumbTintColor = .white
    progressSlider.translatesAutoresizingMaskIntoConstraints = false
    progressSlider.isContinuous = true
    progressSlider.isEnabled = false

    // Configure AudioTrackButton
    configureGlassButton(audioTrackButton, systemName: "waveform", size: 48, pointSize: 20)

    // Configure SubtitlesButton
    configureGlassButton(subtitlesButton, systemName: "captions.bubble", size: 48, pointSize: 20)

    let spacer = UIView()

#if os(iOS) && canImport(GoogleCast)
    let stopStack = UIStackView(arrangedSubviews: [closeButton, progressLabel, spacer, airplayButton, settingsButton, castButton])
#elseif os(iOS)
    let stopStack = UIStackView(arrangedSubviews: [closeButton, progressLabel, spacer, airplayButton, settingsButton])
#endif
#if os(tvOS)
    let stopStack = UIStackView(arrangedSubviews: [closeButton, progressLabel, spacer, settingsButton])
#endif

    stopStack.axis = .horizontal
    stopStack.spacing = 12
    stopStack.alignment = .center
    stopStack.translatesAutoresizingMaskIntoConstraints = false

    controlsContainerView.addSubview(stopStack)

    NSLayoutConstraint.activate([
      stopStack.leadingAnchor.constraint(equalTo: controlsContainerView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
      stopStack.trailingAnchor.constraint(equalTo: controlsContainerView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
      stopStack.topAnchor.constraint(equalTo: controlsContainerView.safeAreaLayoutGuide.topAnchor, constant: 12),
    ])

    let controlsStack = UIStackView(arrangedSubviews: [rewindButton, playPauseButton, forwardButton])
    controlsStack.axis = .horizontal
    controlsStack.spacing = 30
    controlsStack.alignment = .bottom
    controlsStack.translatesAutoresizingMaskIntoConstraints = false

    controlsContainerView.addSubview(controlsStack)

    // Contrainte de la stack
    NSLayoutConstraint.activate([
      controlsStack.centerXAnchor.constraint(equalTo: controlsContainerView.centerXAnchor),
      controlsStack.bottomAnchor.constraint(equalTo: controlsContainerView.safeAreaLayoutGuide.bottomAnchor, constant: -40),
    ])

    controlsContainerView.addSubview(progressSlider)
    NSLayoutConstraint.activate([
      progressSlider.leadingAnchor.constraint(equalTo: controlsContainerView.safeAreaLayoutGuide.leadingAnchor, constant: 24),
      progressSlider.trailingAnchor.constraint(equalTo: controlsContainerView.safeAreaLayoutGuide.trailingAnchor, constant: -24),
      progressSlider.bottomAnchor.constraint(equalTo: controlsStack.topAnchor, constant: -36),
      progressSlider.heightAnchor.constraint(equalToConstant: 44),
    ])

    // Afficher les contrôles par défaut
    controlsContainerView.alpha = 1
    view.bringSubviewToFront(controlsContainerView)

    // Chromeless inline preview: hide the whole transport overlay.
    if !showsControls {
      controlsContainerView.isHidden = true
      controlsContainerView.isUserInteractionEnabled = false
    }
  }

  private func configureGlassButton(
    _ button: UIButton,
    systemName: String,
    size: CGFloat,
    pointSize: CGFloat,
    backgroundAlpha: CGFloat = 0.52
  ) {
    let image = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold))
    button.setImage(image, for: .normal)
    button.setTitle(nil, for: .normal)
    button.tintColor = .white
    button.backgroundColor = .black.withAlphaComponent(backgroundAlpha)
    button.layer.cornerRadius = size / 2
    button.layer.borderWidth = 1
    button.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
    button.clipsToBounds = true
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      button.widthAnchor.constraint(equalToConstant: size),
      button.heightAnchor.constraint(equalToConstant: size),
    ])
  }

  @objc private func selectAudioTrack() {
    guard let audioTracks = mediaPlayer.audioTrackNames as? [String] else { return }

    // Present an action sheet to select an audio track
    let alert = UIAlertController(title: "Select Audio Track", message: nil, preferredStyle: .actionSheet)
    for (index, trackName) in audioTracks.enumerated() {
      alert.addAction(UIAlertAction(title: trackName, style: .default, handler: { _ in
        self.mediaPlayer.currentAudioTrackIndex = Int32(index + 1)
      }))
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    presentActionSheet(alert, from: settingsButton)
  }

  @objc private func toggleSubtitles() {
    guard let subtitleTracks = mediaPlayer.videoSubTitlesNames as? [String] else { return }
    print(subtitleTracks)
    // Present an action sheet to enable/disable subtitles
    let alert = UIAlertController(title: "Subtitles", message: nil, preferredStyle: .actionSheet)
    alert.addAction(UIAlertAction(title: "Disable", style: .default, handler: { _ in
      self.mediaPlayer.currentVideoSubTitleIndex = -1
    }))
    for (index, trackName) in subtitleTracks.enumerated() {
      alert.addAction(UIAlertAction(title: trackName, style: .default, handler: { _ in
        self.mediaPlayer.currentVideoSubTitleIndex = Int32(index + 1)
      }))
    }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    presentActionSheet(alert, from: settingsButton)
  }

  @objc private func showPlaybackSettings() {
    let alert = UIAlertController(
      title: "Playback Settings",
      message: "Speed: \(formattedRate(currentPlaybackRate)) • Video: \(currentVideoMode.title)",
      preferredStyle: .actionSheet
    )

    let rates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    rates.forEach { rate in
      let title = rate == currentPlaybackRate ? "Speed \(formattedRate(rate)) ✓" : "Speed \(formattedRate(rate))"
      alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
        self?.setPlaybackRate(rate)
      })
    }

    alert.addAction(UIAlertAction(title: videoModeTitle(.fit), style: .default) { [weak self] _ in
      self?.setVideoMode(.fit)
    })
    alert.addAction(UIAlertAction(title: videoModeTitle(.fill), style: .default) { [weak self] _ in
      self?.setVideoMode(.fill)
    })
    alert.addAction(UIAlertAction(title: videoModeTitle(.original), style: .default) { [weak self] _ in
      self?.setVideoMode(.original)
    })

    if !mediaPlayer.audioTrackNames.isEmpty {
      alert.addAction(UIAlertAction(title: "Audio Track", style: .default) { [weak self] _ in
        self?.selectAudioTrack()
      })
    }

    if !mediaPlayer.videoSubTitlesNames.isEmpty {
      alert.addAction(UIAlertAction(title: "Subtitles", style: .default) { [weak self] _ in
        self?.toggleSubtitles()
      })
    }

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    presentActionSheet(alert, from: settingsButton)
    resetHideControlsTimer()
  }

  private func setPlaybackRate(_ rate: Float) {
    currentPlaybackRate = rate
    mediaPlayer.rate = rate
    resetHideControlsTimer()
  }

  private func setVideoMode(_ mode: VideoMode) {
    currentVideoMode = mode

    switch mode {
    case .fit:
      mediaPlayer.scaleFactor = 0
      setVideoAspectRatio(nil)
    case .fill:
      mediaPlayer.scaleFactor = 0
      let videoBounds = videoContainerView.bounds.size == .zero ? view.bounds.size : videoContainerView.bounds.size
      let width = max(Int(videoBounds.width.rounded()), 1)
      let height = max(Int(videoBounds.height.rounded()), 1)
      setVideoAspectRatio("\(width):\(height)")
    case .original:
      setVideoAspectRatio(nil)
      mediaPlayer.scaleFactor = 1
    }

    resetHideControlsTimer()
  }

  private func setVideoAspectRatio(_ ratio: String?) {
    let oldPointer = currentAspectRatioPointer
    currentAspectRatioPointer = ratio.flatMap { strdup($0) }
    mediaPlayer.videoAspectRatio = currentAspectRatioPointer
    free(oldPointer)
  }

  private func videoModeTitle(_ mode: VideoMode) -> String {
    mode == currentVideoMode ? "\(mode.title) ✓" : mode.title
  }

  private func formattedRate(_ rate: Float) -> String {
    rate.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(rate))x" : "\(rate)x"
  }

  private func presentActionSheet(_ alert: UIAlertController, from sourceView: UIView) {
    if let popover = alert.popoverPresentationController {
      popover.sourceView = sourceView
      popover.sourceRect = sourceView.bounds
    }
    present(alert, animated: true)
  }

  private func setupActions() {
    playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .primaryActionTriggered)
    forwardButton.addTarget(self, action: #selector(skipForward), for: .primaryActionTriggered)
    rewindButton.addTarget(self, action: #selector(skipBackward), for: .primaryActionTriggered)
    closeButton.addTarget(self, action: #selector(closeView), for: .primaryActionTriggered)
    audioTrackButton.addTarget(self, action: #selector(selectAudioTrack), for: .primaryActionTriggered)
    subtitlesButton.addTarget(self, action: #selector(toggleSubtitles), for: .primaryActionTriggered)
    settingsButton.addTarget(self, action: #selector(showPlaybackSettings), for: .primaryActionTriggered)
    progressSlider.addTarget(self, action: #selector(startSeeking), for: .touchDown)
    progressSlider.addTarget(self, action: #selector(updateSeekingPreview), for: .valueChanged)
    progressSlider.addTarget(self, action: #selector(finishSeeking), for: [.touchUpInside, .touchUpOutside, .touchCancel])
  }

  @objc
  private func closeView() {
    reportPlaybackProgress()
    if mediaPlayer.isPlaying {
      mediaPlayer.stop()
    }
    dismiss(animated: true)
  }

  // MARK: - Show/Hide Controls

  private func showControls() {
    guard showsControls else { return }
    controlsVisible = true
    UIView.animate(withDuration: 0.3) {
      self.controlsContainerView.alpha = 1
      self.playPauseButton.alpha = 1
      self.forwardButton.alpha = 1
      self.rewindButton.alpha = 1
      self.closeButton.alpha = 1
      self.settingsButton.alpha = 1
      self.progressLabel.alpha = 1
      self.progressSlider.alpha = 1

      if self.mediaPlayer.videoSubTitlesNames.isEmpty {
        self.subtitlesButton.alpha = 0
      } else {
        self.subtitlesButton.alpha = 1
      }
      if self.mediaPlayer.audioTrackNames.isEmpty {
        self.audioTrackButton.alpha = 0
      } else {
        self.audioTrackButton.alpha = 1
      }
    }
    resetHideControlsTimer()
  }

  private func hideControls() {
    controlsVisible = false
    UIView.animate(withDuration: 0.3) {
      self.controlsContainerView.alpha = 0
      self.playPauseButton.alpha = 0
      self.forwardButton.alpha = 0
      self.rewindButton.alpha = 0
      self.closeButton.alpha = 0
      self.settingsButton.alpha = 0
      self.progressLabel.alpha = 0
      self.progressSlider.alpha = 0
    }
  }

  private func setupRemoteInteraction() {
#if os(iOS)
    // Gestion des interactions tactiles sur iOS/iPadOS
    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(remoteInteraction))
    tapRecognizer.numberOfTapsRequired = 1
    tapRecognizer.cancelsTouchesInView = false
    videoContainerView.isUserInteractionEnabled = true
    videoContainerView.addGestureRecognizer(tapRecognizer)
#endif

#if os(tvOS)
    // Gestion des actions avec la télécommande sur tvOS
    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(remoteInteraction))
    tapRecognizer.allowedPressTypes = [
      NSNumber(value: UIPress.PressType.select.rawValue),
      NSNumber(value: UIPress.PressType.playPause.rawValue),
    ]
    view.isUserInteractionEnabled = true
    view.addGestureRecognizer(tapRecognizer)
#endif
  }

  @objc private func remoteInteraction() {
    print("tap detected \(controlsVisible)")
    if !controlsVisible {
      showControls()
    } else {
      hideControls()
    }
  }

  // MARK: - Player Actions

  @objc private func togglePlayPause() {
    if mediaPlayer.isPlaying {
      mediaPlayer.pause()
      playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)), for: .normal)
      playPauseButton.alpha = 1
      playPauseButton.tintColor = .white
    } else {
      mediaPlayer.play()
      playPauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .semibold)), for: .normal)
      playPauseButton.alpha = 1
      playPauseButton.tintColor = .white
    }
    resetHideControlsTimer()
  }

  @objc private func skipForward() {
    let currentTime = mediaPlayer.time.intValue
    guard let length = mediaPlayer.media?.length.intValue else { return }
    let newTime = min(currentTime + 30000, length) // Skip forward by 30 seconds
    mediaPlayer.time = VLCTime(int: newTime)
    resetHideControlsTimer()
  }

  @objc private func skipBackward() {
    let currentTime = mediaPlayer.time.intValue
    let newTime = max(currentTime - 30000, 0) // Skip backward by 30 seconds
    mediaPlayer.time = VLCTime(int: newTime)
    resetHideControlsTimer()
  }

  @objc private func startSeeking() {
    isSeeking = true
    hideControlsTimer?.invalidate()
  }

  @objc private func updateSeekingPreview() {
    guard let length = seekableLength else { return }
    let previewTime = Int32(progressSlider.value * Float(length))
    progressLabel.text = "\(VLCTime(int: previewTime).stringValue) / \(videoLengthString)"
  }

  @objc private func finishSeeking() {
    guard let length = seekableLength else {
      isSeeking = false
      resetHideControlsTimer()
      return
    }

    let newTime = Int32(progressSlider.value * Float(length))
    mediaPlayer.time = VLCTime(int: newTime)
    isSeeking = false
    updateProgressSlider()
    resetHideControlsTimer()
  }

  private func updateProgressSlider() {
    guard !isSeeking else { return }

    let length = max(videoLength, mediaPlayer.media?.length.intValue ?? 0)
    guard length > 0 else {
      progressSlider.value = 0
      progressSlider.isEnabled = false
      return
    }

    progressSlider.isEnabled = true
    progressSlider.value = min(max(Float(videoCurrentTime) / Float(length), 0), 1)
  }

  private var seekableLength: Int32? {
    let length = max(videoLength, mediaPlayer.media?.length.intValue ?? 0)
    return length > 0 ? length : nil
  }

  private func applyResumeTimeIfNeeded() {
    guard !didApplyResumeTime,
          let resumeTimeMilliseconds,
          let length = seekableLength,
          resumeTimeMilliseconds > 5_000,
          resumeTimeMilliseconds < length - 10_000 else { return }

    mediaPlayer.time = VLCTime(int: resumeTimeMilliseconds)
    videoCurrentTime = resumeTimeMilliseconds
    didApplyResumeTime = true
    updateProgressSlider()
  }

  private func reportPlaybackProgress() {
    let duration = max(videoLength, mediaPlayer.media?.length.intValue ?? 0)
    let progress = max(mediaPlayer.time.intValue, videoCurrentTime)
    guard progress > 0, duration > 0 else { return }
    onPlaybackProgress?(progress, duration)
  }

  private func reportPlaybackEnded() {
    let duration = max(videoLength, mediaPlayer.media?.length.intValue ?? 0)
    guard duration > 0 else {
      reportPlaybackProgress()
      return
    }

    onPlaybackProgress?(duration, duration)
  }

  private func resetHideControlsTimer() {
    hideControlsTimer?.invalidate()
    hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
      self?.hideControls()
    }
  }
}

#if os(iOS) && canImport(GoogleCast)
extension VPlayerController: GCKSessionManagerListener, GCKRemoteMediaClientListener, GCKRequestDelegate {
  // MARK: - GCKSessionManagerListener

  func sessionManager(_: GCKSessionManager, didStart session: GCKSession) {
    print("MediaViewController: sessionManager didStartSession \(session)")
    sessionManager.currentSession?.remoteMediaClient?.add(self)
  }

  func sessionManager(_: GCKSessionManager, didResumeSession session: GCKSession) {
    print("MediaViewController: sessionManager didResumeSession \(session)")
    sessionManager.currentSession?.remoteMediaClient?.add(self)
  }

  func sessionManager(_: GCKSessionManager, didEnd _: GCKSession, withError error: Error?) {
    print("session ended with error: \(String(describing: error))")
    let message = "The Casting session has ended.\n\(String(describing: error))"
    sessionManager.currentSession?.remoteMediaClient?.remove(self)
  }

  func sessionManager(_: GCKSessionManager, didFailToStartSessionWithError _: Error?) {
    sessionManager.currentSession?.remoteMediaClient?.remove(self)
  }

  func sessionManager(
    _: GCKSessionManager,
    didFailToResumeSession _: GCKSession,
    withError _: Error?
  ) {
    sessionManager.currentSession?.remoteMediaClient?.remove(self)
  }

  func remoteMediaClient(_: GCKRemoteMediaClient, didUpdate mediaStatus: GCKMediaStatus?) {
    if let mediaStatus {
      mediaInformation = mediaStatus.mediaInformation
    }
  }

  // MARK: - GCKRequestDelegate

  func requestDidComplete(_ request: GCKRequest) {
    print("request \(Int(request.requestID)) completed")
  }

  func request(_ request: GCKRequest, didFailWithError error: GCKError) {
    print("request \(Int(request.requestID)) failed with error \(error)")
  }
}
#endif
