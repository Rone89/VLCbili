import SwiftUI
import UIKit

struct MPVPlayerView: UIViewRepresentable {
    let source: PlayableVideoSource
    let playbackState: BilibiliVLCPlaybackState
    let commandCenter: BilibiliVLCCommandCenter
    let isFullscreen: Bool
    let fullscreenOrientation: UIDeviceOrientation

    func makeCoordinator() -> Coordinator {
        Coordinator(playbackState: playbackState, commandCenter: commandCenter)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        context.coordinator.updateTransform(
            for: view,
            isFullscreen: isFullscreen,
            orientation: fullscreenOrientation
        )
        context.coordinator.attach(to: view)
        context.coordinator.play(source: source)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.attach(to: uiView)
        context.coordinator.updateTransform(
            for: uiView,
            isFullscreen: isFullscreen,
            orientation: fullscreenOrientation
        )
        context.coordinator.play(source: source)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        private let player = MPVPlayerController()
        private var currentSource: PlayableVideoSource?
        private weak var playbackState: BilibiliVLCPlaybackState?
        private weak var commandCenter: BilibiliVLCCommandCenter?

        init(playbackState: BilibiliVLCPlaybackState, commandCenter: BilibiliVLCCommandCenter) {
            self.playbackState = playbackState
            self.commandCenter = commandCenter
            self.commandCenter?.togglePlayHandler = { [weak self] in
                self?.player.togglePlay()
            }
            self.commandCenter?.seekHandler = { [weak self] position in
                self?.player.seek(to: position)
            }
            self.commandCenter?.stopHandler = { [weak self] in
                self?.stop()
            }
            self.player.timeUpdateHandler = { [weak playbackState] current, total, isPlaying in
                guard let playbackState else { return }
                if !playbackState.isScrubbing, total.isFinite, total > 0 {
                    playbackState.position = max(0, min(1, current / total))
                }
                playbackState.elapsedText = BilibiliVLCVideoSurface.Coordinator.format(seconds: current)
                playbackState.durationText = BilibiliVLCVideoSurface.Coordinator.format(seconds: total)
                playbackState.isPlaying = isPlaying
            }
        }

        func attach(to view: UIView) {
            player.attach(to: view)
        }

        func play(source: PlayableVideoSource) {
            guard source != currentSource else { return }
            currentSource = source
            playbackState?.resetForNewMedia()
            player.play(source: source)
        }

        func stop() {
            player.stop()
        }

        func updateTransform(for view: UIView, isFullscreen: Bool, orientation: UIDeviceOrientation) {
            UIView.animate(withDuration: 0.25) {
                if isFullscreen {
                    view.transform = orientation == .landscapeLeft
                        ? CGAffineTransform(rotationAngle: .pi / 2)
                        : CGAffineTransform(rotationAngle: -.pi / 2)
                } else {
                    view.transform = .identity
                }
            }
        }
    }
}
