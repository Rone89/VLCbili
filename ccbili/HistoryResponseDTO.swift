//
//  HistoryResponseDTO.swift
//  ccbili
//
//  Created by chuzu  on 2026/4/25.
//


import Foundation

struct HistoryResponseDTO: Decodable {
    let code: Int
    let message: String
    let data: [HistoryItemDTO]?
}

struct HistoryItemDTO: Decodable {
    let title: String?
    let authorName: String?
    let history: HistoryDetailDTO?
    let covers: [String]?
    let cover: String?
    let bvid: String?
    let videos: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case history
        case covers
        case cover
        case bvid
        case videos
    }
}

struct HistoryDetailDTO: Decodable {
    let bvid: String?
    let oid: Int?
    let cid: Int?
    let part: String?
    let dt: Int?

    enum CodingKeys: String, CodingKey {
        case bvid
        case oid
        case cid
        case part
        case dt
    }
}