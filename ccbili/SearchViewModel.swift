import Foundation
import Observation

@Observable
final class SearchViewModel {
    var keyword = ""
    var isLoading = false
    var errorMessage: String?
    var searchHistory: [String] = ["动画", "音乐", "游戏"]
    var results: [VideoItem] = []

    private let searchService = SearchService()

    func search() async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            results = []
            errorMessage = "请输入关键词"
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            results = try await searchService.searchAll(keyword: trimmed, page: 1)
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
    }

    func applyHistory(_ text: String) {
        keyword = text
    }

    func clearHistory() {
        searchHistory.removeAll()
    }
}
