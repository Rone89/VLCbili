import Foundation

struct ReplyService {
    struct CommentPage {
        let comments: [VideoComment]
        let nextOffset: String?
        let hasMore: Bool
    }

    struct ReplyPage {
        let replies: [VideoCommentPreviewReply]
        let nextPage: Int?
        let hasMore: Bool
    }

    func fetchVideoReplies(oid: Int, type: Int = 1, sort: Int = 1) async throws -> [VideoComment] {
        try await fetchVideoReplyPage(oid: oid, type: type, sort: sort, offset: nil).comments
    }

    func fetchVideoReplyPage(oid: Int, type: Int = 1, sort: Int = 1, offset: String?) async throws -> CommentPage {
        var components = URLComponents(
            url: AppConfig.apiBaseURL.appending(path: "/x/v2/reply/main"),
            resolvingAgainstBaseURL: false
        )

        let paginationOffset = offset ?? ""
        components?.queryItems = [
            URLQueryItem(name: "oid", value: String(oid)),
            URLQueryItem(name: "type", value: String(type)),
            URLQueryItem(name: "mode", value: String(sort + 2)),
            URLQueryItem(name: "pagination_str", value: "{\"offset\":\"\(paginationOffset)\"}")
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response = try await APIClient.shared.get(
            url: url,
            as: ReplyListResponse.self
        )

        guard response.code == 0 else {
            throw APIError.serverMessage(response.message)
        }

        let comments = (response.data?.replies ?? []).map { reply in
            VideoComment(
                id: String(reply.rpid ?? 0),
                username: reply.member?.uname ?? "未知用户",
                message: reply.content?.message ?? "",
                userID: reply.member?.mid,
                avatarURL: normalizedImageURL(from: reply.member?.avatar),
                timeText: formattedCommentTime(from: reply.ctime),
                likeCount: reply.like ?? 0,
                replyCount: reply.rcount ?? reply.replies?.count ?? 0,
                previewReplies: (reply.replies ?? []).prefix(2).map { child in
                    VideoCommentPreviewReply(
                        username: child.member?.uname ?? "未知用户",
                        message: child.content?.message ?? ""
                    )
                }
            )
        }

        let nextOffset = response.data?.cursor?.paginationReply?.nextOffset
        let isEnd = response.data?.cursor?.isEnd ?? (nextOffset?.isEmpty ?? true)
        let hasMore = !isEnd
        return CommentPage(comments: comments, nextOffset: nextOffset, hasMore: hasMore)
    }

    func fetchReplyReplies(oid: Int, root: Int, type: Int = 1) async throws -> [VideoCommentPreviewReply] {
        try await fetchReplyReplyPage(oid: oid, root: root, type: type, page: 1).replies
    }

    func fetchReplyReplyPage(oid: Int, root: Int, type: Int = 1, page: Int = 1) async throws -> ReplyPage {
        var components = URLComponents(
            url: AppConfig.apiBaseURL.appending(path: "/x/v2/reply/reply"),
            resolvingAgainstBaseURL: false
        )

        components?.queryItems = [
            URLQueryItem(name: "oid", value: String(oid)),
            URLQueryItem(name: "type", value: String(type)),
            URLQueryItem(name: "root", value: String(root)),
            URLQueryItem(name: "pn", value: String(page)),
            URLQueryItem(name: "ps", value: "20")
        ]

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let response = try await APIClient.shared.get(url: url, as: ReplyListResponse.self)
        guard response.code == 0 else {
            throw APIError.serverMessage(response.message)
        }

        let replies = (response.data?.replies ?? []).map { reply in
            VideoCommentPreviewReply(
                username: reply.member?.uname ?? "未知用户",
                message: reply.content?.message ?? ""
            )
        }

        let totalCount = response.data?.page?.count ?? 0
        let pageSize = response.data?.page?.size ?? 20
        let currentPage = response.data?.page?.num ?? page
        let hasMore = currentPage * pageSize < totalCount
        return ReplyPage(replies: replies, nextPage: hasMore ? currentPage + 1 : nil, hasMore: hasMore)
    }

    private func normalizedImageURL(from path: String?) -> URL? {
        guard let path, !path.isEmpty else {
            return nil
        }

        if path.hasPrefix("//") {
            return URL(string: "https:" + path)
        }

        return URL(string: path)
    }

    private func formattedCommentTime(from timestamp: Int?) -> String {
        guard let timestamp else {
            return "时间未知"
        }

        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
