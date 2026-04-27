import Foundation

struct DashRemuxService {
    func makeMPDManifest(
        video: PlayURLDashVideoDTO,
        audio: PlayURLDashAudioDTO,
        durationMilliseconds: Int?,
        bvid: String,
        cid: Int
    ) throws -> URL {
        guard let videoURL = streamURL(from: video.baseURL, backups: video.backupURL),
              let audioURL = streamURL(from: audio.baseURL, backups: audio.backupURL) else {
            throw APIError.serverMessage("DASH 音视频地址不完整")
        }

        let directory = try manifestDirectory(bvid: bvid, cid: cid)
        let manifestURL = directory.appendingPathComponent("manifest.mpd")
        let mpd = makeMPD(
            video: video,
            videoURL: videoURL,
            audio: audio,
            audioURL: audioURL,
            durationMilliseconds: durationMilliseconds
        )
        try mpd.write(to: manifestURL, atomically: true, encoding: .utf8)
        return manifestURL
    }

    private func streamURL(from baseURL: String?, backups: [String]?) -> String? {
        if let baseURL, !baseURL.isEmpty {
            return baseURL
        }

        return backups?.first(where: { !$0.isEmpty })
    }

    private func manifestDirectory(bvid: String, cid: Int) throws -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = caches
            .appendingPathComponent("DashManifests", isDirectory: true)
            .appendingPathComponent("\(bvid)-\(cid)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeMPD(
        video: PlayURLDashVideoDTO,
        videoURL: String,
        audio: PlayURLDashAudioDTO,
        audioURL: String,
        durationMilliseconds: Int?
    ) -> String {
        let duration = durationMilliseconds.map { isoDuration(milliseconds: $0) }
        let durationAttribute = duration.map { " mediaPresentationDuration=\"\($0)\"" } ?? ""
        let periodDurationAttribute = duration.map { " duration=\"\($0)\"" } ?? ""
        let videoRepresentation = representation(
            id: video.id ?? 0,
            bandwidth: video.bandwidth ?? 0,
            mimeType: video.mimeType ?? "video/mp4",
            codecs: video.codecs ?? "",
            baseURL: videoURL,
            width: video.width,
            height: video.height,
            frameRate: video.frameRate,
            segmentBase: video.segmentBase
        )
        let audioRepresentation = representation(
            id: audio.id ?? 0,
            bandwidth: audio.bandwidth ?? 0,
            mimeType: audio.mimeType ?? "audio/mp4",
            codecs: audio.codecs ?? "",
            baseURL: audioURL,
            width: nil,
            height: nil,
            frameRate: nil,
            segmentBase: audio.segmentBase
        )

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <MPD xmlns="urn:mpeg:dash:schema:mpd:2011" profiles="urn:mpeg:dash:profile:isoff-on-demand:2011" type="static"\(durationAttribute) minBufferTime="PT1.5S">
          <Period id="0" start="PT0S"\(periodDurationAttribute)>
            <AdaptationSet id="0" contentType="video" segmentAlignment="true" subsegmentAlignment="true">
        \(videoRepresentation)
            </AdaptationSet>
            <AdaptationSet id="1" contentType="audio" segmentAlignment="true" subsegmentAlignment="true">
        \(audioRepresentation)
            </AdaptationSet>
          </Period>
        </MPD>
        """
    }

    private func representation(
        id: Int,
        bandwidth: Int,
        mimeType: String,
        codecs: String,
        baseURL: String,
        width: Int?,
        height: Int?,
        frameRate: String?,
        segmentBase: PlayURLSegmentBaseDTO?
    ) -> String {
        var attributes = [
            "id=\"\(id)\"",
            "bandwidth=\"\(bandwidth)\"",
            "mimeType=\"\(xmlEscape(mimeType))\"",
            "codecs=\"\(xmlEscape(codecs))\""
        ]

        if let width {
            attributes.append("width=\"\(width)\"")
        }
        if let height {
            attributes.append("height=\"\(height)\"")
        }
        if let frameRate, !frameRate.isEmpty {
            attributes.append("frameRate=\"\(xmlEscape(frameRate))\"")
        }

        let initialization = segmentBase?.initialization ?? "0-0"
        let indexRange = segmentBase?.indexRange ?? "0-0"

        return """
              <Representation \(attributes.joined(separator: " "))>
                <BaseURL>\(xmlEscape(baseURL))</BaseURL>
                <SegmentBase indexRange="\(xmlEscape(indexRange))">
                  <Initialization range="\(xmlEscape(initialization))" />
                </SegmentBase>
              </Representation>
        """
    }

    private func isoDuration(milliseconds: Int) -> String {
        let seconds = Double(milliseconds) / 1000
        return String(format: "PT%.3fS", seconds)
    }

    private func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
