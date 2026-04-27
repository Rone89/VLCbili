import Foundation

struct VideoItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let bvid: String?
    let aid: Int?
    let cid: Int?
    let coverURL: URL?

    init(
        id: String,
        title: String,
        subtitle: String,
        bvid: String? = nil,
        aid: Int? = nil,
        cid: Int? = nil,
        coverURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.bvid = bvid
        self.aid = aid
        self.cid = cid
        self.coverURL = coverURL
    }

    var resolvedBVID: String? {
        if let bvid, !bvid.isEmpty {
            return bvid
        }
        return id.hasPrefix("BV") ? id : nil
    }
}
