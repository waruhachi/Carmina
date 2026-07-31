//
//  MetadataOverride.swift
//  CarminaKit
//
//  Created by waru on 7/30/26.
//

import Foundation
import SwiftData

@Model
public final class MetadataOverride {
    public var devicePersistentID: String = ""  // String form of the UInt64
    public var title: String?
    public var artist: String?
    public var album: String?
    public var artworkCacheKey: String?
    public var dateModified: Date = Date()

    public init(
        devicePersistentID: String,
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        artworkCacheKey: String? = nil,
        dateModified: Date = Date()
    ) {
        self.devicePersistentID = devicePersistentID
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkCacheKey = artworkCacheKey
        self.dateModified = dateModified
    }
}
