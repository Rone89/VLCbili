import Foundation

struct VideoDetailResponseDTO: Decodable {
    let bvid: String?
    let aid: Int?
    let cid: Int?
    let title: String?
    let desc: String?
    let pubdate: Int?
    let ctime: Int?
    let owner: VideoDetailOwnerDTO?
    let pages: [VideoDetailPageDTO]?
}

struct VideoDetailOwnerDTO: Decodable {
    let name: String?
    let mid: Int?
    let face: String?
}

struct VideoDetailPageDTO: Decodable {
    let cid: Int?
    let page: Int?
    let part: String?
}

struct RelatedVideoDTO: Decodable {
    let bvid: String?
    let aid: Int?
    let cid: Int?
    let title: String?
    let pic: String?
    let owner: RelatedVideoOwnerDTO?
}

struct RelatedVideoOwnerDTO: Decodable {
    let name: String?
}

struct UserCardResponseDTO: Decodable {
    let code: Int
    let message: String
    let data: UserCardDataDTO?
}

struct UserCardDataDTO: Decodable {
    let card: UserCardDTO?
    let follower: Int?
}

struct UserCardDTO: Decodable {
    let mid: String?
    let name: String?
    let face: String?
}
