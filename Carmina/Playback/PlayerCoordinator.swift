//
//  PlayerCoordinator.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import AVFoundation
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(MediaPlayer)
    import MediaPlayer
#endif

@MainActor
@Observable
final class PlayerCoordinator {
    private(set) var queue: [Song] = []
    private(set) var currentIndex = 0

    private let player = AVPlayer()
    private var endObserver: NSObjectProtocol?

    @ObservationIgnored weak var library: DeviceLibrary?

    var isPlaying = false
    var currentTime: Double = 0
    var duration: Double = 0
    var audioQuality: String?

    var current: Song? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }
    var hasQueue: Bool { !queue.isEmpty }

    init() {
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
                self.updateNowPlayingInfo()
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

    func play(_ songs: [Song], startAt index: Int = 0) {
        queue = songs
        currentIndex = index
        startCurrent()
    }

    func play(at index: Int) {
        guard queue.indices.contains(index) else { return }
        currentIndex = index
        startCurrent()
    }

    func shuffle(_ songs: [Song]) {
        queue = songs.shuffled()
        currentIndex = 0
        startCurrent()
    }

    func togglePlayPause() {
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

    func next() {
        guard currentIndex + 1 < queue.count else { return }
        currentIndex += 1
        startCurrent(autoPlay: isPlaying)
    }

    func previous() {
        if currentTime > 3 || currentIndex == 0 {
            seek(to: 0)
            return
        }
        currentIndex -= 1
        startCurrent(autoPlay: isPlaying)
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        currentTime = seconds
        updateNowPlayingInfo()
        saveState()
    }

    func playNext(_ song: Song) {
        if queue.isEmpty {
            play([song])
        } else {
            queue.insert(song, at: currentIndex + 1)
            saveState()
        }
    }

    func playLast(_ song: Song) {
        if queue.isEmpty {
            play([song])
        } else {
            queue.append(song)
            saveState()
        }
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

    func mixSettingChanged() {
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

    func restoreState() {
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
            if !song.album.isEmpty {
                info[MPMediaItemPropertyAlbumTitle] = song.album
            }
            info[MPMediaItemPropertyPlaybackDuration] = duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            if let artwork = library?.artwork(for: song.persistentID) {
                info[MPMediaItemPropertyArtwork] = artwork
            } else {
                info[MPMediaItemPropertyArtwork] = nil
            }
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
}
