import Foundation
import AVFoundation
import libmpv

final class MPVPlayerController {
    private var mpv: OpaquePointer?

    init() {
        mpv = mpv_create()
        guard let mpv else { return }
        setOption("vo", value: "avfoundation")
        setOption("keepaspect", value: "yes")
        setOption("hwdec", value: "videotoolbox")
        setOption("profile", value: "fast")
        setOption("cache", value: "yes")
        setOption("demuxer-max-bytes", value: "64MiB")
        setOption("demuxer-readahead-secs", value: "20")
        mpv_initialize(mpv)
    }

    deinit {
        stop()
        if let mpv {
            mpv_terminate_destroy(mpv)
        }
    }

    func play(source: PlayableVideoSource) {
        guard let mpv else { return }
        configureHeaders(source.headers)
        command(["loadfile", source.url.absoluteString, "replace"])
        if let audioURL = source.audioURL {
            command(["audio-add", audioURL.absoluteString, "select"])
        }
        command(["set", "pause", "no"])
        _ = mpv
    }

    func togglePlay() {
        command(["cycle", "pause"])
    }

    func stop() {
        command(["stop"])
    }

    private func configureHeaders(_ headers: [String: String]) {
        var enrichedHeaders = headers
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        if let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"], !cookieHeader.isEmpty {
            enrichedHeaders["Cookie"] = cookieHeader
        }
        enrichedHeaders["Accept"] = "*/*"
        let headerString = enrichedHeaders
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ",")
        setOption("http-header-fields", value: headerString)
        if let referer = enrichedHeaders["Referer"] {
            setOption("referrer", value: referer)
        }
        if let userAgent = enrichedHeaders["User-Agent"] {
            setOption("user-agent", value: userAgent)
        }
    }

    private func setOption(_ name: String, value: String) {
        guard let mpv else { return }
        mpv_set_option_string(mpv, name, value)
    }

    private func command(_ args: [String]) {
        guard let mpv else { return }
        args.withCStringArray { argv in
            _ = mpv_command(mpv, argv)
        }
    }
}

private extension Array where Element == String {
    func withCStringArray<Result>(_ body: (UnsafeMutablePointer<UnsafePointer<CChar>?>) -> Result) -> Result {
        var cStrings = map { strdup($0) }
        defer {
            for pointer in cStrings {
                free(pointer)
            }
        }
        cStrings.append(nil)
        var constPointers = cStrings.map { UnsafePointer<CChar>($0) }
        return constPointers.withUnsafeMutableBufferPointer { buffer in
            body(buffer.baseAddress!)
        }
    }
}
