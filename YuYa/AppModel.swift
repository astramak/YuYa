//
//  AppModel.swift
//  YuYa
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let windowLifecycle = WindowLifecycleController()

    @Published private(set) var services: [MusicService]

    @Published var selectedServiceID: String {
        didSet {
            if oldValue != selectedServiceID {
                ensureSelectedServiceIsValid()
                cancelForcedPause(for: selectedServiceID)
                if let service = selectedService {
                    _ = webViewModel(for: service)
                }
                persistState()
            }
        }
    }

    @Published private(set) var nowPlayingSnapshot: PlaybackSnapshot?
    @Published private(set) var playingServiceID: String?
    @Published private(set) var navigationStates: [String: WebNavigationState] = [:]
    @Published private(set) var faviconsByServiceID: [String: NSImage] = [:]
    @Published var interfaceLanguage: InterfaceLanguage {
        didSet {
            if oldValue != interfaceLanguage {
                persistState()
            }
        }
    }
    @Published var selectedSettingsTab: SettingsTab = .services

    var selectedService: MusicService? {
        services.first { $0.id == selectedServiceID } ?? services.first
    }

    var selectedNavigationState: WebNavigationState {
        navigationStates[selectedServiceID] ?? WebNavigationState()
    }

    var interfaceText: InterfaceText {
        InterfaceText(interfaceLanguage)
    }

    private let nowPlayingController = NowPlayingController()
    private let faviconLoader = FaviconLoader()
    private var serviceModels: [String: ServiceWebViewModel] = [:]
    private var snapshotsByServiceID: [String: PlaybackSnapshot] = [:]
    private var lastURLsByService: [String: URL]
    private var activePlaybackServiceID: String?
    private var forcedPauseRequestsByServiceID: [String: Date] = [:]
    private var forcedPauseTasksByServiceID: [String: Task<Void, Never>] = [:]
    private var faviconTasks: [String: Task<Void, Never>] = [:]

    init() {
        let restoredState = AppStateStore.load()
        services = restoredState.services.map {
            Self.normalizedRestoredService($0)
        }
        selectedServiceID = restoredState.selectedServiceID
        nowPlayingSnapshot = restoredState.lastPlaybackSnapshot
        playingServiceID = restoredState.lastPlaybackSnapshot?.isPlaying == true ? restoredState.lastPlaybackSnapshot?.serviceID : nil
        lastURLsByService = restoredState.lastURLsByService
        activePlaybackServiceID = restoredState.lastPlaybackSnapshot?.serviceID
        interfaceLanguage = restoredState.interfaceLanguage

        ensureSelectedServiceIsValid()
        syncServiceModels()
        services.forEach(loadFallbackFaviconIfNeeded)

        nowPlayingController.commandHandler = { [weak self] command in
            self?.handleRemoteCommand(command) ?? false
        }

        nowPlayingController.update(with: restoredState.lastPlaybackSnapshot)
    }

    func webViewModel(for service: MusicService) -> ServiceWebViewModel {
        if let existing = serviceModels[service.id] {
            existing.update(service: service)
            return existing
        }

        let model = ServiceWebViewModel(
            service: service,
            initialURL: lastURLsByService[service.id] ?? service.homeURL
        )
        model.delegate = self
        serviceModels[service.id] = model
        navigationStates[service.id] = model.navigationState
        loadFallbackFaviconIfNeeded(for: service)
        return model
    }

    func goBack() {
        guard let selectedService else {
            return
        }
        webViewModel(for: selectedService).goBack()
    }

    func goForward() {
        guard let selectedService else {
            return
        }
        webViewModel(for: selectedService).goForward()
    }

    func reload() {
        guard let selectedService else {
            return
        }
        webViewModel(for: selectedService).reload()
    }

    func openHome(for serviceID: String) {
        guard let service = service(withID: serviceID) else {
            return
        }
        webViewModel(for: service).loadHome()
    }

    func addService(displayName: String, urlString: String) -> Bool {
        guard let url = normalizedURL(from: urlString),
              let serviceName = normalizedName(from: displayName)
        else {
            return false
        }

        let service = MusicService.custom(displayName: serviceName, homeURL: url)
        services.append(service)
        selectedServiceID = service.id
        _ = webViewModel(for: service)
        persistState()
        return true
    }

    func updateService(serviceID: String, displayName: String, urlString: String) -> Bool {
        guard let index = services.firstIndex(where: { $0.id == serviceID }),
              let url = normalizedURL(from: urlString),
              let serviceName = normalizedName(from: displayName)
        else {
            return false
        }

        let previousURL = services[index].homeURL
        let updatedService = services[index].updating(displayName: serviceName, homeURL: url)
        services[index] = updatedService
        let model = webViewModel(for: updatedService)

        if previousURL != url {
            lastURLsByService[serviceID] = url
            model.loadHome()
        }

        loadFallbackFaviconIfNeeded(for: updatedService)
        persistState()
        return true
    }

    func moveServices(from source: IndexSet, to destination: Int) {
        let indexes = source.sorted()
        guard !indexes.isEmpty,
              indexes.allSatisfy({ services.indices.contains($0) })
        else {
            return
        }

        let movingServices = indexes.map { services[$0] }
        for index in indexes.reversed() {
            services.remove(at: index)
        }

        let removedBeforeDestination = indexes.filter { $0 < destination }.count
        let adjustedDestination = min(max(destination - removedBeforeDestination, 0), services.count)
        services.insert(contentsOf: movingServices, at: adjustedDestination)
        persistState()
    }

    func moveService(serviceID: String, by offset: Int) -> Bool {
        guard let currentIndex = services.firstIndex(where: { $0.id == serviceID }) else {
            return false
        }

        let targetIndex = currentIndex + offset
        guard services.indices.contains(targetIndex) else {
            return false
        }

        let service = services.remove(at: currentIndex)
        services.insert(service, at: targetIndex)
        persistState()
        return true
    }

    func removeService(serviceID: String) {
        guard services.count > 1,
              let index = services.firstIndex(where: { $0.id == serviceID })
        else {
            return
        }

        serviceModels[serviceID]?.pauseIfPlaying()
        serviceModels[serviceID] = nil
        navigationStates[serviceID] = nil
        snapshotsByServiceID[serviceID] = nil
        faviconsByServiceID[serviceID] = nil
        faviconTasks[serviceID]?.cancel()
        faviconTasks[serviceID] = nil
        cancelForcedPause(for: serviceID)
        lastURLsByService[serviceID] = nil

        services.remove(at: index)
        if selectedServiceID == serviceID {
            selectedServiceID = services[0].id
        }
        if playingServiceID == serviceID {
            playingServiceID = nil
        }
        if activePlaybackServiceID == serviceID {
            activePlaybackServiceID = nil
            setNowPlayingSnapshot(snapshotsByServiceID[selectedServiceID])
        }

        persistState()
    }

    func resetServicesToDefaults() {
        for model in serviceModels.values {
            model.pauseIfPlaying()
        }

        services = MusicService.defaultServices
        selectedServiceID = MusicService.youtubeMusicID
        activePlaybackServiceID = nil
        playingServiceID = nil
        snapshotsByServiceID = [:]
        lastURLsByService = [:]
        forcedPauseRequestsByServiceID = [:]
        forcedPauseTasksByServiceID.values.forEach { $0.cancel() }
        forcedPauseTasksByServiceID = [:]
        faviconsByServiceID = [:]
        faviconTasks.values.forEach { $0.cancel() }
        faviconTasks = [:]

        syncServiceModels()
        services.forEach(loadFallbackFaviconIfNeeded)
        setNowPlayingSnapshot(nil)
        persistState()
    }

    func service(withID serviceID: String) -> MusicService? {
        services.first { $0.id == serviceID }
    }

    func prepareForTermination() {
        for model in serviceModels.values {
            model.pauseIfPlaying()
        }
        persistState()
    }

    private func syncServiceModels() {
        let serviceIDs = Set(services.map(\.id))

        for removedServiceID in serviceModels.keys where !serviceIDs.contains(removedServiceID) {
            serviceModels[removedServiceID]?.pauseIfPlaying()
            serviceModels[removedServiceID] = nil
            cancelForcedPause(for: removedServiceID)
        }

        for service in services {
            _ = webViewModel(for: service)
        }
    }

    private func ensureSelectedServiceIsValid() {
        if !services.contains(where: { $0.id == selectedServiceID }) {
            selectedServiceID = services[0].id
        }
    }

    private static func normalizedRestoredService(_ service: MusicService) -> MusicService {
        let normalizedName: String
        switch service.id {
        case MusicService.yandexMusicID where service.displayName == "Yandex Music" || service.displayName == "Яндекс Музыка":
            normalizedName = MusicService.yandexMusic.displayName
        case MusicService.youtubeMusicID where service.displayName == "YouTube Music" || service.displayName == "YouTube":
            normalizedName = MusicService.youtubeMusic.displayName
        default:
            normalizedName = service.displayName
        }

        return service.updating(displayName: normalizedName, homeURL: service.homeURL)
    }

    private func handleRemoteCommand(_ command: PlaybackCommand) -> Bool {
        let targetServiceID = nowPlayingSnapshot?.serviceID ?? activePlaybackServiceID ?? selectedServiceID
        guard let service = service(withID: targetServiceID) else {
            return false
        }
        webViewModel(for: service).send(command)
        return true
    }

    private func handlePlaybackSnapshot(_ snapshot: PlaybackSnapshot) {
        var normalizedSnapshot = snapshot
        if let service = service(withID: snapshot.serviceID) {
            normalizedSnapshot.serviceName = service.displayName
        }

        snapshotsByServiceID[normalizedSnapshot.serviceID] = normalizedSnapshot

        if normalizedSnapshot.isPlaying {
            if shouldSuppressForcedPausedService(normalizedSnapshot.serviceID) {
                serviceModels[normalizedSnapshot.serviceID]?.forcePausePlayback()
                return
            }

            cancelForcedPause(for: normalizedSnapshot.serviceID)
            if activePlaybackServiceID != normalizedSnapshot.serviceID {
                pauseOtherServices(except: normalizedSnapshot.serviceID)
            }
            activePlaybackServiceID = normalizedSnapshot.serviceID
            playingServiceID = normalizedSnapshot.serviceID
            setNowPlayingSnapshot(normalizedSnapshot)
            return
        }

        if forcedPauseRequestsByServiceID[normalizedSnapshot.serviceID] == nil {
            cancelForcedPause(for: normalizedSnapshot.serviceID)
        }
        if playingServiceID == normalizedSnapshot.serviceID {
            playingServiceID = nil
        }

        if activePlaybackServiceID == normalizedSnapshot.serviceID || nowPlayingSnapshot?.serviceID == normalizedSnapshot.serviceID {
            setNowPlayingSnapshot(normalizedSnapshot)
        } else if nowPlayingSnapshot == nil {
            setNowPlayingSnapshot(normalizedSnapshot)
        }
    }

    private func pauseOtherServices(except serviceID: String) {
        for (candidateID, model) in serviceModels where candidateID != serviceID {
            forcedPauseRequestsByServiceID[candidateID] = Date()
            model.forcePausePlayback()
            scheduleForcedPauseRetries(for: candidateID, model: model)
        }
    }

    private func shouldSuppressForcedPausedService(_ serviceID: String) -> Bool {
        guard forcedPauseRequestsByServiceID[serviceID] != nil,
              let activePlaybackServiceID,
              activePlaybackServiceID != serviceID,
              selectedServiceID != serviceID
        else {
            return false
        }

        return true
    }

    private func scheduleForcedPauseRetries(for serviceID: String, model: ServiceWebViewModel) {
        forcedPauseTasksByServiceID[serviceID]?.cancel()
        forcedPauseTasksByServiceID[serviceID] = Task { @MainActor [weak self, weak model] in
            let retryDelays: [UInt64] = [
                250_000_000,
                700_000_000,
                1_200_000_000,
                2_000_000_000
            ]

            for delay in retryDelays {
                do {
                    try await Task.sleep(nanoseconds: delay)
                } catch {
                    return
                }

                guard !Task.isCancelled,
                      let self,
                      self.forcedPauseRequestsByServiceID[serviceID] != nil,
                      self.activePlaybackServiceID != serviceID,
                      self.selectedServiceID != serviceID
                else {
                    return
                }

                model?.forcePausePlayback()
            }
        }
    }

    private func cancelForcedPause(for serviceID: String) {
        forcedPauseRequestsByServiceID[serviceID] = nil
        forcedPauseTasksByServiceID[serviceID]?.cancel()
        forcedPauseTasksByServiceID[serviceID] = nil
    }

    private func setNowPlayingSnapshot(_ snapshot: PlaybackSnapshot?) {
        guard nowPlayingSnapshot != snapshot else {
            return
        }

        nowPlayingSnapshot = snapshot
        nowPlayingController.update(with: snapshot)
    }

    private func loadFallbackFaviconIfNeeded(for service: MusicService) {
        guard faviconsByServiceID[service.id] == nil,
              let url = service.fallbackFaviconURL
        else {
            return
        }

        loadFavicon(from: url, for: service.id)
    }

    private func loadFavicon(from url: URL, for serviceID: String) {
        faviconTasks[serviceID]?.cancel()
        faviconTasks[serviceID] = Task { [weak self] in
            guard let image = await self?.faviconLoader.image(from: url),
                  !Task.isCancelled
            else {
                return
            }

            await MainActor.run {
                self?.faviconsByServiceID[serviceID] = image
            }
        }
    }

    private func normalizedURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate),
              url.scheme == "http" || url.scheme == "https",
              url.host(percentEncoded: false) != nil
        else {
            return nil
        }

        return url
    }

    private func normalizedName(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func persistState() {
        let state = AppState(
            services: services,
            selectedServiceID: selectedServiceID,
            lastURLsByService: lastURLsByService,
            lastPlaybackSnapshot: nowPlayingSnapshot,
            interfaceLanguage: interfaceLanguage
        )
        AppStateStore.save(state)
    }
}

extension AppModel: ServiceWebViewModelDelegate {
    func serviceWebViewModel(_ model: ServiceWebViewModel, didReceive message: BridgeMessage) {
        switch message.type {
        case .playback:
            guard let snapshot = message.snapshot else {
                return
            }
            handlePlaybackSnapshot(snapshot)
        case .commandResult:
            if message.succeeded == false, let command = message.command {
                NSLog("YuYa command \(command.rawValue) failed on \(message.serviceID): \(message.message ?? "No message")")
            }
        case .log:
            if let message = message.message {
                NSLog("YuYa bridge log: \(message)")
            }
        }
    }

    func serviceWebViewModel(_ model: ServiceWebViewModel, didUpdateURL url: URL) {
        lastURLsByService[model.service.id] = url
        persistState()
    }

    func serviceWebViewModel(_ model: ServiceWebViewModel, didFindFaviconURL url: URL) {
        guard model.service.acceptsDiscoveredFavicon(url) else {
            return
        }

        loadFavicon(from: url, for: model.service.id)
    }

    func serviceWebViewModel(
        _ model: ServiceWebViewModel,
        didUpdateNavigationState navigationState: WebNavigationState
    ) {
        navigationStates[model.service.id] = navigationState
    }
}
