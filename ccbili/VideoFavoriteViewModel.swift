import Foundation
import Observation

@Observable
final class VideoFavoriteViewModel {
    var isFavorite = false
    var isLoading = false
    var errorMessage: String?

    private let service = VideoInteractionService()

    func load(videoID: String) {
        errorMessage = nil
    }

    func favorite(video: VideoItem) async {
        guard let aid = video.aid else {
            errorMessage = "缺少 aid，暂时无法操作收藏"
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let folders = try await service.favoriteFolders(aid: aid)
            guard let firstFolderID = folders.first?.id else {
                throw APIError.serverMessage("未找到可用收藏夹")
            }

            try await service.favorite(
                aid: aid,
                addMediaIDs: [firstFolderID],
                deleteMediaIDs: []
            )

            isFavorite = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
