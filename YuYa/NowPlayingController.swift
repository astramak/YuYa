//
//  NowPlayingController.swift
//  YuYa
//
//  Created by Maksim Cherkasov on 30.05.2026.
//

import AppKit
import Foundation
import MediaPlayer

@MainActor
final class NowPlayingController {
    var commandHandler: ((PlaybackCommand) -> Bool)?

    private let nowPlayingCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var latestSnapshot: PlaybackSnapshot?
    private var latestInfo: [String: Any] = [:]
    private var artworkCache: [URL: MPMediaItemArtwork] = [:]
    private var artworkTask: Task<Void, Never>?

    init() {
        registerRemoteCommands()
        clear()
    }

    func update(with snapshot: PlaybackSnapshot?) {
        latestSnapshot = snapshot
        artworkTask?.cancel()

        guard let snapshot else {
            clear()
            return
        }

        latestInfo = makeNowPlayingInfo(from: snapshot, artwork: snapshot.artworkURL.flatMap { artworkCache[$0] })
        nowPlayingCenter.nowPlayingInfo = latestInfo
        updatePlaybackState(isPlaying: snapshot.isPlaying)
        updateRemoteCommandAvailability(snapshot.capabilities)

        if let artworkURL = snapshot.artworkURL, artworkCache[artworkURL] == nil {
            loadArtwork(from: artworkURL, for: snapshot)
        }
    }

    func clear() {
        latestSnapshot = nil
        latestInfo = [:]
        nowPlayingCenter.nowPlayingInfo = nil
        updatePlaybackState(isPlaying: false)
        updateRemoteCommandAvailability(.empty)
    }

    private func registerRemoteCommands() {
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.perform(.play) ?? .commandFailed
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.perform(.pause) ?? .commandFailed
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.perform(.togglePlayPause) ?? .commandFailed
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.perform(.nextTrack) ?? .commandFailed
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.perform(.previousTrack) ?? .commandFailed
        }
    }

    private func perform(_ command: PlaybackCommand) -> MPRemoteCommandHandlerStatus {
        guard commandHandler?(command) == true else {
            return .commandFailed
        }
        return .success
    }

#if DEBUG
    func performForTesting(_ command: PlaybackCommand) -> MPRemoteCommandHandlerStatus {
        perform(command)
    }
#endif

    private func makeNowPlayingInfo(
        from snapshot: PlaybackSnapshot,
        artwork: MPMediaItemArtwork?
    ) -> [String: Any] {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: snapshot.title ?? snapshot.serviceName,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: snapshot.isPlaying ? 1.0 : 0.0
        ]

        if let artist = snapshot.artist {
            info[MPMediaItemPropertyArtist] = artist
        }

        if let album = snapshot.album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }

        if let duration = snapshot.duration, duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        if let position = snapshot.position, position.isFinite, position >= 0 {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        }

        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        return info
    }

    private func updatePlaybackState(isPlaying: Bool) {
        nowPlayingCenter.playbackState = isPlaying ? .playing : .paused
    }

    private func updateRemoteCommandAvailability(_ capabilities: PlaybackCapabilities) {
        commandCenter.playCommand.isEnabled = capabilities.canPlay
        commandCenter.pauseCommand.isEnabled = capabilities.canPause
        commandCenter.togglePlayPauseCommand.isEnabled = capabilities.canTogglePlayPause
        commandCenter.nextTrackCommand.isEnabled = capabilities.canNextTrack
        commandCenter.previousTrackCommand.isEnabled = capabilities.canPreviousTrack
    }

    private func loadArtwork(from url: URL, for snapshot: PlaybackSnapshot) {
        artworkTask = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let image = NSImage(data: data) else {
                    return
                }

                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                    image
                }

                await MainActor.run {
                    guard let self,
                          self.latestSnapshot?.serviceID == snapshot.serviceID,
                          self.latestSnapshot?.title == snapshot.title,
                          self.latestSnapshot?.artworkURL == url
                    else {
                        return
                    }

                    self.artworkCache[url] = artwork
                    self.latestInfo = self.makeNowPlayingInfo(from: snapshot, artwork: artwork)
                    self.nowPlayingCenter.nowPlayingInfo = self.latestInfo
                }
            } catch {
                NSLog("YuYa artwork load failed: \(error)")
            }
        }
    }
}
