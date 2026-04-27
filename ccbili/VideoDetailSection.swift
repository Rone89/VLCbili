import Foundation

struct VideoAuthor: Hashable {
    let name: String
    let followerText: String
    let avatarURL: URL?
}

struct VideoComment: Identifiable, Hashable {
    let id: String
    let username: String
    let message: String
    let userID: String?
    let avatarURL: URL?
    let timeText: String
}

struct RelatedVideo: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let coverURL: URL?
}
