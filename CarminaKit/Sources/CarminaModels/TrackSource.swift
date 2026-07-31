//
//  TrackSource.swift
//  CarminaKit
//
//  Created by waru on 7/30/26.
//

import Foundation

public enum TrackSource: String, Codable, Sendable {
    case device, imported, subsonic, jellyfin, webdav
}

public struct PlayableAsset: Sendable {
    public let url: URL
    public let headers: [String: String]?

    public init(url: URL, headers: [String: String]? = nil) {
        self.url = url
        self.headers = headers
    }
}

public protocol MusicSource {
    var sourceType: TrackSource { get }
    func playbackAsset(for song: Song) -> PlayableAsset?
}
