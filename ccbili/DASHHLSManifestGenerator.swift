import Foundation

struct DASHHLSSegment {
    let url: String
    let duration: Double
    let byteRange: DASHHLSByteRange?

    init(url: String, duration: Double, byteRange: DASHHLSByteRange? = nil) {
        self.url = url
        self.duration = duration
        self.byteRange = byteRange
    }
}

struct DASHHLSByteRange {
    let offset: Int64
    let length: Int64
}

struct HLSManifestVariant {
    let playlistURL: URL
    let bandwidth: Int
    let resolution: String?
    let frameRate: String?
    let codecs: String?
    let videoQuality: String
}

func generateHLSManifest(
    initUrl: String,
    segments: [DASHHLSSegment],
    videoQuality: String
) -> String {
    generateHLSManifest(
        initUrl: initUrl,
        initByteRange: nil,
        segments: segments,
        videoQuality: videoQuality
    )
}

func generateHLSManifest(
    initUrl: String,
    initByteRange: DASHHLSByteRange?,
    segments: [DASHHLSSegment],
    videoQuality: String
) -> String {
    let escapedInitURL = escapedAbsoluteURL(initUrl)
    let targetDuration = max(1, Int(ceil(segments.map(\.duration).max() ?? 1)))
    var mapTag = "#EXT-X-MAP:URI=\"\(escapedInitURL)\""
    if let initByteRange {
        mapTag += ",BYTERANGE=\"\(initByteRange.length)@\(initByteRange.offset)\""
    }

    var lines: [String] = []
    lines.reserveCapacity(segments.count * 3 + 8)
    lines.append("#EXTM3U")
    lines.append("#EXT-X-VERSION:7")
    lines.append("#EXT-X-PLAYLIST-TYPE:VOD")
    lines.append("#EXT-X-TARGETDURATION:\(targetDuration)")
    lines.append("#EXT-X-MEDIA-SEQUENCE:0")
    lines.append("#EXT-X-INDEPENDENT-SEGMENTS")
    lines.append(mapTag)

    for segment in segments where segment.duration > 0 {
        lines.append("#EXTINF:\(String(format: "%.6f", segment.duration)),")
        if let byteRange = segment.byteRange {
            lines.append("#EXT-X-BYTERANGE:\(byteRange.length)@\(byteRange.offset)")
        }
        lines.append(escapedAbsoluteURL(segment.url))
    }

    lines.append("#EXT-X-ENDLIST")
    return lines.joined(separator: "\n") + "\n"
}

func generateHLSMasterManifest(
    audioPlaylistURL: URL,
    videoVariant: HLSManifestVariant
) -> String {
    var streamInfo = "BANDWIDTH=\(max(videoVariant.bandwidth, 256_000)),AUDIO=\"audio\""
    if let resolution = videoVariant.resolution { streamInfo += ",RESOLUTION=\(resolution)" }
    if let frameRate = videoVariant.frameRate { streamInfo += ",FRAME-RATE=\(frameRate)" }
    if let codecs = videoVariant.codecs, !codecs.isEmpty { streamInfo += ",CODECS=\"\(codecs)\"" }
    if let videoRange = hlsVideoRange(for: videoVariant.videoQuality) {
        streamInfo += ",VIDEO-RANGE=\(videoRange)"
    }

    return """
    #EXTM3U
    #EXT-X-VERSION:7
    #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="DASH Audio",DEFAULT=YES,AUTOSELECT=YES,URI="\(audioPlaylistURL.absoluteString)"
    #EXT-X-STREAM-INF:\(streamInfo)
    \(videoVariant.playlistURL.absoluteString)
    """
}

private func hlsVideoRange(for videoQuality: String) -> String? {
    let normalized = videoQuality.lowercased()
    if normalized.contains("dolbyvision")
        || normalized.contains("dolby")
        || normalized.contains("hdr")
        || normalized.contains("pq")
        || normalized.contains("杜比")
        || normalized.contains("视界")
        || normalized.contains("高动态") {
        return "PQ"
    }
    return nil
}

private func escapedAbsoluteURL(_ value: String) -> String {
    guard let url = URL(string: value), url.scheme != nil else {
        preconditionFailure("HLS manifest URL must be absolute: \(value)")
    }
    return url.absoluteString.replacingOccurrences(of: "\"", with: "%22")
}
