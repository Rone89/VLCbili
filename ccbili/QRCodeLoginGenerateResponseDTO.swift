//
//  QRCodeLoginGenerateResponseDTO.swift
//  ccbili
//
//  Created by chuzu  on 2026/4/25.
//


import Foundation

struct QRCodeLoginGenerateResponseDTO: Decodable {
    let code: Int
    let message: String
    let data: QRCodeLoginGenerateDataDTO?
}

struct QRCodeLoginGenerateDataDTO: Decodable {
    let url: String?
    let qrcodeKey: String?

    enum CodingKeys: String, CodingKey {
        case url
        case qrcodeKey = "qrcode_key"
    }
}

struct QRCodeLoginPollResponseDTO: Decodable {
    let code: Int
    let message: String
    let data: QRCodeLoginPollDataDTO?
}

struct QRCodeLoginPollDataDTO: Decodable {
    let code: Int?
    let message: String?
    let url: String?
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case url
        case refreshToken = "refresh_token"
    }
}