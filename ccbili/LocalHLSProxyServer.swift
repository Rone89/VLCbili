import Foundation
import Network

final class LocalHLSProxyServer {
    static let shared = LocalHLSProxyServer()

    private let queue = DispatchQueue(label: "ccbili.local-hls-proxy")
    private let serverPort: UInt16 = 28757
    private var listener: NWListener?
    private var listenerState: NWListener.State = .setup
    private var readyContinuations: [CheckedContinuation<Void, Error>] = []
    private var routes: [String: Route] = [:]
    private var routeCounter = 0
    private var playlists: [String: String] = [:]
    private var playlistCounter = 0

    private init() {}

    func resetForForegroundPlayback() {
        queue.sync {
            routes.removeAll()
            routeCounter = 0
            playlists.removeAll()
            playlistCounter = 0

            if case .failed = listenerState {
                listener?.cancel()
                listener = nil
                listenerState = .setup
            }

            if case .cancelled = listenerState {
                listener = nil
                listenerState = .setup
            }
        }
    }

    func register(mediaURL: URL, headers: [String: String]) throws -> URL {
        try queue.sync {
            try startIfNeeded()
            routeCounter += 1
            let id = String(routeCounter)
            routes[id] = Route(url: mediaURL, headers: headers)
            return URL(string: "http://127.0.0.1:\(serverPort)/dash/\(id)")!
        }
    }

