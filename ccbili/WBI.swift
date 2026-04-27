import Foundation
import CryptoKit

enum WBIError: Error {
    case invalidNavData
}

actor WBI {
    static let shared = WBI()

    private let mixinKeyTable: [Int] = [
        46, 47, 18, 2, 53, 8, 23, 32,
        15, 50, 10, 31, 58, 3, 45, 35,
        27, 43, 5, 49, 33, 9, 42, 19,
        29, 28, 14, 39, 12, 38, 41, 13
    ]

    private var cachedMixinKey: String?
    private var cachedDay: Int?

    func signedQueryItems(from parameters: [String: String]) async throws -> [URLQueryItem] {
        let mixinKey = try await loadMixinKeyIfNeeded()

        var signedParameters = parameters
        signedParameters["wts"] = String(Int(Date().timeIntervalSince1970))

        let filtered = signedParameters
            .mapValues { value in
                value.replacingOccurrences(of: #"[\!'\(\)\*]"#, with: "", options: .regularExpression)
            }

        let sorted = filtered.sorted { $0.key < $1.key }

        let query = sorted
            .map { key, value in
                "\(percentEncode(key))=\(percentEncode(value))"
            }
            .joined(separator: "&")

        let wRid = md5(query + mixinKey)
        let finalParameters = sorted + [("w_rid", wRid)]

        return finalParameters.map { URLQueryItem(name: $0.0, value: $0.1) }
    }

    private func loadMixinKeyIfNeeded() async throws -> String {
        let day = Calendar.current.component(.day, from: Date())

        if let cachedMixinKey, let cachedDay, cachedDay == day {
            return cachedMixinKey
        }

        let url = AppConfig.apiBaseURL.appending(path: "/x/web-interface/nav")
        var headers = ["User-Agent": AppConfig.desktopUserAgent]
        if let cookieHeader = BilibiliCookieStore.cookieHeader() {
            headers["Cookie"] = cookieHeader
        }
        let json = try await APIClient.shared.getJSON(url: url, headers: headers)

        guard
            let data = json["data"] as? [String: Any],
            let wbiImage = data["wbi_img"] as? [String: Any],
            let imageURLString = wbiImage["img_url"] as? String,
            let subURLString = wbiImage["sub_url"] as? String
        else {
            throw WBIError.invalidNavData
        }

        let imageName = fileNameWithoutExtension(from: imageURLString)
        let subName = fileNameWithoutExtension(from: subURLString)
        let origin = imageName + subName

        let mixinKey = String(mixinKeyTable.compactMap { index in
            guard index < origin.count else { return nil }
            let stringIndex = origin.index(origin.startIndex, offsetBy: index)
            return origin[stringIndex]
        })

        cachedMixinKey = mixinKey
        cachedDay = day
        return mixinKey
    }

    private func fileNameWithoutExtension(from path: String) -> String {
        URL(string: path)?.deletingPathExtension().lastPathComponent ?? ""
    }

    private func percentEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?"))) ?? string
    }

    private func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
