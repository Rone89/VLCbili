import AVFoundation
import Foundation

final class DashHLSResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    private let headers: [String: String]
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    init(headers: [String: String]) {
        self.headers = headers
        super.init()
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let url = loadingRequest.request.url,
              let originalURL = originalURL(from: url) else {
            loadingRequest.finishLoading(with: APIError.invalidURL)
            return false
        }

        let identifier = ObjectIdentifier(loadingRequest)
        tasks[identifier] = Task { [weak self, weak loadingRequest] in
            guard let self, let loadingRequest else { return }
            do {
                try await self.respond(to: loadingRequest, originalURL: originalURL)
                loadingRequest.finishLoading()
            } catch {
                loadingRequest.finishLoading(with: error)
            }
            await MainActor.run { [weak self] in
                self?.tasks[identifier] = nil
            }
        }
        return true
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        didCancel loadingRequest: AVAssetResourceLoadingRequest
    ) {
        let identifier = ObjectIdentifier(loadingRequest)
        tasks[identifier]?.cancel()
        tasks[identifier] = nil
    }

    private func respond(to loadingRequest: AVAssetResourceLoadingRequest, originalURL: URL) async throws {
        var request = URLRequest(url: originalURL)
        request.timeoutInterval = 30
        for (key, value) in enrichedHeaders() {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let dataRequest = loadingRequest.dataRequest {
            let start = dataRequest.requestedOffset
            let end = start + Int64(dataRequest.requestedLength) - 1
            if dataRequest.requestedLength > 0 {
                request.setValue("bytes=\(start)-\(end)", forHTTPHeaderField: "Range")
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.serverMessage("DASH HLS 资源请求失败")
        }

        if let contentInformationRequest = loadingRequest.contentInformationRequest {
            contentInformationRequest.contentType = contentType(from: httpResponse, url: originalURL)
            contentInformationRequest.isByteRangeAccessSupported = true
            if let length = contentLength(from: httpResponse, dataCount: data.count) {
                contentInformationRequest.contentLength = length
            }
        }
        loadingRequest.dataRequest?.respond(with: data)
    }

    private func enrichedHeaders() -> [String: String] {
        var result = headers
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        if let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"], !cookieHeader.isEmpty {
            result["Cookie"] = cookieHeader
        }
        result["Accept"] = "*/*"
        return result
    }

    private func originalURL(from url: URL) -> URL? {
        guard url.scheme == "ccbili-dash" else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url
    }

    private func contentType(from response: HTTPURLResponse, url: URL) -> String {
        if let mimeType = response.mimeType, !mimeType.isEmpty {
            return mimeType
        }
        if url.pathExtension.lowercased() == "m4s" {
            return AVFileType.mp4.rawValue
        }
        return AVFileType.mp4.rawValue
    }

    private func contentLength(from response: HTTPURLResponse, dataCount: Int) -> Int64? {
        if let contentRange = response.value(forHTTPHeaderField: "Content-Range"),
           let total = contentRange.split(separator: "/").last,
           let length = Int64(total) {
            return length
        }
        if let contentLength = response.value(forHTTPHeaderField: "Content-Length"),
           let length = Int64(contentLength) {
            return length
        }
        return Int64(dataCount)
    }
}
