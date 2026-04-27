import Foundation

struct SearchAllResponseDTO: Decodable {
    let code: Int
    let message: String
    let data: SearchAllDataDTO?
}

struct SearchAllDataDTO: Decodable {
    let result: [SearchResultItemDTO]?
}

struct SearchResultItemDTO: Decodable {
    let bvid: String?
    let aid: Int?
    let title: String?
    let author: String?
    let pic: String?
}