    func waitUntilReady() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                switch self.listenerState {
                case .ready:
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    self.readyContinuations.append(continuation)
                }
            }
        }
    }

    func registerPlaylist(_ content: String, name: String) throws -> URL {
        try queue.sync {
            try startIfNeeded()
            playlistCounter += 1
            let safeName = name.replacingOccurrences(of: "/", with: "-")
            let id = "\(playlistCounter)-\(safeName)"
            playlists[id] = content
            return URL(string: "http://127.0.0.1:\(serverPort)/hls/\(id)")!
        }
    }

    private func startIfNeeded() throws {
        if listener != nil, case .ready = listenerState { return }
        if listener != nil, case .setup = listenerState { return }
        if listener != nil, case .waiting = listenerState {
            listener?.cancel()
            listener = nil
            listenerState = .setup
        }
        listener?.cancel()
        listener = nil
        listenerState = .setup
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        guard let port = NWEndpoint.Port(rawValue: serverPort) else {
            throw APIError.serverMessage("HLS 本地代理端口异常")
        }
        let listener = try NWListener(using: parameters, on: port)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            self.queue.async {
                self.listenerState = state
                if case .ready = state {
                    let continuations = self.readyContinuations
                    self.readyContinuations.removeAll()
                    continuations.forEach { $0.resume() }
                }
                if case .failed = state {
                    let continuations = self.readyContinuations
                    self.readyContinuations.removeAll()
                    continuations.forEach { $0.resume(throwing: APIError.serverMessage("HLS 本地代理启动失败")) }
                    self.listener?.cancel()
                    self.listener = nil
                }
                if case .cancelled = state {
                    self.listener = nil
                }
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                self?.send(status: 400, body: Data(), connection: connection)
                return
            }
            self.respond(to: request, connection: connection)
        }
    }

    private func respond(to rawRequest: String, connection: NWConnection) {
        guard let requestLine = rawRequest.split(separator: "\r\n").first else {
            send(status: 400, body: Data(), connection: connection)
            return
        }
        let requestParts = requestLine.split(separator: " ")
        guard requestParts.count >= 2 else {
            send(status: 400, body: Data(), connection: connection)
            return
        }

        let method = String(requestParts[0]).uppercased()
        guard method == "GET" || method == "HEAD" else {
            send(
                status: 405,
                headers: ["Allow": "GET, HEAD"],
                body: Data(),
                connection: connection
            )
            return
        }

        let path = String(requestParts[1])
        if path.hasPrefix("/hls/") {
            let id = String(path.dropFirst("/hls/".count).split(separator: "?").first ?? "")
            guard let playlist = playlists[id] else {
                HLSPlaybackDiagnostics.shared.recordPlaylist(path: path, status: 404)
                send(status: 404, body: Data(), connection: connection)
                return
            }
            HLSPlaybackDiagnostics.shared.recordPlaylist(path: path, status: 200)
            send(
                status: 200,
                headers: [
                    "Content-Type": "application/vnd.apple.mpegurl; charset=utf-8",
                    "Cache-Control": "no-cache"
                ],
                body: Data(playlist.utf8),
                connection: connection,
                sendsBody: method != "HEAD"
            )
            return
        }

        guard path.hasPrefix("/dash/") else {
            HLSPlaybackDiagnostics.shared.recordPlaylist(path: path, status: 404)
            send(status: 404, body: Data(), connection: connection)
            return
        }
        let id = String(path.dropFirst("/dash/".count).split(separator: "?").first ?? "")
        guard let route = routes[id] else {
            send(status: 404, body: Data(), connection: connection)
            return
        }

        let rangeHeader = headerValue("Range", in: rawRequest)
        MediaRouteStreamer(
            route: route,
            headers: enrichedHeaders(route.headers),
            rangeHeader: rangeHeader,
            method: method,
            path: path,
            connection: connection
        )
        .start()
    }

    private func enrichedHeaders(_ headers: [String: String]) -> [String: String] {
        var result = headers
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        if let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"], !cookieHeader.isEmpty {
            result["Cookie"] = cookieHeader
        }
        result["Accept"] = "*/*"
        result["Accept-Encoding"] = "identity"
        return result
    }

    private func headerValue(_ name: String, in request: String) -> String? {
        let prefix = name.lowercased() + ":"
        for line in request.split(separator: "\r\n") {
            let text = String(line)
            if text.lowercased().hasPrefix(prefix) {
                return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func send(
        status: Int,
        headers: [String: String] = [:],
        body: Data,
        connection: NWConnection,
        sendsBody: Bool = true
    ) {
        var statusText = "OK"
        if status == 206 { statusText = "Partial Content" }
        if status >= 400 { statusText = "Error" }
        var headerLines = [
            "HTTP/1.1 \(status) \(statusText)",
            "Content-Length: \(body.count)",
            "Connection: close"
        ]
        for (key, value) in headers where key.lowercased() != "content-length" && key.lowercased() != "connection" {
            headerLines.append("\(key): \(value)")
        }
        headerLines.append("")
        headerLines.append("")
        var response = Data(headerLines.joined(separator: "\r\n").utf8)
        if sendsBody {
            response.append(body)
        }
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private struct Route {
        let url: URL
        let headers: [String: String]
    }

    private final class MediaRouteStreamer: NSObject, URLSessionDataDelegate {
        private let route: Route
        private let headers: [String: String]
        private let rangeHeader: String?
        private let method: String
        private let path: String
        private let connection: NWConnection
        private let delegateQueue: OperationQueue
        private var session: URLSession?
        private var deliveredBytes = 0
        private var responseStatus = 502
        private var responseRange: String?
        private var didSendHeaders = false
        private var selfRetainer: MediaRouteStreamer?

        init(
            route: Route,
            headers: [String: String],
            rangeHeader: String?,
            method: String,
            path: String,
            connection: NWConnection
        ) {
            self.route = route
            self.headers = headers
            self.rangeHeader = rangeHeader
            self.method = method
            self.path = path
            self.connection = connection
            let delegateQueue = OperationQueue()
            delegateQueue.maxConcurrentOperationCount = 1
            self.delegateQueue = delegateQueue
        }

        func start() {
            selfRetainer = self

            var request = URLRequest(url: route.url)
            request.httpMethod = method
            request.timeoutInterval = 30
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            if let rangeHeader {
                request.setValue(rangeHeader, forHTTPHeaderField: "Range")
            }

            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 300
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
            self.session = session
            session.dataTask(with: request).resume()
        }

        func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didReceive response: URLResponse,
            completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
        ) {
            guard let httpResponse = response as? HTTPURLResponse else {
                sendErrorResponse(message: "HLS 本地代理响应异常")
                completionHandler(.cancel)
                finish()
                return
            }

            responseStatus = httpResponse.statusCode
            var responseHeaders = [String: String]()
            for (key, value) in httpResponse.allHeaderFields {
                responseHeaders[String(describing: key)] = String(describing: value)
            }
            responseRange = responseHeaders["Content-Range"] ?? responseHeaders["content-range"]
            sendHeaders(status: httpResponse.statusCode, headers: responseHeaders)
            completionHandler(.allow)
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            var redirectedRequest = request
            redirectedRequest.httpMethod = method
            for (key, value) in headers {
                redirectedRequest.setValue(value, forHTTPHeaderField: key)
            }
            if let rangeHeader {
                redirectedRequest.setValue(rangeHeader, forHTTPHeaderField: "Range")
            }
            completionHandler(redirectedRequest)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            guard method != "HEAD" else { return }
            deliveredBytes += data.count
            connection.send(content: data, completion: .contentProcessed { _ in })
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error {
                HLSPlaybackDiagnostics.shared.recordProxyError(
                    path: path,
                    requestRange: rangeHeader,
                    message: error.localizedDescription
                )
                if !didSendHeaders {
                    sendErrorResponse(message: error.localizedDescription)
                } else {
                    connection.cancel()
                    finish()
                }
                return
            }

            HLSPlaybackDiagnostics.shared.recordProxy(
                path: path,
                requestRange: rangeHeader,
                status: responseStatus,
                responseRange: responseRange,
                bytes: deliveredBytes
            )
            connection.send(content: nil, isComplete: true, completion: .contentProcessed { [weak self] _ in
                self?.connection.cancel()
                self?.finish()
            })
        }

        private func sendHeaders(status: Int, headers: [String: String]) {
            didSendHeaders = true

            var headerLines = [
                "HTTP/1.1 \(status) \(Self.statusText(for: status))",
                "Connection: close",
                "Access-Control-Allow-Origin: *"
            ]
            for (key, value) in headers {
                let lowercasedKey = key.lowercased()
                guard lowercasedKey != "connection",
                      lowercasedKey != "transfer-encoding",
                      lowercasedKey != "content-encoding" else {
                    continue
                }
                headerLines.append("\(key): \(value)")
            }
            headerLines.append("")
            headerLines.append("")
            connection.send(content: Data(headerLines.joined(separator: "\r\n").utf8), completion: .contentProcessed { _ in })
        }

        private func sendErrorResponse(message: String) {
            HLSPlaybackDiagnostics.shared.recordProxyError(
                path: path,
                requestRange: rangeHeader,
                message: message
            )
            let body = Data()
            let headerLines = [
                "HTTP/1.1 502 Error",
                "Content-Length: \(body.count)",
                "Connection: close",
                "",
                ""
            ]
            var response = Data(headerLines.joined(separator: "\r\n").utf8)
            response.append(body)
            connection.send(content: response, isComplete: true, completion: .contentProcessed { [weak self] _ in
                self?.connection.cancel()
                self?.finish()
            })
        }

        private func finish() {
            session?.finishTasksAndInvalidate()
            session = nil
            selfRetainer = nil
        }

        private static func statusText(for status: Int) -> String {
            if status == 206 { return "Partial Content" }
            if status >= 400 { return "Error" }
            return "OK"
        }
    }
}
