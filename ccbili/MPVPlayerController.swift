import Foundation
import AVFoundation
import UIKit
import libmpv

final class MPVPlayerController {
    private var mpv: OpaquePointer?
    private var isInitialized = false
    var timeUpdateHandler: ((TimeInterval, TimeInterval, Bool) -> Void)?
    private var observerTask: Task<Void, Never>?

    init() {
        mpv = mpv_create()
        guard let mpv else { return }
        mpv_request_log_messages(mpv, "warn")
        setOption("vo", value: "gpu")
        setOption("keepaspect", value: "yes")
        setOption("input-default-bindings", value: "no")
        setOption("input-vo-keyboard", value: "no")
        setOption("hwdec", value: "videotoolbox")
        setOption("profile", value: "fast")
        setOption("cache", value: "yes")
        setOption("demuxer-max-bytes", value: "128MiB")
        setOption("demuxer-readahead-secs", value: "8")
        setOption("force-seekable", value: "yes")
    }

    deinit {
        stop()
        observerTask?.cancel()
        if let mpv {
            mpv_terminate_destroy(mpv)
        }
    }

    func attach(to view: UIView) {
        guard !isInitialized else { return }
        var viewPointer = Int64(Int(bitPattern: Unmanaged.passUnretained(view).toOpaque()))
        setOption("wid", format: MPV_FORMAT_INT64, value: &viewPointer)
        if let mpv, mpv_initialize(mpv) >= 0 {
            isInitialized = true
            startObservingPlayback()
        }
    }

    func play(source: PlayableVideoSource) {
        guard isInitialized else { return }
        configureAudioSession()
        configureHeaders(source.headers)
        if let audioURL = source.audioURL {
            command(["loadfile", source.url.absoluteString, "replace", "audio-file=\(audioURL.absoluteString)"])
        } else {
            command(["loadfile", source.url.absoluteString, "replace"])
        }
        command(["set", "pause", "no"])
    }

    func togglePlay() {
        command(["cycle", "pause"])
    }

    func stop() {
        observerTask?.cancel()
        observerTask = nil
        command(["stop"])
    }

    func seek(to position: Double) {
        command(["seek", String(position * 100), "absolute-percent"])
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
            .joined(separator: "\n")
        setOption("http-header-fields", value: headerString)
        if let referer = enrichedHeaders["Referer"] {
            setOption("referrer", value: referer)
        }
        if let userAgent = enrichedHeaders["User-Agent"] {
            setOption("user-agent", value: userAgent)
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure mpv audio session: \(error.localizedDescription)")
        }
    }

    private func setOption(_ name: String, value: String) {
        guard let mpv else { return }
        mpv_set_option_string(mpv, name, value)
    }

    private func setOption(_ name: String, format: mpv_format, value: UnsafeMutableRawPointer) {
        guard let mpv else { return }
        mpv_set_option(mpv, name, format, value)
    }

    private func command(_ args: [String]) {
        guard let mpv else { return }
        args.withCStringArray { argv in
            _ = mpv_command(mpv, argv)
        }
    }

    private func startObservingPlayback() {
        observerTask?.cancel()
        observerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self else { return }
                let current = self.doubleProperty("time-pos") ?? 0
                let duration = self.doubleProperty("duration") ?? 0
                let paused = self.boolProperty("pause") ?? false
                await MainActor.run { [weak self] in
                    self?.timeUpdateHandler?(current, duration, !paused)
                }
            }
        }
    }

    private func doubleProperty(_ name: String) -> Double? {
        guard let mpv else { return nil }
        var value = 0.0
        let result = name.withCString { pointer in
            mpv_get_property(mpv, pointer, MPV_FORMAT_DOUBLE, &value)
        }
        return result >= 0 ? value : nil
    }

    private func boolProperty(_ name: String) -> Bool? {
        guard let mpv else { return nil }
        var value: Int32 = 0
        let result = name.withCString { pointer in
            mpv_get_property(mpv, pointer, MPV_FORMAT_FLAG, &value)
        }
        return result >= 0 ? value != 0 : nil
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

