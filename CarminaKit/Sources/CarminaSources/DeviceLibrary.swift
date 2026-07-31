//
//  DeviceLibrary.swift
//  CarminaKit
//
//  Created by waru on 7/30/26.
//

import CarminaModels
import SwiftUI

#if canImport(MediaPlayer)
    import MediaPlayer
#endif

@MainActor
@Observable
public final class DeviceLibrary: MusicSource {
    public enum LoadState { case idle, loading, authorized, denied }

    public private(set) var state: LoadState = .idle
    public private(set) var songs: [Song] = []

    #if canImport(MediaPlayer)
        private var artworkByID: [UInt64: MPMediaItemArtwork] = [:]
    #endif

    public init() {}

    public nonisolated var sourceType: TrackSource { .device }

    public nonisolated func playbackAsset(for song: Song) -> PlayableAsset? {
        song.assetURL.map { PlayableAsset(url: $0) }
    }

    public var recentlyAdded: [Song] {
        Array(songs.sorted { $0.dateAdded > $1.dateAdded }.prefix(50))
    }

    public func load() async {
        state = .loading
        #if canImport(MediaPlayer) && !targetEnvironment(simulator)
            let status = await MPMediaLibrary.requestAuthorization()
            guard status == .authorized else {
                state = .denied
                songs = []
                return
            }

            let items = MPMediaQuery.songs().items ?? []
            songs = items.compactMap { item -> Song? in
                guard let url = item.assetURL, !item.hasProtectedAsset else {
                    return nil
                }
                #if canImport(MediaPlayer)
                    if let art = item.artwork {
                        artworkByID[item.persistentID] = art
                    }
                #endif
                return Song(
                    title: item.title ?? "Unknown",
                    artist: item.artist ?? "Unknown Artist",
                    album: item.albumTitle ?? "",
                    dateAdded: item.dateAdded,
                    isLocal: false,
                    persistentID: item.persistentID,
                    assetURL: url,
                    lyrics: item.lyrics
                )
            }
            state = .authorized
        #else
            songs = []
            state = .authorized
        #endif
    }

    public func remove(_ song: Song) { songs.removeAll { $0.id == song.id } }

    public func artworkImage(for id: UInt64?, size: CGSize) -> Image? {
        #if canImport(MediaPlayer)
            guard let id, let art = artworkByID[id],
                let ui = art.image(at: size)
            else { return nil }
            return Image(uiImage: ui)
        #else
            return nil
        #endif
    }

    #if canImport(MediaPlayer)
        public func artworkUIImage(for id: UInt64?) -> UIImage? {
            guard let id, let art = artworkByID[id] else { return nil }
            let natural = art.bounds.size
            guard natural.width > 0, natural.height > 0 else { return nil }
            let maxDimension: CGFloat = 1000
            let ratio = min(
                1,
                maxDimension / max(natural.width, natural.height)
            )
            let target = CGSize(
                width: natural.width * ratio,
                height: natural.height * ratio
            )
            return art.image(at: target)
        }
    #endif

    #if canImport(MediaPlayer)
        public func artwork(for id: UInt64?) -> MPMediaItemArtwork? {
            guard let id else { return nil }
            return artworkByID[id]
        }
    #endif
}
