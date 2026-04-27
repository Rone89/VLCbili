//
//  HistoryService.swift
//  ccbili
//
//  Created by chuzu  on 2026/4/25.
//


import Foundation

struct HistoryService {
    func fetchHistory(max: Int = 30) async throws -> [VideoItem] {
        try BiliAuthContext.requireLogin()

        var components = URLComponents(
            url: AppConfig.apiBaseURL.appending(path: "/x/web-interface/history/cursor"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "ps", value: String(max))
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response = try await APIClient.shared.get(
            url: url,
            headers: [
                "Referer": AppConfig.webBaseURL.absoluteString
            ],
            as: HistoryResponseDTO.self
        )

        guard response.code == 0 else {
            throw APIError.serverMessage(response.message)
        }

        return (response.data ?? []).compactMap { item in
            let resolvedBVID = item.history?.bvid ?? item.bvid
            guard let bvid = resolvedBVID, !bvid.isEmpty else {
                return nil
            }

            let coverString = item.cover ?? item.covers?.first
            let coverURL = normalizedImageURL(from: coverString)

            return VideoItem(
                id: bvid,
                title: item.title ?? "未知标题",
                subtitle: item.authorName ?? "未知 UP 主",
                bvid: bvid,
                aid: item.history?.oid,
                cid: item.history?.cid,
                coverURL: coverURL
            )
        }
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