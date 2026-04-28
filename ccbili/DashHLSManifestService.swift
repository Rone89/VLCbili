import Foundation

struct DashHLSManifestService {
    func makeManifest(for source: PlayableVideoSource) throws -> URL {
        guard let audioURL = source.audioURL,
              let duration = source.duration,
              let videoInitRange = byteRange(from: source.videoInitRange),
              let audioInitRange = byteRange(from: source.audioInitRange) else {
            throw APIError.serverMessage("DASH HLS 清单信息不完整")
        }

        let directory = try workingDirectory(bvid: source.bvid, cid: source.cid, quality: source.quality)
        let videoPlaylistURL = directory.appendingPathComponent("video.m3u8")
        let audioPlaylistURL = directory.appendingPathComponent("audio.m3u8")
        let masterURL = directory.appendingPathComponent("master.m3u8")
        let durationText = String(format: "%.3f", max(duration, 0.001))

        try mediaPlaylist(
            mediaURL: source.url,
            initRange: videoInitRange,
            durationText: durationText
        ).write(to: videoPlaylistURL, atomically: true, encoding: .utf8)

        try mediaPlaylist(
            mediaURL: audioURL,
            initRange: audioInitRange,
            durationText: durationText
        ).write(to: audioPlaylistURL, atomically: true, encoding: .utf8)

        try masterPlaylist(
            source: source,
            videoPlaylistURL: videoPlaylistURL,
            audioPlaylistURL: audioPlaylistURL
        ).write(to: masterURL, atomically: true, encoding: .utf8)

        return masterURL
    }

    private func workingDirectory(bvid: String, cid: Int, quality: Int?) throws -> URL {
        let qualityValue = quality.map(String.init) ?? "auto"
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = caches
            .appendingPathComponent("DashHLS", isDirectory: true)
            .appendingPathComponent("\(bvid)-\(cid)-\(qualityValue)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func mediaPlaylist(mediaURL: URL, initRange: ByteRange, durationText: String) -> String {
        let escapedURL = mediaURL.absoluteString.replacingOccurrences(of: "\"", with: "%22")
        return """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXT-X-TARGETDURATION:\(Int(ceil(Double(durationText) ?? 1)))
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-MAP:URI="\(escapedURL)",BYTERANGE="\(initRange.length)@\(initRange.offset)"
        #EXTINF:\(durationText),
        \(escapedURL)
        #EXT-X-ENDLIST
        """
    }

    private func masterPlaylist(source: PlayableVideoSource, videoPlaylistURL: URL, audioPlaylistURL: URL) -> String {
        let bandwidth = max(source.bandwidth ?? 2_000_000, 256_000)
        let resolution = resolutionText(width: source.width, height: source.height)
        let frameRate = normalizedFrameRate(source.frameRate)
        let codecs = [source.videoCodec, source.audioCodec]
            .compactMap { $0?.split(separator: ".").isEmpty == false ? $0 : nil }
            .joined(separator: ",")

        var streamInfo = "BANDWIDTH=\(bandwidth),AUDIO=\"audio\""
        if let resolution {
            streamInfo += ",RESOLUTION=\(resolution)"
        }
        if let frameRate {
            streamInfo += ",FRAME-RATE=\(frameRate)"
        }
        if !codecs.isEmpty {
            streamInfo += ",CODECS=\"\(codecs)\""
        }

        return """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="DASH Audio",DEFAULT=YES,AUTOSELECT=YES,URI="\(audioPlaylistURL.lastPathComponent)"
        #EXT-X-STREAM-INF:\(streamInfo)
        \(videoPlaylistURL.lastPathComponent)
        """
    }

    private func byteRange(from text: String?) -> ByteRange? {
        guard let text else { return nil }
        let parts = text.split(separator: "-").compactMap { Int64($0) }
        guard parts.count == 2, parts[1] >= parts[0] else { return nil }
        return ByteRange(offset: parts[0], length: parts[1] - parts[0] + 1)
    }

    private func resolutionText(width: Int?, height: Int?) -> String? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return "\(width)x\(height)"
    }

    private func normalizedFrameRate(_ value: String?) -> String? {
        guard let value, let doubleValue = Double(value), doubleValue > 0 else { return nil }
        return String(format: "%.3f", doubleValue)
    }

    private struct ByteRange {
        let offset: Int64
        let length: Int64
    }
}
