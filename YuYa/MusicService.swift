//
//  MusicService.swift
//  YuYa
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import Foundation

struct MusicService: Codable, Hashable, Identifiable {
    let id: String
    var displayName: String
    var homeURL: URL
    var allowedHosts: Set<String>
    var customUserAgent: String?

    static let yandexMusicID = "yandexMusic"
    static let youtubeMusicID = "youtubeMusic"

    static let yandexMusic = MusicService(
        id: yandexMusicID,
        displayName: "Ya",
        homeURL: URL(string: "https://music.yandex.ru/home")!,
        allowedHosts: [
            "music.yandex.ru",
            "music.yandex.com",
            "passport.yandex.ru",
            "passport.yandex.com",
            "oauth.yandex.ru",
            "oauth.yandex.com",
            "login.yandex.ru",
            "login.yandex.com",
            "id.yandex.ru",
            "id.yandex.com",
            "yandex.ru",
            "yandex.com",
            "ya.ru"
        ],
        customUserAgent: nil
    )

    static let youtubeMusic = MusicService(
        id: youtubeMusicID,
        displayName: "Yu",
        homeURL: URL(string: "https://music.youtube.com/")!,
        allowedHosts: [
            "music.youtube.com",
            "youtube.com",
            "www.youtube.com",
            "accounts.google.com",
            "consent.google.com",
            "consent.youtube.com",
            "myaccount.google.com",
            "google.com",
            "www.google.com"
        ],
        customUserAgent: safariUserAgent
    )

    static let defaultServices: [MusicService] = [
        .youtubeMusic,
        .yandexMusic
    ]

    static let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_5) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15"

    static func custom(displayName: String, homeURL: URL) -> MusicService {
        MusicService(
            id: UUID().uuidString,
            displayName: displayName,
            homeURL: homeURL,
            allowedHosts: hosts(for: homeURL),
            customUserAgent: nil
        )
    }

    func updating(displayName: String, homeURL: URL) -> MusicService {
        var updated = self
        updated.displayName = displayName
        updated.homeURL = homeURL
        updated.allowedHosts = Self.allowedHosts(for: id, homeURL: homeURL)
        updated.customUserAgent = Self.customUserAgent(for: id)
        return updated
    }

    func allows(_ url: URL) -> Bool {
        guard url.scheme == "http" || url.scheme == "https",
              let host = url.host(percentEncoded: false)?.lowercased()
        else {
            return false
        }

        return allowedHosts.contains { allowedHost in
            host == allowedHost || host.hasSuffix(".\(allowedHost)")
        }
    }

    var fallbackFaviconURL: URL? {
        if let pinnedFaviconURL {
            return pinnedFaviconURL
        }

        guard let scheme = homeURL.scheme,
              let host = homeURL.host(percentEncoded: false)
        else {
            return nil
        }

        return URL(string: "\(scheme)://\(host)/favicon.ico")
    }

    var pinnedFaviconURL: URL? {
        switch id {
        case Self.yandexMusicID:
            return URL(string: "https://music.yandex.ru/favicon.ico")
        case Self.youtubeMusicID:
            return URL(string: "https://music.youtube.com/favicon.ico")
        default:
            return nil
        }
    }

    func acceptsDiscoveredFavicon(_ url: URL) -> Bool {
        guard pinnedFaviconURL == nil else {
            return false
        }

        guard let iconHost = url.host(percentEncoded: false)?.lowercased(),
              let serviceHost = homeURL.host(percentEncoded: false)?.lowercased()
        else {
            return false
        }

        return iconHost == serviceHost || iconHost.hasSuffix(".\(serviceHost)")
    }

    private static func allowedHosts(for id: String, homeURL: URL) -> Set<String> {
        switch id {
        case yandexMusicID:
            return yandexMusic.allowedHosts.union(hosts(for: homeURL))
        case youtubeMusicID:
            return youtubeMusic.allowedHosts.union(hosts(for: homeURL))
        default:
            return hosts(for: homeURL)
        }
    }

    private static func customUserAgent(for id: String) -> String? {
        id == youtubeMusicID ? safariUserAgent : nil
    }

    private static func hosts(for url: URL) -> Set<String> {
        guard let host = url.host(percentEncoded: false)?.lowercased() else {
            return []
        }
        return [host]
    }
}
