//
//  MatchCandidate.swift
//  CarminaKit
//
//  Created by waru on 7/30/26.
//

import Foundation

public struct MatchCandidate: Sendable, Identifiable {
    public let id: Int  // iTunes trackId
    public let title: String
    public let artist: String
    public let album: String
    public let durationSeconds: Double?
    public let artworkURL: URL?  // upscaled
    public var confidence: Double

    public init(
        id: Int,
        title: String,
        artist: String,
        album: String,
        durationSeconds: Double?,
        artworkURL: URL?,
        confidence: Double = 0
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.durationSeconds = durationSeconds
        self.artworkURL = artworkURL
        self.confidence = confidence
    }
}

public struct MetadataQuery: Sendable {
    public let title: String
    public let artist: String
    public let durationSeconds: Double?

    public init(title: String, artist: String, durationSeconds: Double?) {
        self.title = title
        self.artist = artist
        self.durationSeconds = durationSeconds
    }
}
