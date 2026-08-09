//
//  Library.swift
//  Carmina
//
//  Created by waru on 7/30/26.
//

import AVFoundation
import CarminaMatch
import CarminaTagging
import SwiftData
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

@MainActor
@Observable
final class Library {
    @ObservationIgnored weak var player: PlayerCoordinator?
    @ObservationIgnored private var _songLookup: [String: Song]?

    private let device: DeviceLibrary
    private let context: ModelContext

    private let matcher = ITunesSearchClient()
    private var isMatching = false

    private let artworkStore = ArtworkStore()
    private let tagWriter = TagWriter()

    private(set) var imported: [Song] = [] {
        didSet { _songLookup = nil }
    }
    private(set) var deviceSongs: [Song] = [] {
        didSet { _songLookup = nil }
    }

    private(set) var needsReviewIDs: Set<UUID> = []
    private(set) var revertableIDs: Set<UUID> = []

    private(set) var playlists: [Playlist] = []

    private struct OverrideValues {
        var title: String?
        var artist: String?
        var album: String?
        var artworkCacheKey: String?
    }
    private var overrides: [String: OverrideValues] = [:]

    init(device: DeviceLibrary, context: ModelContext) {
        self.device = device
        self.context = context
    }

    var state: DeviceLibrary.LoadState { device.state }

    var songs: [Song] { deviceSongs + imported }

    var recentlyAdded: [Song] {
        Array(songs.sorted { $0.dateAdded > $1.dateAdded }.prefix(50))
    }

    func load() async {
        await device.load()

        reloadOverrides()
        rebuildDeviceSongs()
        reloadImported()
        reloadPlaylists()
        startMatching()
    }

    func remove(_ song: Song) {
        if song.isLocal {
            removeImported(song)
        } else {
            device.remove(song)
            rebuildDeviceSongs()
        }
        player?.removeFromQueue(id: song.id)
    }

    func importFiles(_ urls: [URL]) {
        Task { await performImport(urls) }
    }

    // MARK: - Artwork

    func artworkImage(for song: Song, size: CGSize) -> Image? {
        if let key = song.artworkCacheKey {
            return artworkStore.image(for: key)
        }
        if let pid = song.persistentID {
            return device.artworkImage(for: pid, size: size)
        }
        return nil
    }

    #if canImport(MediaPlayer)
        func artworkUIImage(for song: Song) -> UIImage? {
            if let key = song.artworkCacheKey {
                return artworkStore.uiImage(for: key)
            }
            if let pid = song.persistentID {
                return device.artworkUIImage(for: pid)
            }
            return nil
        }
    #endif

    // MARK: - Imported store

    private var localLibraryDir: URL? {
        let fm = FileManager.default
        guard
            let base = try? fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        else { return nil }
        return base.appendingPathComponent("LocalLibrary", isDirectory: true)
    }

    private func reloadImported() {
        guard let dir = localLibraryDir else {
            imported = []
            needsReviewIDs = []
            return
        }
        let descriptor = FetchDescriptor<Track>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        let tracks = (try? context.fetch(descriptor)) ?? []
        imported = tracks.map { t in
            Song(
                id: t.id,
                title: t.title,
                artist: t.artist,
                album: t.album,
                dateAdded: t.dateAdded,
                isLocal: true,
                persistentID: nil,
                assetURL: t.localRelativePath.map {
                    dir.appendingPathComponent($0)
                },
                lyrics: t.lyrics,
                artworkCacheKey: t.artworkCacheKey,
                duration: t.duration > 0 ? t.duration : nil
            )
        }
        needsReviewIDs = Set(
            tracks
                .filter { $0.matchState == .unmatched && $0.matchAttempted }
                .map(\.id)
        )
        revertableIDs = Set(
            tracks.filter { $0.matchState != .unmatched }.map(\.id)
        )
    }

    private func removeImported(_ song: Song) {
        let id = song.id
        let descriptor = FetchDescriptor<Track>(
            predicate: #Predicate { $0.id == id }
        )
        guard let track = try? context.fetch(descriptor).first else { return }
        if let rel = track.localRelativePath, let dir = localLibraryDir {
            try? FileManager.default.removeItem(
                at: dir.appendingPathComponent(rel)
            )
        }
        context.delete(track)
        try? context.save()
        reloadImported()
    }

