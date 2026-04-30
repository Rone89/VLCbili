import AVFoundation
import AVKit
import MediaPlayer
import SwiftUI
import UIKit

struct AVFoundationDASHPlayerView: UIViewControllerRepresentable {
    let source: PlayableVideoSource
    let playbackState: BilibiliVLCPlaybackState
    let commandCenter: BilibiliVLCCommandCenter
    let onVideoSizeChange: (CGSize) -> Void

    init(
        source: PlayableVideoSource,
        playbackState: BilibiliVLCPlaybackState,
        commandCenter: BilibiliVLCCommandCenter,
        onVideoSizeChange: @escaping (CGSize) -> Void = { _ in }
    ) {
        self.source = source
        self.playbackState = playbackState
        self.commandCenter = commandCenter
        self.onVideoSizeChange = onVideoSizeChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            playbackState: playbackState,
            commandCenter: commandCenter,
            onVideoSizeChange: onVideoSizeChange
        )
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = LandscapeAVPlayerController()
        controller.player = context.coordinator.player
        controller.delegate = context.coordinator
        context.coordinator.attachInlineController(controller)
        context.coordinator.installOverlays(in: controller)
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = true
        controller.videoGravity = .resizeAspect
        context.coordinator.play(source: source)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.onVideoSizeChange = onVideoSizeChange
        if controller.player !== context.coordinator.player {
            controller.player = context.coordinator.player
        }
        context.coordinator.attachInlineController(controller)
        context.coordinator.installOverlays(in: controller)
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.videoGravity = .resizeAspect
        context.coordinator.play(source: source)
    }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        controller.delegate = nil
        coordinator.teardownPlayerController()
        coordinator.stop()
        AppOrientationController.lock(.portrait)
    }

    final class Coordinator: NSObject, AVPlayerViewControllerDelegate, UIGestureRecognizerDelegate {
        let player = AVPlayer()
        var onVideoSizeChange: (CGSize) -> Void
        private weak var playbackState: BilibiliVLCPlaybackState?
        private weak var commandCenter: BilibiliVLCCommandCenter?
        private var currentSource: PlayableVideoSource?
        private var loadTask: Task<Void, Never>?
        private var statusObserver: NSKeyValueObservation?
        private var videoBoundsObserver: NSKeyValueObservation?
        private var timeObserver: Any?
        private var shouldAutoplay = true
        private weak var inlinePlayerViewController: AVPlayerViewController?
        private weak var observedVideoBoundsController: AVPlayerViewController?
        private var danmakuHostingController: UIHostingController<PlayerDanmakuOverlayView>?
        private var gestureContainerView: PlayerGestureOverlayView?
        private var overlayConstraints: [NSLayoutConstraint] = []
        private var playbackRateBeforeFullscreen: Float = 1
        private var wasPlayingBeforeFullscreen = false
        private var isFullscreenActive = false
        private var longPressPlaybackRate: Float = 1
        private var wasPlayingBeforeLongPress = false
        private var panStartPosition: Double = 0
        private var panStartBrightness: CGFloat = 0
        private lazy var volumeController = PlayerSystemVolumeController()

        init(
            playbackState: BilibiliVLCPlaybackState,
            commandCenter: BilibiliVLCCommandCenter,
            onVideoSizeChange: @escaping (CGSize) -> Void
        ) {
            self.playbackState = playbackState
            self.commandCenter = commandCenter
            self.onVideoSizeChange = onVideoSizeChange
            super.init()
            bindCommands()
        }

        deinit {
            teardownPlayerController()
            removeTimeObserver()
        }

        func play(source: PlayableVideoSource) {
            guard source != currentSource else { return }
            currentSource = source
            shouldAutoplay = true
            loadTask?.cancel()
            statusObserver?.invalidate()
            statusObserver = nil
            removeTimeObserver()
            playbackState?.resetForNewMedia()
            player.pause()
            player.replaceCurrentItem(with: nil)

            loadTask = Task { [weak self] in
                await self?.loadAndPlay(source: source)
            }
        }

        func stop() {
            loadTask?.cancel()
            statusObserver?.invalidate()
            statusObserver = nil
            videoBoundsObserver?.invalidate()
            videoBoundsObserver = nil
            removeTimeObserver()
            player.pause()
            player.replaceCurrentItem(with: nil)
            currentSource = nil
        }

        func attachInlineController(_ controller: AVPlayerViewController) {
            inlinePlayerViewController = controller
            if controller.player !== player {
                controller.player = player
            }
        }

        func installOverlays(in controller: AVPlayerViewController) {
            guard let contentOverlayView = controller.contentOverlayView else { return }

            if danmakuHostingController?.view.superview !== contentOverlayView {
                danmakuHostingController?.willMove(toParent: nil)
                danmakuHostingController?.view.removeFromSuperview()
                danmakuHostingController?.removeFromParent()

                let hostingController = UIHostingController(
                    rootView: PlayerDanmakuOverlayView(videoBounds: controller.videoBounds, isFullscreen: false)
                )
                hostingController.view.backgroundColor = .clear
                hostingController.view.translatesAutoresizingMaskIntoConstraints = false
                controller.addChild(hostingController)
                contentOverlayView.addSubview(hostingController.view)
                hostingController.didMove(toParent: controller)
                danmakuHostingController = hostingController
            }

            if gestureContainerView?.superview !== contentOverlayView {
                gestureContainerView?.removeFromSuperview()

                let gestureView = PlayerGestureOverlayView()
                gestureView.translatesAutoresizingMaskIntoConstraints = false
                contentOverlayView.addSubview(gestureView)
                installGestures(on: gestureView)
                volumeController.attach(to: gestureView)
                gestureContainerView = gestureView
            }

            NSLayoutConstraint.deactivate(overlayConstraints)
            overlayConstraints = [danmakuHostingController?.view, gestureContainerView].compactMap { $0 }.flatMap { overlayView in
                [
                    overlayView.topAnchor.constraint(equalTo: contentOverlayView.topAnchor),
                    overlayView.bottomAnchor.constraint(equalTo: contentOverlayView.bottomAnchor),
                    overlayView.leadingAnchor.constraint(equalTo: contentOverlayView.leadingAnchor),
                    overlayView.trailingAnchor.constraint(equalTo: contentOverlayView.trailingAnchor)
                ]
            }
            NSLayoutConstraint.activate(overlayConstraints)

            observeVideoBounds(on: controller)
            updateOverlayVideoBounds(controller.videoBounds, isFullscreen: isFullscreenActive)
        }

        func teardownPlayerController() {
            videoBoundsObserver?.invalidate()
            videoBoundsObserver = nil
            observedVideoBoundsController = nil
            NSLayoutConstraint.deactivate(overlayConstraints)
            overlayConstraints = []
            volumeController.detach()
            gestureContainerView?.removeFromSuperview()
            gestureContainerView = nil
            danmakuHostingController?.willMove(toParent: nil)
            danmakuHostingController?.view.removeFromSuperview()
            danmakuHostingController?.removeFromParent()
            danmakuHostingController = nil
        }

        private func bindCommands() {
            commandCenter?.togglePlayHandler = { [weak self] in
                guard let self else { return }
                if self.player.timeControlStatus == .playing {
                    self.player.pause()
                    self.shouldAutoplay = false
                } else {
                    self.shouldAutoplay = true
                    self.player.play()
                }
                self.updatePlaybackState()
            }

            commandCenter?.playHandler = { [weak self] in
                guard let self else { return }
                self.shouldAutoplay = true
                self.player.play()
                self.updatePlaybackState()
            }

            commandCenter?.pauseHandler = { [weak self] in
                guard let self else { return }
                self.shouldAutoplay = false
                self.player.pause()
                self.updatePlaybackState()
            }

            commandCenter?.seekHandler = { [weak self] position, resumePlayback in
                guard let self, let item = self.player.currentItem else { return }
                let duration = item.duration
                guard duration.isValid, duration.isNumeric, duration.seconds > 0 else { return }
                let target = CMTime(seconds: duration.seconds * min(max(position, 0), 1), preferredTimescale: 600)
                self.player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                    guard let self else { return }
                    if resumePlayback {
                        self.shouldAutoplay = true
                        self.player.play()
                    }
                    self.playbackState?.pendingSeekPosition = nil
                    self.updatePlaybackState()
                }
            }

            commandCenter?.stopHandler = { [weak self] in
                self?.stop()
            }

        }

        private func installGestures(on view: PlayerGestureOverlayView) {
            view.gestureRecognizers?.forEach(view.removeGestureRecognizer)
            view.backgroundColor = .clear

            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            doubleTap.cancelsTouchesInView = false
            doubleTap.delegate = self
            view.addGestureRecognizer(doubleTap)

            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.35
            longPress.cancelsTouchesInView = false
            longPress.delegate = self
            view.addGestureRecognizer(longPress)

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.maximumNumberOfTouches = 1
            pan.cancelsTouchesInView = false
            pan.delegate = self
            view.addGestureRecognizer(pan)
        }

        @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            commandCenter?.togglePlay()
        }

        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            switch gesture.state {
            case .began:
                wasPlayingBeforeLongPress = player.rate > 0 || player.timeControlStatus == .playing
                longPressPlaybackRate = player.rate > 0 ? player.rate : 1
                player.rate = 2
            case .ended, .cancelled, .failed:
                if wasPlayingBeforeLongPress {
                    player.rate = longPressPlaybackRate
                } else {
                    player.pause()
                }
            default:
                break
            }
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let targetView = gesture.view,
                  let item = player.currentItem else { return }

            let location = gesture.location(in: targetView)
            let translation = gesture.translation(in: targetView)

            switch gesture.state {
            case .began:
                panStartPosition = playbackState?.position ?? 0
                panStartBrightness = UIScreen.main.brightness
            case .changed:
                if abs(translation.x) > abs(translation.y) {
                    let delta = translation.x / max(targetView.bounds.width, 1)
                    playbackState?.pendingSeekPosition = min(max(panStartPosition + delta, 0), 1)
                    updatePlaybackState()
                } else if location.x < targetView.bounds.midX {
                    let brightness = panStartBrightness - translation.y / max(targetView.bounds.height, 1)
                    UIScreen.main.brightness = min(max(brightness, 0), 1)
                } else {
                    volumeController.changeVolume(by: Float(-translation.y / max(targetView.bounds.height, 1)))
                    gesture.setTranslation(.zero, in: targetView)
                }
            case .ended, .cancelled:
                guard let pendingSeekPosition = playbackState?.pendingSeekPosition else { return }
                let duration = item.duration
                guard duration.isValid, duration.isNumeric, duration.seconds > 0 else { return }
                let target = CMTime(seconds: duration.seconds * min(max(pendingSeekPosition, 0), 1), preferredTimescale: 600)
                let shouldResume = player.timeControlStatus == .playing
                player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                    guard let self else { return }
                    self.playbackState?.pendingSeekPosition = nil
                    if shouldResume {
                        self.player.play()
                    }
                    self.updatePlaybackState()
                }
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
        ) {
            playbackRateBeforeFullscreen = player.rate > 0 ? player.rate : 1
            wasPlayingBeforeFullscreen = player.rate > 0 || player.timeControlStatus == .playing || shouldAutoplay
            isFullscreenActive = true
            AppOrientationController.lock(.landscape, scene: playerViewController.view.window?.windowScene)
            coordinator.animate { [weak self, weak playerViewController] _ in
                guard let self, let playerViewController else { return }
                self.updateOverlayVideoBounds(playerViewController.videoBounds, isFullscreen: true)
            } completion: { [weak self, weak playerViewController] _ in
                guard let self, let playerViewController else { return }
                self.restorePlaybackAfterFullscreenTransition()
                self.updateOverlayVideoBounds(playerViewController.videoBounds, isFullscreen: true)
            }
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
        ) {
            playbackRateBeforeFullscreen = player.rate > 0 ? player.rate : 1
            wasPlayingBeforeFullscreen = player.rate > 0 || player.timeControlStatus == .playing || shouldAutoplay
            coordinator.animate { [weak self, weak playerViewController] _ in
                guard let self, let playerViewController else { return }
                self.updateOverlayVideoBounds(playerViewController.videoBounds, isFullscreen: false)
            } completion: { [weak self, weak playerViewController] _ in
                guard let self, let playerViewController else { return }
                self.isFullscreenActive = false
                AppOrientationController.lock(.portrait, scene: playerViewController.view.window?.windowScene)
                self.restorePlaybackAfterFullscreenTransition()
                self.updateOverlayVideoBounds(playerViewController.videoBounds, isFullscreen: false)
            }
        }

        private func restorePlaybackAfterFullscreenTransition() {
            if wasPlayingBeforeFullscreen {
                player.rate = playbackRateBeforeFullscreen
            } else {
                player.pause()
            }
            updatePlaybackState()
        }

        private func observeVideoBounds(on controller: AVPlayerViewController) {
            guard videoBoundsObserver == nil || observedVideoBoundsController !== controller else { return }
            videoBoundsObserver?.invalidate()
            observedVideoBoundsController = controller
            videoBoundsObserver = controller.observe(\.videoBounds, options: [.initial, .new]) { [weak self] controller, _ in
                DispatchQueue.main.async {
                    self?.updateOverlayVideoBounds(
                        controller.videoBounds,
                        isFullscreen: self?.isFullscreenActive == true
                    )
                }
            }
        }

        private func updateOverlayVideoBounds(_ videoBounds: CGRect, isFullscreen: Bool) {
            guard let contentOverlayView = inlinePlayerViewController?.contentOverlayView else { return }
            let convertedBounds: CGRect
            if videoBounds == .zero {
                convertedBounds = contentOverlayView.bounds
            } else {
                convertedBounds = contentOverlayView.convert(videoBounds, from: inlinePlayerViewController?.view)
            }

            danmakuHostingController?.rootView = PlayerDanmakuOverlayView(
                videoBounds: convertedBounds,
                isFullscreen: isFullscreen
            )
            gestureContainerView?.videoBounds = convertedBounds
        }

        private func loadAndPlay(source: PlayableVideoSource) async {
            configureAudioSession()

            if source.isDASHSeparated {
                do {
                    HLSPlaybackDiagnostics.shared.reset()
                    let manifestURL = try await DashHLSManifestService().makeManifest(for: source)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        let item = AVPlayerItem(url: manifestURL)
                        item.preferredForwardBufferDuration = 3
                        self.player.automaticallyWaitsToMinimizeStalling = true
                        self.observe(item: item)
                        self.player.replaceCurrentItem(with: item)
                        self.addTimeObserver()
                        self.updatePlaybackState()
                        self.playWhenReady(item: item)
                    }
                    return
                } catch {
                    print("DASH to HLS load failed: \(error.localizedDescription)")
                }
            }

            guard let audioURL = source.audioURL else {
                await loadSingleURL(source: source)
                return
            }

            do {
                let item = try await makePlayerItem(videoURL: source.url, audioURL: audioURL, headers: source.headers)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.player.automaticallyWaitsToMinimizeStalling = true
                    self.observe(item: item)
                    self.player.replaceCurrentItem(with: item)
                    self.addTimeObserver()
                    self.updatePlaybackState()
                    self.playWhenReady(item: item)
                }
            } catch {
                print("AVFoundation DASH load failed: \(error.localizedDescription)")
            }
        }

        private func loadSingleURL(source: PlayableVideoSource) async {
            let asset = AVURLAsset(url: source.url, options: assetOptions(headers: source.headers))
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 3

            await MainActor.run {
                self.player.automaticallyWaitsToMinimizeStalling = true
                self.observe(item: item)
                self.player.replaceCurrentItem(with: item)
                self.addTimeObserver()
                self.updatePlaybackState()
                self.playWhenReady(item: item)
            }
        }

        private func observe(item: AVPlayerItem) {
            statusObserver?.invalidate()
            statusObserver = item.observe(\.status, options: [.new]) { item, _ in
                switch item.status {
                case .readyToPlay:
                    HLSPlaybackDiagnostics.shared.recordPlayerStatus("ready")
                    self.updateVideoSize(for: item)
                    if self.shouldAutoplay {
                        self.player.play()
                    }
                    self.updatePlaybackState()
                case .failed:
                    HLSPlaybackDiagnostics.shared.recordPlayerStatus("failed:\(item.error?.localizedDescription ?? "unknown")")
                case .unknown:
                    HLSPlaybackDiagnostics.shared.recordPlayerStatus("unknown")
                @unknown default:
                    HLSPlaybackDiagnostics.shared.recordPlayerStatus("other")
                }
            }
        }

        private func updateVideoSize(for item: AVPlayerItem) {
            guard let videoTrack = item.tracks
                .compactMap({ $0.assetTrack })
                .first(where: { $0.mediaType == .video }) else {
                return
            }

            let transformedSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
            let videoSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))

            guard videoSize.width > 0, videoSize.height > 0 else {
                return
            }

            DispatchQueue.main.async {
                self.onVideoSizeChange(videoSize)
            }
        }

        private func playWhenReady(item: AVPlayerItem) {
            shouldAutoplay = true
            player.play()
            if item.status != .readyToPlay {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self, weak item] in
                    guard let self, self.shouldAutoplay, item === self.player.currentItem else { return }
                    self.player.play()
                    self.updatePlaybackState()
                }
            }
        }

        private func addTimeObserver() {
            removeTimeObserver()
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 1, preferredTimescale: 600),
                queue: .main
            ) { [weak self] _ in
                self?.updatePlaybackState()
            }
        }

        private func removeTimeObserver() {
            if let timeObserver {
                player.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }
        }

        private func updatePlaybackState() {
            guard let playbackState else { return }
            let current = player.currentTime()
            let duration = player.currentItem?.duration ?? .invalid
            let isPlaying = player.timeControlStatus == .playing
            DispatchQueue.main.async {
                guard duration.isValid, duration.isNumeric, duration.seconds > 0 else {
                    playbackState.updatePlayback(
                        position: nil,
                        elapsedText: Self.timeText(current.seconds),
                        durationText: "00:00",
                        isPlaying: isPlaying
                    )
                    return
                }
                let position: Double?
                if let pendingSeekPosition = playbackState.pendingSeekPosition {
                    position = pendingSeekPosition
                } else if !playbackState.isScrubbing {
                    position = min(max(current.seconds / duration.seconds, 0), 1)
                } else {
                    position = nil
                }
                playbackState.updatePlayback(
                    position: position,
                    elapsedText: Self.timeText(current.seconds),
                    durationText: Self.timeText(duration.seconds),
                    isPlaying: isPlaying
                )
            }
        }

        private static func timeText(_ seconds: Double) -> String {
            guard seconds.isFinite, seconds >= 0 else { return "00:00" }
            let totalSeconds = Int(seconds.rounded(.down))
            let minutes = totalSeconds / 60
            let remainingSeconds = totalSeconds % 60
            return String(format: "%02d:%02d", minutes, remainingSeconds)
        }

        private func configureAudioSession() {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .moviePlayback, options: [])
                try session.setActive(true)
            } catch {
                print("Failed to configure AVFoundation DASH audio session: \(error.localizedDescription)")
            }
        }

        private func makePlayerItem(videoURL: URL, audioURL: URL, headers: [String: String]) async throws -> AVPlayerItem {
            let options = assetOptions(headers: headers)
            let videoAsset = AVURLAsset(url: videoURL, options: options)
            let audioAsset = AVURLAsset(url: audioURL, options: options)

            let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
            let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
            guard let videoTrack = videoTracks.first else {
                throw AVFoundationDASHError.missingVideoTrack
            }
            guard let audioTrack = audioTracks.first else {
                throw AVFoundationDASHError.missingAudioTrack
            }

            let duration = try await videoAsset.load(.duration)
            let composition = AVMutableComposition()
            guard let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw AVFoundationDASHError.cannotCreateCompositionTrack
            }
            try compositionVideoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: videoTrack,
                at: .zero
            )
            compositionVideoTrack.preferredTransform = try await videoTrack.load(.preferredTransform)

            if let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                let audioDuration = try await audioAsset.load(.duration)
                let targetDuration = min(duration, audioDuration)
                try compositionAudioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: targetDuration),
                    of: audioTrack,
                    at: .zero
                )
            }

            let item = AVPlayerItem(asset: composition)
            item.preferredForwardBufferDuration = 3
            return item
        }

        private func assetOptions(headers: [String: String]) -> [String: Any] {
            var enrichedHeaders = headers
            if let cookieHeader = BilibiliCookieStore.cookieHeader() {
                enrichedHeaders["Cookie"] = cookieHeader
            }
            enrichedHeaders["Accept"] = "*/*"
            enrichedHeaders["Connection"] = "keep-alive"
            return ["AVURLAssetHTTPHeaderFieldsKey": enrichedHeaders]
        }
    }
}

