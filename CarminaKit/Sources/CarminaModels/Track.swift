//
//  Track.swift
//  CarminaKit
//
//  Created by waru on 7/30/26.
//

import Foundation
import SwiftData

public enum MatchState: String, Codable, Sendable {
    case unmatched, matched, manual
}

@Model
public final class Track {
    public var id: UUID = UUID()
    public var sourceRaw: String = TrackSource.imported.rawValue
    public var title: String = ""
    public var artist: String = ""
    public var album: String = ""
    public var dateAdded: Date = Date()

    // Source addressing
    public var localRelativePath: String?
    public var fileFormat: String?
    public var importedFileName: String?

    // Enrichment
    public var artworkCacheKey: String?
    public var lyrics: String?

    // Matching
    public var matchStateRaw: String = MatchState.unmatched.rawValue
    public var matchedStoreID: String?
    public var matchConfidence: Double?
    public var matchAttempted: Bool = false

    public init(
        id: UUID = UUID(),
        source: TrackSource = .imported,
        title: String = "",
        artist: String = "",
        album: String = "",
        dateAdded: Date = Date(),
        localRelativePath: String? = nil,
        fileFormat: String? = nil,
        importedFileName: String? = nil,
        artworkCacheKey: String? = nil,
        lyrics: String? = nil,
        matchState: MatchState = .unmatched,
        matchedStoreID: String? = nil,
        matchConfidence: Double? = nil,
        matchAttempted: Bool = false
    ) {
        self.id = id
        self.sourceRaw = source.rawValue
        self.title = title
        self.artist = artist
        self.album = album
        self.dateAdded = dateAdded
        self.localRelativePath = localRelativePath
        self.fileFormat = fileFormat
        self.importedFileName = importedFileName
        self.artworkCacheKey = artworkCacheKey
        self.lyrics = lyrics
        self.matchStateRaw = matchState.rawValue
        self.matchedStoreID = matchedStoreID
        self.matchConfidence = matchConfidence
        self.matchAttempted = matchAttempted
    }

    public var source: TrackSource {
        get { TrackSource(rawValue: sourceRaw) ?? .imported }
        set { sourceRaw = newValue.rawValue }
    }

    public var matchState: MatchState {
        get { MatchState(rawValue: matchStateRaw) ?? .unmatched }
        set { matchStateRaw = newValue.rawValue }
    }
}
