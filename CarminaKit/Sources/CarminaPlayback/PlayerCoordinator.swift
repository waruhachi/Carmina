//
//  PlayerCoordinator.swift
//  CarminaKit
//
//  Created by waru on 7/17/26.
//

import AVFoundation
import CarminaModels
import CarminaSources
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(MediaPlayer)
    import MediaPlayer
#endif

@MainActor
@Observable
public final class PlayerCoordinator {
    public private(set) var queue: [Song] = []
    public private(set) var currentIndex = 0

    private let player = AVPlayer()
    private var endObserver: NSObjectProtocol?

    @ObservationIgnored public weak var library: DeviceLibrary?

    #if canImport(MediaPlayer)
        @ObservationIgnored private var artworkSongID: UUID?
        @ObservationIgnored private var cachedArtwork: MPMediaItemArtwork?
        @ObservationIgnored public var artworkProvider:
            (@MainActor (Song) -> UIImage?)?
    #endif

    public var isPlaying = false
    public var currentTime: Double = 0
    public var duration: Double = 0
    public var audioQuality: String?

    public var current: Song? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }
    public var previousSong: Song? {
        queue.indices.contains(currentIndex - 1) ? queue[currentIndex - 1] : nil
    }
    public var nextSong: Song? {
        queue.indices.contains(currentIndex + 1) ? queue[currentIndex + 1] : nil
    }
    public var hasQueue: Bool { !queue.isEmpty }

    public init() {
        player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.currentTime = time.seconds
                if let d = self.player.currentItem?.duration.seconds, d.isFinite
                {
                    self.duration = d
                }
            }
        }
        setupRemoteCommands()

        #if canImport(UIKit)
            _ = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.saveState() }
            }
        #endif

        #if os(iOS)
            _ = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard
                    let info = notification.userInfo,
                    let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                    let type = AVAudioSession.InterruptionType(rawValue: raw)
                else { return }
                MainActor.assumeIsolated {
                    guard let self else { return }
                    switch type {
                    case .began:
                        guard self.isPlaying else { return }
                        self.player.pause()
                        self.isPlaying = false
                        self.updateNowPlayingInfo()
                    case .ended:
                        guard
                            UserDefaults.standard.bool(
                                forKey: "resumeAfterInterruption"
                            ),
                            !self.isPlaying,
                            self.current != nil,
                            let optsRaw = info[
                                AVAudioSessionInterruptionOptionKey
                            ] as? UInt,
                            AVAudioSession.InterruptionOptions(
                                rawValue: optsRaw
                            )
                            .contains(.shouldResume)
                        else { return }
                        self.activateSession()
                        self.player.play()
                        self.isPlaying = true
                        self.updateNowPlayingInfo()
                    @unknown default:
                        break
                    }
                }
            }
        #endif
    }

    public func play(_ songs: [Song], startAt index: Int = 0) {
        queue = songs
        currentIndex = index
        startCurrent()
    }

    public func play(at index: Int) {
        guard queue.indices.contains(index) else { return }
        currentIndex = index
        startCurrent()
    }

    public func shuffle(_ songs: [Song]) {
        queue = songs.shuffled()
        currentIndex = 0
        startCurrent()
    }

    public func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            activateSession()
            player.play()
        }
        isPlaying.toggle()
        updateNowPlayingInfo()
        saveState()
    }

    public func next() {
        guard currentIndex + 1 < queue.count else { return }
        currentIndex += 1
        startCurrent(autoPlay: isPlaying)
    }

    public func previous() {
        if currentTime > 3 || currentIndex == 0 {
            seek(to: 0)
            return
        }

        previousTrack()
    }

    public func previousTrack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        startCurrent(autoPlay: isPlaying)
    }

    public func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        currentTime = seconds
        updateNowPlayingInfo()
        saveState()
    }

    public func playNext(_ song: Song) {
        if queue.isEmpty {
            play([song])
        } else {
            queue.insert(song, at: currentIndex + 1)
            saveState()
        }
    }

    public func playLast(_ song: Song) {
        if queue.isEmpty {
            play([song])
        } else {
            queue.append(song)
            saveState()
        }
    }

    public func playNext(_ songs: [Song]) {
        guard !songs.isEmpty else { return }
        if queue.isEmpty {
            play(songs)
        } else {
            queue.insert(contentsOf: songs, at: currentIndex + 1)
            saveState()
        }
    }

    public func playLast(_ songs: [Song]) {
        guard !songs.isEmpty else { return }
        if queue.isEmpty {
            play(songs)
        } else {
            queue.append(contentsOf: songs)
            saveState()
        }
    }

    public func updateSong(_ updated: Song) {
        var changed = false
        for i in queue.indices where queue[i].id == updated.id {
            queue[i] = updated
            changed = true
        }
        if changed {
            #if canImport(MediaPlayer)
                artworkSongID = nil
            #endif
            updateNowPlayingInfo()
            saveState()
        }
    }

    public func removeFromQueue(id: UUID) {
        guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }
        let wasCurrent = idx == currentIndex
        queue.remove(at: idx)

        if queue.isEmpty {
            player.pause()
            player.replaceCurrentItem(with: nil)
            isPlaying = false
            currentIndex = 0
            currentTime = 0
            duration = 0
            audioQuality = nil
            updateNowPlayingInfo()
            clearState()
            return
        }
        if idx < currentIndex {
            currentIndex -= 1
        } else if wasCurrent {
            if currentIndex >= queue.count { currentIndex = queue.count - 1 }
            startCurrent(autoPlay: isPlaying)
        }
        updateNowPlayingInfo()
        saveState()
    }

    private func startCurrent(autoPlay: Bool = true) {
        guard let url = current?.audioURL else { return }

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.next() }
        }

        if autoPlay {
            activateSession()
            player.play()
        }
        isPlaying = autoPlay
        currentTime = 0
        duration = 0
        audioQuality = nil
        updateNowPlayingInfo()
        saveState()

        Task {
            if let cm = try? await item.asset.load(.duration),
                cm.seconds.isFinite
            {
                duration = cm.seconds
                updateNowPlayingInfo()
            }
        }
        Task { await loadAudioQuality(url: url) }
    }

    private func activateSession(sampleRate: Double? = nil) {
        #if os(iOS)
            let mixWithOthers = UserDefaults.standard.bool(
                forKey: "mixWithOthers"
            )
            Task.detached {
                let session = AVAudioSession.sharedInstance()
                let options: AVAudioSession.CategoryOptions =
                    mixWithOthers ? [.mixWithOthers] : []
                try? session.setCategory(.playback, options: options)
                if let sampleRate, sampleRate > 48_000 {
                    try? session.setPreferredSampleRate(sampleRate)
                }
                try? session.setActive(true)
            }
        #endif
    }

    public func mixSettingChanged() {
        if isPlaying { activateSession() }
    }

    // MARK: - Persistence

    private struct PlaybackSnapshot: Codable {
        var queue: [Song]
        var index: Int
        var time: Double
    }

    private var stateURL: URL? {
        let fm = FileManager.default
        guard
            let dir = try? fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        else { return nil }
        return dir.appendingPathComponent("playback.json")
    }

    private func saveState() {
        guard !queue.isEmpty, let url = stateURL else { return }
        let t = player.currentTime().seconds
        let snapshot = PlaybackSnapshot(
            queue: queue,
            index: currentIndex,
            time: t.isFinite ? t : currentTime
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }

    public func restoreState() {
        guard queue.isEmpty,  // don't clobber an active session
            let url = stateURL,
            let data = try? Data(contentsOf: url),
            let snapshot = try? JSONDecoder().decode(
                PlaybackSnapshot.self,
                from: data
            ),
            !snapshot.queue.isEmpty,
            snapshot.queue.indices.contains(snapshot.index)
        else { return }

        let song = snapshot.queue[snapshot.index]

        // The last-played track was removed from the library → clean up, restore nothing.
        if let library, library.state == .authorized,
            let pid = song.persistentID,
            !library.songs.contains(where: { $0.persistentID == pid })
        {
            clearState()
            return
        }

        // No playable URL → nothing to restore; clean up.
        guard let assetURL = song.audioURL else {
            clearState()
            return
        }

        queue = snapshot.queue
        currentIndex = snapshot.index

        let item = AVPlayerItem(url: assetURL)
        player.replaceCurrentItem(with: item)
        if snapshot.time > 0 {
            player.seek(
                to: CMTime(seconds: snapshot.time, preferredTimescale: 600)
            )
        }
        currentTime = snapshot.time
        isPlaying = false

        Task {
            if let cm = try? await item.asset.load(.duration),
                cm.seconds.isFinite
            {
                duration = cm.seconds
            }
        }
        Task { await loadAudioQuality(url: assetURL) }
        updateNowPlayingInfo()
    }

    private func clearState() {
        guard let url = stateURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Now Playing / remote commands

    private func setupRemoteCommands() {
        #if canImport(MediaPlayer)
            let center = MPRemoteCommandCenter.shared()
            center.playCommand.addTarget { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, !self.isPlaying else {
                        return MPRemoteCommandHandlerStatus.commandFailed
                    }
                    self.togglePlayPause()
                    return .success
                }
            }
            center.pauseCommand.addTarget { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.isPlaying else {
                        return MPRemoteCommandHandlerStatus.commandFailed
                    }
                    self.togglePlayPause()
                    return .success
                }
            }
            center.togglePlayPauseCommand.addTarget { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.togglePlayPause()
                    return .success
                }
            }
            center.nextTrackCommand.addTarget { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.next()
                    return .success
                }
            }
            center.previousTrackCommand.addTarget { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.previous()
                    return .success
                }
            }
            center.changePlaybackPositionCommand.addTarget {
                [weak self] event in
                MainActor.assumeIsolated {
                    guard let self,
                        let e = event as? MPChangePlaybackPositionCommandEvent
                    else { return MPRemoteCommandHandlerStatus.commandFailed }
                    self.seek(to: e.positionTime)
                    return .success
                }
            }
        #endif
    }

    private func updateNowPlayingInfo() {
        #if canImport(MediaPlayer)
            guard let song = current else {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                return
            }
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPMediaItemPropertyTitle] = song.title
            info[MPMediaItemPropertyArtist] = song.artist
            info[MPMediaItemPropertyArtwork] = artwork(for: song)
            info[MPMediaItemPropertyPlaybackDuration] = duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #endif
    }

    private func loadAudioQuality(url: URL) async {
        let asset = AVURLAsset(url: url)
        guard
            let track = try? await asset.loadTracks(withMediaType: .audio)
                .first,
            let formats = try? await track.load(.formatDescriptions),
            let format = formats.first
        else {
            audioQuality = nil
            return
        }

        let subType = CMFormatDescriptionGetMediaSubType(format)
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?
            .pointee
        let sampleRate = asbd?.mSampleRate ?? 0
        let channels = asbd?.mChannelsPerFrame ?? 0

        switch subType {
        case kAudioFormatAppleLossless, kAudioFormatFLAC:
            audioQuality = sampleRate > 48_000 ? "Hi-Res Lossless" : "Lossless"
        case kAudioFormatLinearPCM:
            audioQuality = "Lossless"
        case kAudioFormatEnhancedAC3, kAudioFormatAC3:
            audioQuality = channels > 2 ? "Dolby Atmos" : "Dolby Digital"
        default:
            audioQuality = nil
        }

        if sampleRate > 48_000 {
            activateSession(sampleRate: sampleRate)
        }
    }

    #if canImport(MediaPlayer)
        private func artwork(for song: Song) -> MPMediaItemArtwork? {
            if artworkSongID == song.id { return cachedArtwork }
            artworkSongID = song.id

            if song.artworkCacheKey == nil,
                let deviceArt = library?.artwork(for: song.persistentID)
            {
                cachedArtwork = deviceArt
            } else if let image = artworkProvider?(song) {
                let size = image.size
                let art = UIGraphicsImageRenderer(size: size).image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                cachedArtwork = MPMediaItemArtwork(boundsSize: size) { _ in art
                }
            } else {
                cachedArtwork = nil
            }
            return cachedArtwork
        }
    #endif
}