final class LandscapeAVPlayerController: AVPlayerViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        [.portrait, .landscapeLeft, .landscapeRight]
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .landscapeLeft
    }

    override var shouldAutorotate: Bool {
        true
    }
}

private struct PlayerDanmakuOverlayView: View {
    let videoBounds: CGRect
    let isFullscreen: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.clear

                Color.clear
                    .frame(
                        width: max(videoBounds.width, 0),
                        height: max(videoBounds.height, 0)
                    )
                    .position(
                        x: min(max(videoBounds.midX, 0), proxy.size.width),
                        y: min(max(videoBounds.midY, 0), proxy.size.height)
                    )
            }
            .allowsHitTesting(false)
        }
    }
}

private final class PlayerGestureOverlayView: UIView {
    var videoBounds: CGRect = .zero

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard videoBounds != .zero else {
            return false
        }
        return videoBounds.contains(point)
    }
}

private final class PlayerSystemVolumeController {
    private let volumeView = MPVolumeView(frame: .zero)
    private weak var volumeSlider: UISlider?
    private var currentVolume: Float {
        AVAudioSession.sharedInstance().outputVolume
    }

    init() {
        volumeView.alpha = 0.01
        volumeView.isUserInteractionEnabled = false
        volumeSlider = volumeView.subviews.compactMap { $0 as? UISlider }.first
    }

    func attach(to view: UIView) {
        guard volumeView.superview !== view else { return }
        volumeView.removeFromSuperview()
        volumeView.frame = CGRect(x: -100, y: -100, width: 1, height: 1)
        view.addSubview(volumeView)
        volumeSlider = volumeView.subviews.compactMap { $0 as? UISlider }.first
    }

    func detach() {
        volumeView.removeFromSuperview()
    }

    func changeVolume(by delta: Float) {
        let targetVolume = min(max(currentVolume + delta, 0), 1)
        volumeSlider?.setValue(targetVolume, animated: false)
        volumeSlider?.sendActions(for: .valueChanged)
    }
}

enum AVFoundationDASHError: Error {
    case missingVideoTrack
    case missingAudioTrack
    case cannotCreateCompositionTrack
}
