import Foundation
import WebKit

enum BilibiliCookieStore {
    private static let storageKey = "bilibili.persisted.cookies"

    static func restoreToSharedStorage() {
        for cookie in persistedCookies() {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }

    static func persistSharedStorage() {
        persist(cookies: bilibiliCookies(from: HTTPCookieStorage.shared.cookies ?? []))
    }

    static func syncWebCookiesToSharedStorage() async {
        let cookieStore = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        persistAndShare(cookies: cookieStore)
    }

    static func restoreEverywhere() async {
        restoreToSharedStorage()
        await seedWebCookieStore(WKWebsiteDataStore.default().httpCookieStore)
        await syncWebCookiesToSharedStorage()
    }

    static func persistAndShare(cookies: [HTTPCookie]) {
        let filteredCookies = bilibiliCookies(from: cookies)
        guard !filteredCookies.isEmpty else { return }

        for cookie in filteredCookies {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
        persist(cookies: filteredCookies)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    static func seedWebCookieStore(_ cookieStore: WKHTTPCookieStore) async {
        for cookie in persistedCookies() {
            await cookieStore.setCookie(cookie)
        }
    }

    static func cookieHeader() -> String? {
        restoreToSharedStorage()

        let cookies = bilibiliCookies(from: HTTPCookieStorage.shared.cookies ?? [])
        guard !cookies.isEmpty else { return nil }

        let header = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"]
        return header?.isEmpty == false ? header : nil
    }

    private static func bilibiliCookies(from cookies: [HTTPCookie]) -> [HTTPCookie] {
        cookies.filter { cookie in
            cookie.domain.contains("bilibili.com") || cookie.domain.contains("biligame.com")
        }
    }

    private static func persist(cookies: [HTTPCookie]) {
        guard !cookies.isEmpty else { return }

        let properties = cookies.compactMap { cookie -> [String: Any]? in
            guard let properties = cookie.properties else { return nil }
            return Dictionary(uniqueKeysWithValues: properties.map { key, value in
                (key.rawValue, value)
            })
        }
        UserDefaults.standard.set(properties, forKey: storageKey)
    }

    private static func persistedCookies() -> [HTTPCookie] {
        guard let properties = UserDefaults.standard.array(forKey: storageKey) as? [[String: Any]] else {
            return []
        }

        return properties.compactMap { propertyMap in
            let typedProperties = Dictionary(uniqueKeysWithValues: propertyMap.map { key, value in
                (HTTPCookiePropertyKey(key), value)
            })
            return HTTPCookie(properties: typedProperties)
        }
    }
}

extension WKHTTPCookieStore {
    func setCookie(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { continuation in
            setCookie(cookie) {
                continuation.resume()
            }
        }
    }

    func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }
}
