//
//  Song.swift
//  CarminaKit
//
//  Created by waru on 7/30/26.
//

import Foundation

public struct Song: Identifiable, Hashable, Codable, Sendable {
    public var id = UUID()
    public let title: String
    public let artist: String
    public let album: String
    public let dateAdded: Date
    public let isLocal: Bool
    public var persistentID: UInt64?
    public var assetURL: URL?
    public var lyrics: String?
    public var artworkCacheKey: String?
    public var duration: Double?

    public var audioURL: URL? { assetURL }

    public init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String,
        dateAdded: Date,
        isLocal: Bool,
        persistentID: UInt64? = nil,
        assetURL: URL? = nil,
        lyrics: String? = nil,
        artworkCacheKey: String? = nil,
        duration: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.dateAdded = dateAdded
        self.isLocal = isLocal
        self.persistentID = persistentID
        self.assetURL = assetURL
        self.lyrics = lyrics
        self.artworkCacheKey = artworkCacheKey
        self.duration = duration
    }
}
