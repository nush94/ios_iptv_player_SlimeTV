# SlimeTV

SlimeTV is an iOS IPTV player for Xtream-compatible playlists. It supports Movies, Shows, Live TV, search, favorites, and VLC-based playback.

This repository is a modified fork of an open-source iOS IPTV player. The original project history credits Tarik ALAOUI M'HAMDI and other upstream contributors. This version has been customized with a new streaming-style interface, playlist setup flow, iOS signing/build fixes, and updated player controls.

## Important Notice

SlimeTV does not provide IPTV subscriptions, channels, movies, shows, streams, or playlist credentials. Users must provide their own lawful Xtream playlist access.

Do not use this app for piracy or unauthorized streaming.

## Current Features

- Movies, Shows, and Live TV browsing from an Xtream playlist
- First-time playlist setup prompt
- Settings screen for full playlist URL or manual server, username, and password entry
- Playlist loading for Live, Movies, and Shows
- Streaming-style top navigation
- Cleaner empty library states
- Favorites shelves when favorites exist
- Search across saved Movies, Live TV, and Shows
- VLC video playback
- Player controls for back, play/pause, 30-second skip, playback speed, video sizing, audio tracks, and subtitles
- iOS bundle/signing updates for local testing and TestFlight preparation

## Setup

1. Open `sources/IPTV.xcodeproj` in Xcode.
2. Select the `IPTV-iOS` scheme.
3. In Signing & Capabilities, select your Apple developer team.
4. Build and run on an iPhone simulator or device.
5. In the app, open Settings and add your Xtream playlist URL or server credentials.
6. Tap `Save & Load Playlist`.

## Dependencies

This project uses Swift Package Manager dependencies and MobileVLCKit via Carthage/XCFramework setup.

If VLC frameworks are missing, run:

```bash
carthage bootstrap --use-xcframeworks
```

The app has Google Cast code guarded so the project can build without `GoogleCast.xcframework`.

## Modified Fork Notice

This version includes substantial changes from the upstream project, including:

- Login gate removed for easier local testing
- English UI text updates
- Xtream playlist entry and parsing
- Local playlist loading into Realm cache
- Netflix/IPTVX-style top navigation
- New empty setup and empty library screens
- Cleaner shelf/category display
- Safer handling of missing Google Cast framework
- Player UI and playback settings improvements
- iOS device family and signing fixes

## License

This repository includes a `LICENSE` file containing the GNU General Public License version 3 (GPLv3). This modified version is distributed under GPLv3 as a covered/modified work.

If you distribute this app or a modified version, keep the GPLv3 license, keep attribution to upstream contributors, mark your changes, and provide the corresponding source code as required by GPLv3.
