import Foundation

struct HomeRecommendationResponse: Decodable {
    let item: [HomeRecommendationItem]
}

struct HomeRecommendationItem: Decodable {
    let id: Int?
    let bvid: String?
    let title: String
    let goto: String?
    let pic: String?
    let owner: HomeRecommendationOwner?
}

struct HomeRecommendationOwner: Decodable {
    let mid: Int?
    let name: String?
}