    /// Copies a picked file into the container, coordinating access and
    /// downloading it first if it's an iCloud-Drive placeholder.
    private func copyIntoLibrary(from url: URL, to dest: URL) async throws {
        await ensureDownloaded(url)

        let fm = FileManager.default
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinationError
        ) { readURL in
            do {
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.copyItem(at: readURL, to: dest)
            } catch {
                copyError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
    }

    /// If the URL is a non-downloaded iCloud item, start the download and
    /// wait (up to ~30s) for it to materialize.
    private func ensureDownloaded(_ url: URL) async {
        let fm = FileManager.default
        guard
            let values = try? url.resourceValues(forKeys: [
                .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey,
            ]),
            values.isUbiquitousItem == true
        else { return }

        if values.ubiquitousItemDownloadingStatus == .current { return }
        try? fm.startDownloadingUbiquitousItem(at: url)

        for _ in 0..<60 {
            try? await Task.sleep(for: .milliseconds(500))
            if let v = try? url.resourceValues(
                forKeys: [.ubiquitousItemDownloadingStatusKey]
            ), v.ubiquitousItemDownloadingStatus == .current {
                return
            }
        }
    }

    private func performImport(_ urls: [URL]) async {
        let fm = FileManager.default
        guard let dir = localLibraryDir else { return }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
            let filename = "\(UUID().uuidString).\(ext)"
            let dest = dir.appendingPathComponent(filename)
            do {
                try await copyIntoLibrary(from: url, to: dest)
            } catch {
                continue
            }

            let fallback = url.deletingPathExtension().lastPathComponent
            let meta = await readEmbeddedMetadata(dest)
            let hasTitle = !meta.title.isEmpty
            let title = hasTitle ? meta.title : fallback

            var artworkKey: String?
            if let data = meta.artworkData {
                let key = UUID().uuidString
                artworkStore.store(data, key: key)
                artworkKey = key
            }

            let complete =
                hasTitle && !meta.artist.isEmpty && !meta.album.isEmpty
                && artworkKey != nil

            context.insert(
                Track(
                    source: .imported,
                    title: title,
                    artist: meta.artist,
                    album: meta.album,
                    dateAdded: Date(),
                    localRelativePath: filename,
                    fileFormat: ext,
                    importedFileName: fallback,
                    artworkCacheKey: artworkKey,
                    matchState: complete ? .matched : .unmatched,
                    matchAttempted: complete,
                    duration: meta.duration
                )
            )
        }

        try? context.save()
        reloadImported()
        startMatching()
    }

    private func readEmbeddedMetadata(
        _ url: URL
    ) async -> (
        title: String, artist: String, album: String, artworkData: Data?,
        duration: Double
    ) {
        let asset = AVURLAsset(url: url)

        var title = ""
        var artist = ""
        var album = ""
        var artworkData: Data?
        var duration: Double = 0

        if let cm = try? await asset.load(.duration), cm.seconds.isFinite {
            duration = cm.seconds
        }

        if let items = try? await asset.load(.commonMetadata) {
            for item in items {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    if let v = try? await item.load(.stringValue) { title = v }
                case .commonKeyArtist:
                    if let v = try? await item.load(.stringValue) { artist = v }
                case .commonKeyAlbumName:
                    if let v = try? await item.load(.stringValue) { album = v }
                case .commonKeyArtwork:
                    if let d = try? await item.load(.dataValue) {
                        artworkData = d
                    }
                default:
                    break
                }
            }
        }

