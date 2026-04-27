//
//  BiliActionResponseDTO.swift
//  ccbili
//
//  Created by chuzu  on 2026/4/25.
//


import Foundation

struct BiliActionResponseDTO: Decodable {
    let code: Int
    let message: String
    let ttl: Int?
}

struct FavoriteFolderListResponseDTO: Decodable {
    let code: Int
    let message: String
    let data: FavoriteFolderListDataDTO?
}

struct FavoriteFolderListDataDTO: Decodable {
    let list: [FavoriteFolderDTO]?
}

struct FavoriteFolderDTO: Decodable {
    let id: Int?
    let title: String?
    let mediaCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case mediaCount = "media_count"
    }
}