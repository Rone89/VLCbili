//
//  PlayURLResponseDTO.swift
//  ccbili
//
//  Created by chuzu  on 2026/4/26.
//

import Foundation

struct PlayURLResponseDTO: Decodable {
    let code: Int
    let message: String
    let data: PlayURLDataDTO?
}

struct PlayURLDataDTO: Decodable {
    let duration: Int?
    let quality: Int?
    let format: String?
    let acceptQuality: [Int]?
    let acceptDescription: [String]?
    let acceptFormat: String?
    let durl: [PlayURLDURLDTO]?
    let dash: PlayURLDashDTO?

    enum CodingKeys: String, CodingKey {
        case duration = "timelength"
        case quality
        case format
        case acceptQuality = "accept_quality"
        case acceptDescription = "accept_description"
        case acceptFormat = "accept_format"
        case durl
        case dash
    }
}

struct PlayURLDURLDTO: Decodable {
    let url: String?
    let length: Int?
    let size: Int?
}

struct PlayURLDashDTO: Decodable {
    let video: [PlayURLDashVideoDTO]?
    let audio: [PlayURLDashAudioDTO]?
}

struct PlayURLDashVideoDTO: Decodable {
    let id: Int?
    let baseURL: String?
    let backupURL: [String]?
    let bandwidth: Int?
    let width: Int?
    let height: Int?
    let frameRate: String?
    let codecs: String?
    let mimeType: String?
    let segmentBase: PlayURLSegmentBaseDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case baseURL = "base_url"
        case backupURL = "backup_url"
        case bandwidth
        case width
        case height
        case frameRate = "frame_rate"
        case codecs
        case mimeType = "mime_type"
        case segmentBase = "segment_base"
    }
}

struct PlayURLDashAudioDTO: Decodable {
    let id: Int?
    let baseURL: String?
    let backupURL: [String]?
    let bandwidth: Int?
    let codecs: String?
    let mimeType: String?
    let segmentBase: PlayURLSegmentBaseDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case baseURL = "base_url"
        case backupURL = "backup_url"
        case bandwidth
        case codecs
        case mimeType = "mime_type"
        case segmentBase = "segment_base"
    }
}

struct PlayURLSegmentBaseDTO: Decodable {
    let initialization: String?
    let indexRange: String?

    enum CodingKeys: String, CodingKey {
        case initialization
        case indexRange = "index_range"
    }
}
