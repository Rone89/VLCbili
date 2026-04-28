import AVFoundation
import Foundation

/// Loads separate DASH video/audio resources and combines them into one AVPlayerItem.
///
/// Bilibili 1080P+ streams are usually DASH resources: video and audio are two
/// independent URLs. AVPlayer can play a single progressive URL directly, but it
/// cannot automatically discover and merge two unrelated URLs. This loader creates
/// two AVURLAssets with the same request headers, waits for their tracks to become
/// available, and inserts both tracks into an AVMutableComposition. The resulting
/// AVPlayerItem behaves like one media item while still letting AVFoundation load
/// the remote resources lazily.
struct DASHAssetLoader {
    enum LoaderError: LocalizedError {
        case missingVideoTrack
        case missingAudioTrack
        case missingDuration
        case cannotCreateVideoTrack
        case cannotCreateAudioTrack
        case insertFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingVideoTrack:
                return "DASH 视频轨加载失败"
            case .missingAudioTrack:
                return "DASH 音频轨加载失败"
            case .missingDuration:
                return "DASH 视频时长加载失败"
            case .cannotCreateVideoTrack:
                return "DASH 合成视频轨创建失败"
            case .cannotCreateAudioTrack:
                return "DASH 合成音频轨创建失败"
            case .insertFailed(let message):
                return "DASH 轨道合成失败：\(message)"
            }
        }
    }

    /// Creates a composed AVPlayerItem from separate DASH video/audio URLs.
    ///
    /// - Parameters:
    ///   - videoURL: Remote video-only DASH URL.
    ///   - audioURL: Remote audio-only DASH URL.
    ///   - headers: Request headers required by Bilibili CDN, such as Referer,
    ///     User-Agent and Cookie. They are injected into both AVURLAssets.
    /// - Returns: An AVPlayerItem backed by AVMutableComposition.
    func createPlayerItem(
        videoURL: URL,
        audioURL: URL,
        headers: [String: String]
    ) async throws -> AVPlayerItem {
        let assetOptions = Self.assetOptions(headers: headers)
        let videoAsset = AVURLAsset(url: videoURL, options: assetOptions)
        let audioAsset = AVURLAsset(url: audioURL, options: assetOptions)

        async let videoTrackTask = firstTrack(from: videoAsset, mediaType: .video)
        async let audioTrackTask = firstTrack(from: audioAsset, mediaType: .audio)
        async let durationTask = videoAsset.load(.duration)

        guard let videoTrack = try await videoTrackTask else {
            throw LoaderError.missingVideoTrack
        }
        guard let audioTrack = try await audioTrackTask else {
            throw LoaderError.missingAudioTrack
        }
        let duration = try await durationTask
        guard duration.isValid, duration.seconds.isFinite, duration > .zero else {
            throw LoaderError.missingDuration
        }

        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw LoaderError.cannotCreateVideoTrack
        }
        guard let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw LoaderError.cannotCreateAudioTrack
        }

        do {
            let videoRange = CMTimeRange(start: .zero, duration: duration)
            try compositionVideoTrack.insertTimeRange(videoRange, of: videoTrack, at: .zero)

            let audioTimeRange = try await audioTrack.load(.timeRange)
            let audioDuration = CMTimeMinimum(audioTimeRange.duration, duration)
            let audioRange = CMTimeRange(start: audioTimeRange.start, duration: audioDuration)
            try compositionAudioTrack.insertTimeRange(audioRange, of: audioTrack, at: .zero)
        } catch {
            throw LoaderError.insertFailed(error.localizedDescription)
        }

        compositionVideoTrack.preferredTransform = try await videoTrack.load(.preferredTransform)
        composition.naturalSize = try await videoTrack.load(.naturalSize)

        let item = AVPlayerItem(asset: composition)
        item.preferredForwardBufferDuration = 2
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        return item
    }

    private func firstTrack(from asset: AVURLAsset, mediaType: AVMediaType) async throws -> AVAssetTrack? {
        let tracks = try await asset.loadTracks(withMediaType: mediaType)
        return tracks.first
    }

    private static func assetOptions(headers: [String: String]) -> [String: Any] {
        var injectedHeaders = headers
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        if let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"], !cookieHeader.isEmpty {
            injectedHeaders["Cookie"] = cookieHeader
        }
        injectedHeaders["Accept"] = "*/*"
        injectedHeaders["Connection"] = "keep-alive"
        return ["AVURLAssetHTTPHeaderFieldsKey": injectedHeaders]
    }
}
