//
//  PlaybackModels.swift
//  YuYa
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import Foundation

enum PlaybackCommand: String, Codable {
    case play
    case pause
    case togglePlayPause
    case nextTrack
    case previousTrack
}

struct PlaybackCapabilities: Codable, Equatable {
    var canPlay: Bool
    var canPause: Bool
    var canTogglePlayPause: Bool
    var canNextTrack: Bool
    var canPreviousTrack: Bool

    static let empty = PlaybackCapabilities(
        canPlay: false,
        canPause: false,
        canTogglePlayPause: false,
        canNextTrack: false,
        canPreviousTrack: false
    )

    static let basic = PlaybackCapabilities(
        canPlay: true,
        canPause: true,
        canTogglePlayPause: true,
        canNextTrack: false,
        canPreviousTrack: false
    )
}

struct PlaybackSnapshot: Codable, Equatable {
    var serviceID: String
    var serviceName: String
    var title: String?
    var artist: String?
    var album: String?
    var artworkURL: URL?
    var duration: TimeInterval?
    var position: TimeInterval?
    var isPlaying: Bool
    var capabilities: PlaybackCapabilities

    enum CodingKeys: String, CodingKey {
        case service
        case serviceID
        case serviceName
        case title
        case artist
        case album
        case artworkURL
        case duration
        case position
        case isPlaying
        case capabilities
    }

    init(
        serviceID: String,
        serviceName: String,
        title: String?,
        artist: String?,
        album: String?,
        artworkURL: URL?,
        duration: TimeInterval?,
        position: TimeInterval?,
        isPlaying: Bool,
        capabilities: PlaybackCapabilities
    ) {
        self.serviceID = serviceID
        self.serviceName = serviceName
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.duration = duration
        self.position = position
        self.isPlaying = isPlaying
        self.capabilities = capabilities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedServiceID = try container.decodeIfPresent(String.self, forKey: .serviceID)
            ?? container.decodeIfPresent(String.self, forKey: .service)
            ?? MusicService.yandexMusicID

        let fallbackName = MusicService.defaultServices.first { $0.id == decodedServiceID }?.displayName ?? decodedServiceID
        serviceID = decodedServiceID
        serviceName = try container.decodeIfPresent(String.self, forKey: .serviceName) ?? fallbackName
        title = try container.decodeIfPresent(String.self, forKey: .title)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        artworkURL = try container.decodeIfPresent(URL.self, forKey: .artworkURL)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        position = try container.decodeIfPresent(TimeInterval.self, forKey: .position)
        isPlaying = try container.decodeIfPresent(Bool.self, forKey: .isPlaying) ?? false
        capabilities = try container.decodeIfPresent(PlaybackCapabilities.self, forKey: .capabilities) ?? .empty
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(serviceID, forKey: .serviceID)
        try container.encode(serviceName, forKey: .serviceName)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(artist, forKey: .artist)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encodeIfPresent(artworkURL, forKey: .artworkURL)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(position, forKey: .position)
        try container.encode(isPlaying, forKey: .isPlaying)
        try container.encode(capabilities, forKey: .capabilities)
    }
}

enum BridgeMessageType: String, Codable {
    case playback
    case commandResult
    case log
}

struct BridgeMessage: Codable, Equatable {
    var type: BridgeMessageType
    var serviceID: String
    var snapshot: PlaybackSnapshot?
    var command: PlaybackCommand?
    var succeeded: Bool?
    var message: String?

    enum CodingKeys: String, CodingKey {
        case type
        case service
        case serviceID
        case snapshot
        case command
        case succeeded
        case message
    }

    init(
        type: BridgeMessageType,
        serviceID: String,
        snapshot: PlaybackSnapshot?,
        command: PlaybackCommand?,
        succeeded: Bool?,
        message: String?
    ) {
        self.type = type
        self.serviceID = serviceID
        self.snapshot = snapshot
        self.command = command
        self.succeeded = succeeded
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(BridgeMessageType.self, forKey: .type)
        serviceID = try container.decodeIfPresent(String.self, forKey: .serviceID)
            ?? container.decodeIfPresent(String.self, forKey: .service)
            ?? MusicService.yandexMusicID
        snapshot = try container.decodeIfPresent(PlaybackSnapshot.self, forKey: .snapshot)
        command = try container.decodeIfPresent(PlaybackCommand.self, forKey: .command)
        succeeded = try container.decodeIfPresent(Bool.self, forKey: .succeeded)
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(serviceID, forKey: .serviceID)
        try container.encodeIfPresent(snapshot, forKey: .snapshot)
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(succeeded, forKey: .succeeded)
        try container.encodeIfPresent(message, forKey: .message)
    }
}

struct WebNavigationState: Equatable {
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
}
