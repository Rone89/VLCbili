import Foundation
import Observation

@Observable
final class AuthManager {
    var isLoggedIn = false
    var username: String?
    var avatarURL: URL?

    var isLoading = false
    var errorMessage: String?

    func refreshLoginStatus() async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let url = AppConfig.apiBaseURL.appending(path: "/x/web-interface/nav")
            let response = try await APIClient.shared.get(
                url: url,
                as: BiliBaseResponse<NavUserInfoDTO>.self
            )

            guard response.code == 0, let data = response.data else {
                isLoggedIn = false
                username = nil
                avatarURL = nil
                return
            }

            if data.isLogin == true {
                isLoggedIn = true
                username = data.uname ?? "已登录用户"
                avatarURL = normalizedImageURL(from: data.face)
            } else {
                isLoggedIn = false
                username = nil
                avatarURL = nil
            }
        } catch {
            isLoggedIn = false
            username = nil
            avatarURL = nil
            errorMessage = error.localizedDescription
        }
    }

    func loginDemo() {
        isLoggedIn = true
        username = "Demo User"
        avatarURL = nil
        errorMessage = nil
    }

    func logout() {
        clearBilibiliCookies()
        isLoggedIn = false
        username = nil
        avatarURL = nil
        errorMessage = nil
    }

    private func clearBilibiliCookies() {
        let storage = HTTPCookieStorage.shared
        let cookies = storage.cookies ?? []

        for cookie in cookies where cookie.domain.contains("bilibili.com") {
            storage.deleteCookie(cookie)
        }
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
}
