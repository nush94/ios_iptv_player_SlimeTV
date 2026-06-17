import IPTVModels
import SwiftUI

struct PlaylistPlayerView: View {
    let channel: PlaylistChannel
    @Environment(\.dismiss) var dismiss

    private var kindMedia: KindMedia {
        KindMedia(rawValue: channel.kind) ?? .live
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let url = URL(string: channel.streamUrl) {
                VideoPlayerView(streamURL: url, id: 0, kind: kindMedia)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text("Invalid stream URL")
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
    }
}