        return (title, artist, album, artworkData, duration)
    }

    // MARK: - Auto-matching (iTunes)

    func startMatching() {
        guard !isMatching else { return }
        Task { await matchUnmatched() }
    }

    private func matchUnmatched() async {
        isMatching = true
        defer { isMatching = false }
        guard let dir = localLibraryDir else { return }

        while true {
            // raw-string compare because #Predicate can't use the enum directly
            var descriptor = FetchDescriptor<Track>(
                predicate: #Predicate {
                    $0.sourceRaw == "imported"
                        && $0.matchStateRaw == "unmatched"
                        && $0.matchAttempted == false
                }
            )
            descriptor.fetchLimit = 1
            guard let track = try? context.fetch(descriptor).first else {
                break
            }

            await matchOne(track, dir: dir)
            reloadImported()
            try? await Task.sleep(for: .seconds(3))  // iTunes rate limit
        }
    }

    private func matchOne(_ track: Track, dir: URL) async {
        var duration: Double?
        if let rel = track.localRelativePath {
            let asset = AVURLAsset(url: dir.appendingPathComponent(rel))
            if let cm = try? await asset.load(.duration), cm.seconds.isFinite {
                duration = cm.seconds
            }
        }

        let term = [track.artist, track.title]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard
            !term.isEmpty,
            let candidates = try? await matcher.search(term: term),
            !candidates.isEmpty
        else {
            track.matchAttempted = true
            try? context.save()
            return
        }

        let query = MetadataQuery(
            title: track.title,
            artist: track.artist,
            durationSeconds: duration
        )
        guard let best = MatchScorer.best(candidates, for: query),
            best.confidence >= 0.75
        else {
            track.matchAttempted = true
            try? context.save()
            return
        }

        let textComplete =
            !track.title.isEmpty && !track.artist.isEmpty
            && !track.album.isEmpty

        if !textComplete {
            track.title = best.title
            track.artist = best.artist
            track.album = best.album
        }

        track.matchedStoreID = String(best.id)
        track.matchConfidence = best.confidence
        track.matchState = .matched

        try? context.save()

        if track.artworkCacheKey == nil,
            let artURL = best.artworkURL,
            let (data, _) = try? await URLSession.shared.data(from: artURL)
        {
            let key = String(best.id)
            artworkStore.store(data, key: key)
            track.artworkCacheKey = key
            try? context.save()
        }

        reloadImported()

        if let updated = songs.first(where: { $0.id == track.id }) {
            player?.updateSong(updated)
        }
    }

    func searchMatches(_ term: String) async -> [MatchCandidate] {
        (try? await matcher.search(term: term, limit: 25)) ?? []
    }

    func applyEdit(
        to song: Song,
        title: String,
        artist: String,
        album: String,
        newArtworkData: Data?
    ) async {
        if song.isLocal {
            let songID = song.id
            let descriptor = FetchDescriptor<Track>(
                predicate: #Predicate { $0.id == songID }
            )
            guard let track = try? context.fetch(descriptor).first else {
                return
            }
            track.title = title
            track.artist = artist
            track.album = album
            track.matchState = .manual
            track.matchAttempted = true
            if let data = newArtworkData {
                let key = UUID().uuidString
                artworkStore.store(data, key: key)
                track.artworkCacheKey = key
            }
            try? context.save()
            reloadImported()
        } else if let pid = song.persistentID {
            let key = String(pid)
            let descriptor = FetchDescriptor<MetadataOverride>(
                predicate: #Predicate { $0.devicePersistentID == key }
            )
            let existing = try? context.fetch(descriptor).first
            let override = existing ?? MetadataOverride(devicePersistentID: key)
            override.title = title
            override.artist = artist
            override.album = album
            override.dateModified = Date()
            if let data = newArtworkData {
                let artKey = UUID().uuidString
                artworkStore.store(data, key: artKey)
                override.artworkCacheKey = artKey
            }
            if existing == nil { context.insert(override) }
            try? context.save()
            reloadOverrides()
            rebuildDeviceSongs()
        }

        if let updated = songs.first(where: { $0.id == song.id }) {
            player?.updateSong(updated)
        }
    }

    private func reloadOverrides() {
        let rows =
            (try? context.fetch(FetchDescriptor<MetadataOverride>())) ?? []
        overrides = Dictionary(
            rows.map {
                (
                    $0.devicePersistentID,
                    OverrideValues(
                        title: $0.title,
                        artist: $0.artist,
                        album: $0.album,
                        artworkCacheKey: $0.artworkCacheKey
                    )
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func rebuildDeviceSongs() {
        deviceSongs = device.songs.map(applyingOverride)
    }

    private func applyingOverride(_ song: Song) -> Song {
        guard let pid = song.persistentID,
            let o = overrides[String(pid)]
        else { return song }
        return Song(
            id: song.id,
            title: o.title ?? song.title,
            artist: o.artist ?? song.artist,
            album: o.album ?? song.album,
            dateAdded: song.dateAdded,
            isLocal: song.isLocal,
            persistentID: song.persistentID,
            assetURL: song.assetURL,
            lyrics: song.lyrics,
            artworkCacheKey: o.artworkCacheKey ?? song.artworkCacheKey
        )
    }

    func hasOverride(for song: Song) -> Bool {
        guard let pid = song.persistentID else { return false }
        return overrides[String(pid)] != nil
    }

    func removeOverride(for song: Song) {
        guard let pid = song.persistentID else { return }
        let key = String(pid)
        let descriptor = FetchDescriptor<MetadataOverride>(
            predicate: #Predicate { $0.devicePersistentID == key }
        )
        if let existing = try? context.fetch(descriptor).first {
            if let artKey = existing.artworkCacheKey {
                artworkStore.remove(artKey)
            }
            context.delete(existing)
            try? context.save()
        }
        reloadOverrides()
        rebuildDeviceSongs()
        if let updated = songs.first(where: { $0.id == song.id }) {
            player?.updateSong(updated)
        }
    }

    func canRevert(_ song: Song) -> Bool {
        if song.isLocal { return revertableIDs.contains(song.id) }
        return hasOverride(for: song)
    }

    func revertToOriginal(_ song: Song) async {
        if song.isLocal {
            let songID = song.id
            guard let dir = localLibraryDir else { return }
            let descriptor = FetchDescriptor<Track>(
                predicate: #Predicate { $0.id == songID }
            )
            guard let track = try? context.fetch(descriptor).first,
                let rel = track.localRelativePath
            else { return }

            let meta = await readEmbeddedMetadata(
                dir.appendingPathComponent(rel)
            )
            track.title =
                meta.title.isEmpty
                ? (track.importedFileName ?? track.title) : meta.title
            track.artist = meta.artist
            track.album = meta.album

            if let oldKey = track.artworkCacheKey {
                artworkStore.remove(oldKey)
            }
            if let artData = meta.artworkData {
                let key = UUID().uuidString
                artworkStore.store(artData, key: key)
                track.artworkCacheKey = key
            } else {
                track.artworkCacheKey = nil
            }
            track.matchState = .manual  // keep the original; don't auto-re-match
            track.matchAttempted = true
            try? context.save()
            reloadImported()
        } else if song.persistentID != nil {
            removeOverride(for: song)  // already reloads + updates the player
            return
        }

        if let updated = songs.first(where: { $0.id == song.id }) {
            player?.updateSong(updated)
        }
    }

    func exportForSharing(_ song: Song) async -> URL? {
        guard song.isLocal, let dir = localLibraryDir else { return nil }
        let songID = song.id
        let descriptor = FetchDescriptor<Track>(
            predicate: #Predicate { $0.id == songID }
        )
        guard let track = try? context.fetch(descriptor).first,
            let rel = track.localRelativePath
        else { return nil }

        let source = dir.appendingPathComponent(rel)
        let ext = track.fileFormat ?? source.pathExtension
        let name = shareFileName(for: track)

        let fm = FileManager.default
        let shareDir = fm.temporaryDirectory
            .appendingPathComponent("Share", isDirectory: true)
        try? fm.createDirectory(at: shareDir, withIntermediateDirectories: true)
        let dest = shareDir.appendingPathComponent("\(name).\(ext)")
        try? fm.removeItem(at: dest)
        do {
            try fm.copyItem(at: source, to: dest)
        } catch {
            return nil
        }

        // Embed current metadata (best-effort; MP3/M4A only).
        let artwork = track.artworkCacheKey.flatMap {
            artworkStore.data(for: $0)
        }
        let meta = TagMetadata(
            title: track.title,
            artist: track.artist,
            album: track.album,
            artwork: artwork
        )
        try? await tagWriter.write(meta, to: dest)

        return dest
    }

    private func shareFileName(for track: Track) -> String {
        let base = [track.artist, track.title]
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
        let name = base.isEmpty ? (track.importedFileName ?? "Track") : base
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        return name.components(separatedBy: invalid).joined(separator: "_")
    }

    // MARK: - Playlists

    private func reloadPlaylists() {
        let descriptor = FetchDescriptor<Playlist>(
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        playlists = (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func createPlaylist(name: String) -> Playlist {
        let playlist = Playlist(name: name)
        context.insert(playlist)
        try? context.save()
        reloadPlaylists()
        return playlist
    }

    func renamePlaylist(_ playlist: Playlist, to name: String) {
        playlist.name = name
        playlist.dateModified = Date()
        try? context.save()
        reloadPlaylists()
    }

    func deletePlaylist(_ playlist: Playlist) {
        context.delete(playlist)
        try? context.save()
        reloadPlaylists()
    }

    private func seedArtKeysIfNeeded(_ playlist: Playlist) {
        if playlist.artKeys.isEmpty, !playlist.itemKeys.isEmpty {
            playlist.artKeys = playlist.itemKeys
        }
    }

    func addSong(_ song: Song, to playlist: Playlist) {
        seedArtKeysIfNeeded(playlist)
        let key = playlistKey(for: song)
        playlist.itemKeys.append(key)
        playlist.artKeys.append(key)
        playlist.dateModified = Date()
        try? context.save()
        reloadPlaylists()
    }

    func addSongs(_ songs: [Song], to playlist: Playlist) {
        guard !songs.isEmpty else { return }
        seedArtKeysIfNeeded(playlist)
        let keys = songs.map { playlistKey(for: $0) }
        playlist.itemKeys.append(contentsOf: keys)
        playlist.artKeys.append(contentsOf: keys)
        playlist.dateModified = Date()
        try? context.save()
        reloadPlaylists()
    }

    func removeSong(_ song: Song, from playlist: Playlist) {
        let key = playlistKey(for: song)
        if let idx = playlist.itemKeys.firstIndex(of: key) {
            playlist.itemKeys.remove(at: idx)
        }
        if let idx = playlist.artKeys.firstIndex(of: key) {
            playlist.artKeys.remove(at: idx)
        }
        playlist.dateModified = Date()
        try? context.save()
        reloadPlaylists()
    }

    func removeItems(at offsets: IndexSet, from playlist: Playlist) {
        let removedKeys = offsets.map { playlist.itemKeys[$0] }
        playlist.itemKeys.remove(atOffsets: offsets)
        for key in removedKeys {
            if let idx = playlist.artKeys.firstIndex(of: key) {
                playlist.artKeys.remove(at: idx)
            }
        }
        playlist.dateModified = Date()
        try? context.save()
        reloadPlaylists()
    }

    func moveItems(
        in playlist: Playlist,
        from source: IndexSet,
        to destination: Int
    ) {
        seedArtKeysIfNeeded(playlist)
        playlist.itemKeys.move(fromOffsets: source, toOffset: destination)
        playlist.dateModified = Date()
        try? context.save()
        reloadPlaylists()
    }

    private var songLookup: [String: Song] {
        _ = deviceSongs
        _ = imported
        if let cached = _songLookup { return cached }
        var map: [String: Song] = [:]
        map.reserveCapacity(deviceSongs.count + imported.count)
        for song in deviceSongs + imported {
            let key = playlistKey(for: song)
            if map[key] == nil { map[key] = song }
        }
        _songLookup = map
        return map
    }

    private func resolve(_ keys: [String], limit: Int? = nil) -> [Song] {
        let lookup = songLookup
        var result: [Song] = []
        for key in keys {
            guard let song = lookup[key] else { continue }
            result.append(song)
            if let limit, result.count == limit { break }
        }
        return result
    }

    func songs(in playlist: Playlist) -> [Song] {
        resolve(playlist.itemKeys)
    }

    private func playlistKey(for song: Song) -> String {
        if !song.isLocal, let pid = song.persistentID {
            return "device:\(pid)"
        }
        return "imported:\(song.id.uuidString)"
    }

    func pruneMissing(in playlist: Playlist) {
        let valid = Set(songLookup.keys)
        var mutated = false
        if playlist.artKeys.isEmpty, !playlist.itemKeys.isEmpty {
            playlist.artKeys = playlist.itemKeys
            mutated = true
        }
        let items = playlist.itemKeys.filter { valid.contains($0) }
        if items.count != playlist.itemKeys.count {
            playlist.itemKeys = items
            mutated = true
        }
        let art = playlist.artKeys.filter { valid.contains($0) }
        if art.count != playlist.artKeys.count {
            playlist.artKeys = art
            mutated = true
        }
        guard mutated else { return }
        try? context.save()
        reloadPlaylists()
    }

    func suggestedPlaylistName() -> String {
        let base = "New Playlist"
        let existing = Set(playlists.map(\.name))
        if !existing.contains(base) { return base }
        var n = 2
        while existing.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    func setPinned(_ pinned: Bool, for playlist: Playlist) {
        playlist.isPinned = pinned
        try? context.save()
        reloadPlaylists()
    }

    func markPlayed(_ playlist: Playlist) {
        playlist.lastPlayedDate = Date()
        try? context.save()
        reloadPlaylists()
    }

    func updatePlaylist(
        _ playlist: Playlist,
        name: String,
        details: String,
        newArtworkData: Data?,
        clearArtwork: Bool = false
    ) {
        playlist.name = name
        playlist.details = details
        if clearArtwork {
            if let key = playlist.artworkCacheKey { artworkStore.remove(key) }
            playlist.artworkCacheKey = nil
        } else if let data = newArtworkData {
            if let key = playlist.artworkCacheKey { artworkStore.remove(key) }
            let key = UUID().uuidString
            artworkStore.store(data, key: key)
            playlist.artworkCacheKey = key
        }
        playlist.dateModified = Date()
        try? context.save()
        reloadPlaylists()
    }

    func playlistCoverImage(for playlist: Playlist) -> Image? {
        guard let key = playlist.artworkCacheKey else { return nil }
        return artworkStore.image(for: key)
    }

    #if canImport(MediaPlayer)
        func playlistCoverUIImage(for playlist: Playlist) -> UIImage? {
            if let key = playlist.artworkCacheKey,
                let img = artworkStore.uiImage(for: key)
            {
                return img
            }
            for song in artSongs(in: playlist) {
                if let img = artworkUIImage(for: song) { return img }
            }
            return nil
        }
    #endif

    #if canImport(MediaPlayer)
        func playlistArtUIImages(for playlist: Playlist) -> [UIImage] {
            if let key = playlist.artworkCacheKey,
                let img = artworkStore.uiImage(for: key)
            {
                return [img]
            }
            return artSongs(in: playlist).compactMap { artworkUIImage(for: $0) }
        }
    #endif

    #if canImport(MediaPlayer)
        func songArtUIImages(for playlist: Playlist) -> [UIImage] {
            artSongs(in: playlist).compactMap { artworkUIImage(for: $0) }
        }
    #endif

    func setPlaylistArtwork(_ data: Data, for playlist: Playlist) {
        if let key = playlist.artworkCacheKey { artworkStore.remove(key) }
        let key = UUID().uuidString
        artworkStore.store(data, key: key)
        playlist.artworkCacheKey = key
        playlist.dateModified = Date()
        try? context.save()
        reloadPlaylists()
    }

    func clearPlaylistArtwork(for playlist: Playlist) {
        if let key = playlist.artworkCacheKey { artworkStore.remove(key) }
        playlist.artworkCacheKey = nil
        playlist.dateModified = Date()
        try? context.save()
        reloadPlaylists()
    }

    func artSongs(in playlist: Playlist) -> [Song] {
        let keys =
            playlist.artKeys.isEmpty ? playlist.itemKeys : playlist.artKeys
        return resolve(keys, limit: 4)
    }
}
