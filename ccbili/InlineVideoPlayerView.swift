import SwiftUI
import AVKit

struct InlineVideoPlayerView: View {
    let url: URL

    @State private var player = AVPlayer()

    var body: some View {
        VideoPlayer(player: player)
            .background(.black)
            .onAppear {
                let item = AVPlayerItem(url: url)
                player.replaceCurrentItem(with: item)
            }
            .onDisappear {
                player.pause()
                player.replaceCurrentItem(with: nil)
            }
    }
}
