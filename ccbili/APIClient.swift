import Foundation

enum APIError: Error, LocalizedError {
    case invalidResponse
    case invalidStatusCode(Int)
    case invalidStatusCodeWithBody(Int, String)
    case decodingFailed(Error)
    case decodingFailedWithBody(Error, String)
    case invalidURL
    case serverMessage(String)
    case unknown(Error)
    case unauthorized
    case missingCSRF
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "无效的服务器响应"
        case .invalidStatusCode(let code):
            return "服务器状态码错误：\(code)"
        case .invalidStatusCodeWithBody(let code, let body):
            return "服务器状态码错误：\(code)\n响应内容：\(body)"
        case .decodingFailed(let error):
            return "数据解析失败：\(error.localizedDescription)"
        case .decodingFailedWithBody(let error, let body):
            return "数据解析失败：\(error.localizedDescription)\n原始响应：\(body)"
        case .invalidURL:
            return "无效的请求地址"
        case .serverMessage(let message):
            return message
        case .unknown(let error):
            return "未知错误：\(error.localizedDescription)"
        case .unauthorized:
            return "当前未登录或登录已失效"
        case .missingCSRF:
            return "缺少 csrf（bili_jct）"
        case .cancelled:
            return nil
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpAdditionalHeaders = [
            "Accept-Encoding": "br, gzip"
        ]

        self.session = URLSession(configuration: configuration)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        self.decoder = decoder
    }

    func get<T: Decodable>(
        url: URL,
        headers: [String: String] = [:],
        as type: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppConfig.defaultUserAgent, forHTTPHeaderField: "User-Agent")

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return try await perform(request, as: type)
    }

    func getJSON(
        url: URL,
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppConfig.defaultUserAgent, forHTTPHeaderField: "User-Agent")

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let data = try await performData(request)

        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any] else {
                throw APIError.invalidResponse
            }
            return dictionary
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingFailedWithBody(error, debugString(from: data))
        }
    }

    func postForm<T: Decodable>(
        url: URL,
        form: [String: String],
        headers: [String: String] = [:],
        as type: T.Type
    ) async throws -> T {
        let request = makePostFormRequest(url: url, form: form, headers: headers)
        return try await perform(request, as: type)
    }

    func postFormData(
        url: URL,
        form: [String: String],
        headers: [String: String] = [:]
    ) async throws -> Data {
        let request = makePostFormRequest(url: url, form: form, headers: headers)
        return try await performData(request)
    }

    func postFormJSON(
        url: URL,
        form: [String: String],
        headers: [String: String] = [:]
    ) async throws -> [String: Any] {
        let request = makePostFormRequest(url: url, form: form, headers: headers)
        let data = try await performData(request)

        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any] else {
                throw APIError.invalidResponse
            }
            return dictionary
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingFailedWithBody(error, debugString(from: data))
        }
    }

    private func makePostFormRequest(
        url: URL,
        form: [String: String],
        headers: [String: String]
    ) -> URLRequest {
        let bodyString = form
            .map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }
            .joined(separator: "&")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(bodyString.utf8)
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppConfig.defaultUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(AppConfig.webBaseURL.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue(AppConfig.webBaseURL.absoluteString, forHTTPHeaderField: "Origin")

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let data = try await performData(request)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailedWithBody(error, debugString(from: data))
        }
    }

    private func performData(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidStatusCodeWithBody(
                    httpResponse.statusCode,
                    debugString(from: data)
                )
            }

            return data
        } catch is CancellationError {
            throw APIError.cancelled
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw APIError.cancelled
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.unknown(error)
        }
    }

    private func percentEncode(_ string: String) -> String {
        string.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?"))
        ) ?? string
    }

    private func debugString(from data: Data) -> String {
        if let utf8String = String(data: data, encoding: .utf8), !utf8String.isEmpty {
            return utf8String
        }

        if let asciiString = String(data: data, encoding: .ascii), !asciiString.isEmpty {
            return asciiString
        }

        return "<\(data.count) bytes binary data>"
    }
}
