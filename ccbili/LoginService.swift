//
//  LoginService.swift
//  ccbili
//
//  Created by chuzu  on 2026/4/25.
//

import Foundation

struct LoginService {
    private let passportBaseURL = URL(string: "https://passport.bilibili.com")!

    private var defaultHeaders: [String: String] {
        [
            "Accept": "application/json, text/plain, */*",
            "Referer": "https://www.bilibili.com/",
            "Origin": "https://www.bilibili.com",
            "User-Agent": AppConfig.defaultUserAgent
        ]
    }

    func generateQRCode() async throws -> QRCodeLoginGenerateDataDTO {
        let url = passportBaseURL.appending(path: "/x/passport-login/web/qrcode/generate")

        let response = try await APIClient.shared.get(
            url: url,
            headers: defaultHeaders,
            as: QRCodeLoginGenerateResponseDTO.self
        )

        guard response.code == 0, let data = response.data else {
            throw APIError.serverMessage(response.message)
        }

        return data
    }

    func pollQRCodeLogin(qrcodeKey: String) async throws -> QRCodeLoginPollDataDTO {
        var components = URLComponents(
            url: passportBaseURL.appending(path: "/x/passport-login/web/qrcode/poll"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "qrcode_key", value: qrcodeKey)
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response = try await APIClient.shared.get(
            url: url,
            headers: defaultHeaders,
            as: QRCodeLoginPollResponseDTO.self
        )

        guard response.code == 0, let data = response.data else {
            throw APIError.serverMessage(response.message)
        }

        return data
    }
}
