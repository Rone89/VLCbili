import Foundation

struct SearchService {
    func searchAll(keyword: String, page: Int = 1) async throws -> [VideoItem] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(
            url: AppConfig.apiBaseURL.appending(path: "/x/web-interface/wbi/search/all/v2"),
            resolvingAgainstBaseURL: false
        )

        let queryItems = try await WBI.shared.signedQueryItems(from: [
            "keyword": trimmed,
            "page": String(page)
        ])
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response = try await APIClient.shared.get(
            url: url,
            as: SearchAllResponseDTO.self
        )

        guard response.code == 0 else {
            throw APIError.serverMessage(response.message)
        }

        let items = (response.data?.result ?? []).compactMap { result -> VideoItem? in
            guard let bvid = result.bvid, !bvid.isEmpty else {
                return nil
            }

            let cleanTitle = (result.title ?? "未知标题")
                .replacingOccurrences(of: "<em class=\"keyword\">", with: "")
                .replacingOccurrences(of: "</em>", with: "")

            let subtitle = result.author ?? "未知 UP 主"
            let coverURL = normalizedImageURL(from: result.pic)

            return VideoItem(
                id: bvid,
                title: cleanTitle,
                subtitle: subtitle,
                bvid: bvid,
                aid: result.aid,
                cid: nil,
                coverURL: coverURL
            )
        }

        return items
    }

    private func normalizedImageURL(from path: String?) -> URL? {
        guard let path, !path.isEmpty else {
            return nil
        }

        if path.hasPrefix("//") {
            return URL(string: "https:" + path)
        }

        return URL(string: path)
    }
}
