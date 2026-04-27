import Foundation

struct BiliBaseResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let ttl: Int?
    let data: T?
}
