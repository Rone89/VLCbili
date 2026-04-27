//
//  VideoInteractionService.swift
//  ccbili
//
//  Created by chuzu  on 2026/4/25.
//

import Foundation

struct VideoInteractionService {
    func like(aid: Int, like: Bool) async throws {
        try BiliAuthContext.requireLogin()
        let csrf = try BiliAuthContext.csrfToken()

        let url = AppConfig.apiBaseURL.appending(path: "/x/web-interface/archive/like")

        let response = try await APIClient.shared.postForm(
            url: url,
            form: [
                "aid": String(aid),
                "like": like ? "1" : "2",
                "csrf": csrf
            ],
            headers: [
                "Referer": "\(AppConfig.webBaseURL.absoluteString)/video/av\(aid)",
                "Origin": AppConfig.webBaseURL.absoluteString
            ],
            as: BiliActionResponseDTO.self
        )

        guard response.code == 0 else {
            throw APIError.serverMessage(response.message.isEmpty ? "点赞请求失败" : response.message)
        }
    }

    func coin(aid: Int, multiply: Int = 1, like: Bool = false) async throws {
        try BiliAuthContext.requireLogin()
        let csrf = try BiliAuthContext.csrfToken()

        let url = AppConfig.apiBaseURL.appending(path: "/x/web-interface/coin/add")

        let response = try await APIClient.shared.postForm(
            url: url,
            form: [
                "aid": String(aid),
                "multiply": String(max(1, min(multiply, 2))),
                "select_like": like ? "1" : "0",
                "csrf": csrf
            ],
            headers: [
                "Referer": "\(AppConfig.webBaseURL.absoluteString)/video/av\(aid)",
                "Origin": AppConfig.webBaseURL.absoluteString
            ],
            as: BiliActionResponseDTO.self
        )

        guard response.code == 0 else {
            throw APIError.serverMessage(response.message.isEmpty ? "投币请求失败" : response.message)
        }
    }

    func favoriteFolders(aid: Int) async throws -> [FavoriteFolderDTO] {
        try BiliAuthContext.requireLogin()

        var components = URLComponents(
            url: AppConfig.apiBaseURL.appending(path: "/x/v3/fav/folder/created/list-all"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "type", value: "2"),
            URLQueryItem(name: "rid", value: String(aid))
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response = try await APIClient.shared.get(
            url: url,
            headers: [
                "Referer": "\(AppConfig.webBaseURL.absoluteString)/video/av\(aid)"
            ],
            as: FavoriteFolderListResponseDTO.self
        )

        guard response.code == 0 else {
            throw APIError.serverMessage(response.message.isEmpty ? "获取收藏夹失败" : response.message)
        }

        return response.data?.list ?? []
    }

    func favorite(aid: Int, addMediaIDs: [Int], deleteMediaIDs: [Int] = []) async throws {
        try BiliAuthContext.requireLogin()
        let csrf = try BiliAuthContext.csrfToken()

        let url = AppConfig.apiBaseURL.appending(path: "/x/v3/fav/resource/deal")

        let json = try await APIClient.shared.postFormJSON(
            url: url,
            form: [
                "rid": String(aid),
                "type": "2",
                "add_media_ids": addMediaIDs.map(String.init).joined(separator: ","),
                "del_media_ids": deleteMediaIDs.map(String.init).joined(separator: ","),
                "csrf": csrf,
                "csrf_token": csrf
            ],
            headers: [
                "Referer": "\(AppConfig.webBaseURL.absoluteString)/video/av\(aid)",
                "Origin": AppConfig.webBaseURL.absoluteString
            ]
        )

        let code = json["code"] as? Int ?? -9999
        let message = (json["message"] as? String) ?? (json["msg"] as? String) ?? "收藏请求失败"

        guard code == 0 else {
            let dataDescription: String
            if let data = json["data"] {
                dataDescription = String(describing: data)
            } else {
                dataDescription = "nil"
            }

            throw APIError.serverMessage(
                """
                收藏请求失败
                code: \(code)
                message: \(message)
                data: \(dataDescription)
                """
            )
        }
    }
}
