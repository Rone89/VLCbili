import Foundation

struct DashMPDManifestService {
    func makeManifest(for source: PlayableVideoSource) async throws -> URL {
        LocalHLSProxyServer.shared.resetForForegroundPlayback()

        guard let audioURL = source.audioURL,
              isValidByteRange(source.videoInitRange),
              isValidByteRange(source.videoIndexRange),
              isValidByteRange(source.audioInitRange),
              isValidByteRange(source.audioIndexRange) else {
            throw APIError.serverMessage("DASH MPD 清单信息不完整")
        }

        let proxiedVideoURL = try LocalHLSProxyServer.shared.register(mediaURL: source.url, headers: source.headers)
        let proxiedAudioURL = try LocalHLSProxyServer.shared.register(mediaURL: audioURL, headers: source.headers)
        let manifest = mpdManifest(
            source: source,
            videoURL: proxiedVideoURL,
            audioURL: proxiedAudioURL
        )
        let manifestURL = try LocalHLSProxyServer.shared.registerMPD(manifest, name: "manifest.mpd")
        HLSPlaybackDiagnostics.shared.recordMPD(
            videoIndex: source.videoIndexRange,
            audioIndex: source.audioIndexRange,
            duration: source.duration,
            videoCodec: source.videoCodec,
            audioCodec: source.audioCodec
        )
        try await LocalHLSProxyServer.shared.waitUntilReady()
        return manifestURL
    }

    private func mpdManifest(source: PlayableVideoSource, videoURL: URL, audioURL: URL) -> String {
        let duration = isoDuration(source.duration)
        let videoRepresentation = videoRepresentationXML(source: source, url: videoURL)
        let audioRepresentation = audioRepresentationXML(source: source, url: audioURL)

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <MPD xmlns="urn:mpeg:dash:schema:mpd:2011" type="static" profiles="urn:mpeg:dash:profile:isoff-on-demand:2011" mediaPresentationDuration="\(duration)" minBufferTime="PT1.500S">
          <Period id="0" duration="\(duration)">
            <AdaptationSet id="1" contentType="video" mimeType="video/mp4" segmentAlignment="true" startWithSAP="1">
        \(videoRepresentation)
            </AdaptationSet>
            <AdaptationSet id="2" contentType="audio" mimeType="audio/mp4" segmentAlignment="true" startWithSAP="1">
              <AudioChannelConfiguration schemeIdUri="urn:mpeg:dash:23003:3:audio_channel_configuration:2011" value="2"/>
        \(audioRepresentation)
            </AdaptationSet>
          </Period>
        </MPD>
        """
    }

    private func videoRepresentationXML(source: PlayableVideoSource, url: URL) -> String {
        var attributes = [
            "id=\"video-\(source.quality ?? 0)\"",
            "bandwidth=\"\(max(source.bandwidth ?? 2_000_000, 256_000))\""
        ]

        if let width = source.width, width > 0 {
            attributes.append("width=\"\(width)\"")
        }
        if let height = source.height, height > 0 {
            attributes.append("height=\"\(height)\"")
        }
        if let frameRate = source.frameRate, !frameRate.isEmpty {
            attributes.append("frameRate=\"\(xmlEscaped(frameRate))\"")
        }
        if let codec = source.videoCodec, !codec.isEmpty {
            attributes.append("codecs=\"\(xmlEscaped(codec))\"")
        }

        return representationXML(
            attributes: attributes,
            baseURL: url,
            initializationRange: source.videoInitRange,
            indexRange: source.videoIndexRange
        )
    }

    private func audioRepresentationXML(source: PlayableVideoSource, url: URL) -> String {
        var attributes = [
            "id=\"audio\"",
            "bandwidth=\"128000\""
        ]

        if let codec = source.audioCodec, !codec.isEmpty {
            attributes.append("codecs=\"\(xmlEscaped(codec))\"")
        }

        return representationXML(
            attributes: attributes,
            baseURL: url,
            initializationRange: source.audioInitRange,
            indexRange: source.audioIndexRange
        )
    }

    private func representationXML(
        attributes: [String],
        baseURL: URL,
        initializationRange: String?,
        indexRange: String?
    ) -> String {
        """
              <Representation \(attributes.joined(separator: " "))>
                <BaseURL>\(xmlEscaped(baseURL.absoluteString))</BaseURL>
                <SegmentBase indexRange="\(xmlEscaped(indexRange ?? ""))">
                  <Initialization range="\(xmlEscaped(initializationRange ?? ""))"/>
                </SegmentBase>
              </Representation>
        """
    }

    private func isoDuration(_ duration: TimeInterval?) -> String {
        guard let duration, duration.isFinite, duration > 0 else {
            return "PT0S"
        }

        return String(format: "PT%.3fS", duration)
    }

    private func isValidByteRange(_ text: String?) -> Bool {
        guard let text else { return false }
        let parts = text.split(separator: "-").compactMap { Int64($0) }
        return parts.count == 2 && parts[1] >= parts[0]
    }

    private func xmlEscaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
