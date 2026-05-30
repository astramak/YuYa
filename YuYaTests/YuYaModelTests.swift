//
//  YuYaModelTests.swift
//  YuYaTests
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import MediaPlayer
import XCTest
@testable import YuYa

final class YuYaModelTests: XCTestCase {
    func testMusicServiceAllowListMatchesExactAndSubdomains() {
        XCTAssertTrue(MusicService.yandexMusic.allows(URL(string: "https://music.yandex.ru/home")!))
        XCTAssertTrue(MusicService.yandexMusic.allows(URL(string: "https://passport.yandex.ru/auth")!))
        XCTAssertTrue(MusicService.youtubeMusic.allows(URL(string: "https://music.youtube.com/playlist")!))
        XCTAssertTrue(MusicService.youtubeMusic.allows(URL(string: "https://accounts.google.com/signin")!))

        XCTAssertFalse(MusicService.yandexMusic.allows(URL(string: "https://example.com/")!))
        XCTAssertFalse(MusicService.youtubeMusic.allows(URL(string: "https://music.yandex.ru/home")!))
    }

    func testCustomServiceAllowsOnlyItsHost() {
        let service = MusicService.custom(
            displayName: "Example",
            homeURL: URL(string: "https://player.example.com/app")!
        )

        XCTAssertTrue(service.allows(URL(string: "https://player.example.com/app")!))
        XCTAssertTrue(service.allows(URL(string: "https://sub.player.example.com/app")!))
        XCTAssertFalse(service.allows(URL(string: "https://example.com/app")!))
    }

    func testYouTubeMusicUsesSafariLikeUserAgent() {
        XCTAssertNil(MusicService.yandexMusic.customUserAgent)
        XCTAssertTrue(MusicService.youtubeMusic.customUserAgent?.contains("Version/") == true)
        XCTAssertTrue(MusicService.youtubeMusic.customUserAgent?.contains("Safari/") == true)
        XCTAssertFalse(MusicService.youtubeMusic.customUserAgent?.contains("Chrome/") == true)
    }

    func testBuiltInServicesUsePinnedFavicons() {
        XCTAssertEqual(MusicService.youtubeMusic.fallbackFaviconURL, URL(string: "https://music.youtube.com/favicon.ico"))
        XCTAssertFalse(MusicService.youtubeMusic.acceptsDiscoveredFavicon(URL(string: "https://accounts.google.com/favicon.ico")!))
        XCTAssertFalse(MusicService.youtubeMusic.acceptsDiscoveredFavicon(URL(string: "https://www.google.com/favicon.ico")!))

        XCTAssertEqual(MusicService.yandexMusic.fallbackFaviconURL, URL(string: "https://music.yandex.ru/favicon.ico"))
    }

    func testDefaultServicesStartWithYouTubeThenYandex() {
        XCTAssertEqual(MusicService.defaultServices.map(\.id), [
            MusicService.youtubeMusicID,
            MusicService.yandexMusicID
        ])
        XCTAssertEqual(AppState.empty.selectedServiceID, MusicService.youtubeMusicID)
    }

    func testCustomServiceAcceptsOwnHostFavicon() {
        let service = MusicService.custom(
            displayName: "Example",
            homeURL: URL(string: "https://player.example.com/app")!
        )

        XCTAssertTrue(service.acceptsDiscoveredFavicon(URL(string: "https://player.example.com/assets/icon.png")!))
        XCTAssertFalse(service.acceptsDiscoveredFavicon(URL(string: "https://accounts.example.com/favicon.ico")!))
    }

    func testAppStateRoundTripsEditableServices() throws {
        let customService = MusicService.custom(
            displayName: "Example",
            homeURL: URL(string: "https://player.example.com")!
        )
        let state = AppState(
            services: [.yandexMusic, .youtubeMusic, customService],
            selectedServiceID: customService.id,
            lastURLsByService: [
                MusicService.yandexMusicID: URL(string: "https://music.yandex.ru/album/1")!,
                MusicService.youtubeMusicID: URL(string: "https://music.youtube.com/watch?v=abc")!,
                customService.id: URL(string: "https://player.example.com/album")!
            ],
            lastPlaybackSnapshot: PlaybackSnapshot(
                serviceID: customService.id,
                serviceName: customService.displayName,
                title: "Track",
                artist: "Artist",
                album: "Album",
                artworkURL: URL(string: "https://example.com/art.jpg"),
                duration: 120,
                position: 12,
                isPlaying: true,
                capabilities: .basic
            ),
            interfaceLanguage: .russian
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(AppState.self, from: data)

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.interfaceLanguage, .russian)
    }

    func testBridgeMessageDecodesPlaybackSnapshot() throws {
        let json = """
        {
          "type": "playback",
          "serviceID": "youtubeMusic",
          "snapshot": {
            "serviceID": "youtubeMusic",
            "serviceName": "YouTube Music",
            "title": "Track",
            "artist": "Artist",
            "album": "Album",
            "artworkURL": "https://example.com/art.jpg",
            "duration": 201.5,
            "position": 34.25,
            "isPlaying": true,
            "capabilities": {
              "canPlay": true,
              "canPause": true,
              "canTogglePlayPause": true,
              "canNextTrack": true,
              "canPreviousTrack": false
            }
          }
        }
        """

        let message = try JSONDecoder().decode(BridgeMessage.self, from: Data(json.utf8))

        XCTAssertEqual(message.type, .playback)
        XCTAssertEqual(message.serviceID, MusicService.youtubeMusicID)
        XCTAssertEqual(message.snapshot?.title, "Track")
        XCTAssertEqual(message.snapshot?.capabilities.canNextTrack, true)
        XCTAssertEqual(message.snapshot?.capabilities.canPreviousTrack, false)
    }

    @MainActor
    func testNowPlayingCommandRoutingUsesHandlerResult() {
        let controller = NowPlayingController()
        var routedCommands: [PlaybackCommand] = []

        controller.commandHandler = { command in
            routedCommands.append(command)
            return command == .nextTrack
        }

        XCTAssertEqual(controller.performForTesting(.nextTrack), .success)
        XCTAssertEqual(controller.performForTesting(.previousTrack), .commandFailed)
        XCTAssertEqual(routedCommands, [.nextTrack, .previousTrack])

        controller.clear()
    }
}
