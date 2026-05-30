//
//  AppState.swift
//  YuYa
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import Foundation

struct AppState: Codable, Equatable {
    var services: [MusicService]
    var selectedServiceID: String
    var lastURLsByService: [String: URL]
    var lastPlaybackSnapshot: PlaybackSnapshot?
    var interfaceLanguage: InterfaceLanguage

    static let empty = AppState(
        services: MusicService.defaultServices,
        selectedServiceID: MusicService.yandexMusicID,
        lastURLsByService: [:],
        lastPlaybackSnapshot: nil,
        interfaceLanguage: .system
    )

    enum CodingKeys: String, CodingKey {
        case services
        case selectedService
        case selectedServiceID
        case lastURLsByService
        case lastPlaybackSnapshot
        case interfaceLanguage
    }

    init(
        services: [MusicService],
        selectedServiceID: String,
        lastURLsByService: [String: URL],
        lastPlaybackSnapshot: PlaybackSnapshot?,
        interfaceLanguage: InterfaceLanguage = .system
    ) {
        let normalizedServices = Self.normalized(services)
        self.services = normalizedServices
        self.selectedServiceID = normalizedServices.contains { $0.id == selectedServiceID }
            ? selectedServiceID
            : normalizedServices[0].id
        self.lastURLsByService = lastURLsByService
        self.lastPlaybackSnapshot = lastPlaybackSnapshot
        self.interfaceLanguage = interfaceLanguage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedServices = try container.decodeIfPresent([MusicService].self, forKey: .services)
        services = Self.normalized(decodedServices ?? MusicService.defaultServices)

        if let selectedServiceID = try container.decodeIfPresent(String.self, forKey: .selectedServiceID) {
            self.selectedServiceID = selectedServiceID
        } else {
            self.selectedServiceID = try container.decodeLegacySelectedServiceID(forKey: .selectedService) ?? MusicService.yandexMusicID
        }

        lastPlaybackSnapshot = try container.decodeIfPresent(PlaybackSnapshot.self, forKey: .lastPlaybackSnapshot)
        lastURLsByService = try container.decodeIfPresent([String: URL].self, forKey: .lastURLsByService) ?? [:]
        interfaceLanguage = try container.decodeIfPresent(InterfaceLanguage.self, forKey: .interfaceLanguage) ?? .system

        if !services.contains(where: { $0.id == selectedServiceID }) {
            selectedServiceID = services[0].id
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(services, forKey: .services)
        try container.encode(selectedServiceID, forKey: .selectedServiceID)
        try container.encode(lastURLsByService, forKey: .lastURLsByService)
        try container.encodeIfPresent(lastPlaybackSnapshot, forKey: .lastPlaybackSnapshot)
        try container.encode(interfaceLanguage, forKey: .interfaceLanguage)
    }

    private static func normalized(_ services: [MusicService]) -> [MusicService] {
        var seen = Set<String>()
        let filtered = services.compactMap { service -> MusicService? in
            guard !service.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  service.homeURL.scheme == "http" || service.homeURL.scheme == "https",
                  !seen.contains(service.id)
            else {
                return nil
            }

            seen.insert(service.id)
            return service
        }

        return filtered.isEmpty ? MusicService.defaultServices : filtered
    }
}

private extension KeyedDecodingContainer where K == AppState.CodingKeys {
    func decodeLegacySelectedServiceID(forKey key: K) throws -> String? {
        guard contains(key) else {
            return nil
        }

        if let value = try? decode(String.self, forKey: key) {
            return value
        }

        if let value = try? decode(MusicService.self, forKey: key) {
            return value.id
        }

        return nil
    }
}

enum AppStateStore {
    private static let key = "YuYa.AppState.v2"
    private static let legacyKey = "YuYa.AppState.v1"

    static func load() -> AppState {
        if let state = load(forKey: key) {
            return state
        }

        if let legacyState = load(forKey: legacyKey) {
            save(legacyState)
            return legacyState
        }

        return .empty
    }

    static func save(_ state: AppState) {
        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            assertionFailure("Failed to persist app state: \(error)")
        }
    }

    private static func load(forKey key: String) -> AppState? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(AppState.self, from: data)
        } catch {
            return nil
        }
    }
}
