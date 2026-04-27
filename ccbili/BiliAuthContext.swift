//
//  BiliAuthContext.swift
//  ccbili
//
//  Created by chuzu  on 2026/4/25.
//


import Foundation

enum BiliAuthContext {
    static func csrfToken() throws -> String {
        guard let token = cookieValue(named: "bili_jct"), !token.isEmpty else {
            throw APIError.missingCSRF
        }
        return token
    }

    static func requireLogin() throws {
        guard let sessData = cookieValue(named: "SESSDATA"), !sessData.isEmpty else {
            throw APIError.unauthorized
        }
    }

    static func cookieValue(named name: String) -> String? {
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        return cookies.first(where: { $0.name == name })?.value
    }
}