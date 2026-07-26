//
//  DeviceLibrary.swift
//  Carmina
//
//  Created by waru on 7/20/26.
//

import SwiftUI

#if canImport(MediaPlayer)
    import MediaPlayer
#endif

@MainActor
@Observable
final class DeviceLibrary {
    enum LoadState { case idle, loading, authorized, denied }

    private(set) var state: LoadState = .idle
    private(set) var songs: [Song] = []

    #if canImport(MediaPlayer)
        private var artworkByID: [UInt64: MPMediaItemArtwork] = [:]
    #endif

    var recentlyAdded: [Song] {
        Array(songs.sorted { $0.dateAdded > $1.dateAdded }.prefix(50))
    }

    func load() async {
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

    func remove(_ song: Song) { songs.removeAll { $0.id == song.id } }

    func artworkImage(for id: UInt64?, size: CGSize) -> Image? {
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
        func artworkUIImage(for id: UInt64?, size: CGSize) -> UIImage? {
            guard let id, let art = artworkByID[id] else { return nil }
            return art.image(at: size)
        }
    #endif

    #if canImport(MediaPlayer)
        func artwork(for id: UInt64?) -> MPMediaItemArtwork? {
            guard let id else { return nil }
            return artworkByID[id]
        }
    #endif
}
