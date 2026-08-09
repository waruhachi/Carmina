//
//  Playlist.swift
//  CarminaKit
//
//  Created by waru on 8/4/26.
//

import Foundation
import SwiftData

@Model
public final class Playlist {
    public var id: UUID = UUID()
    public var name: String = ""
    public var details: String = ""
    public var dateCreated: Date = Date()
    public var dateModified: Date = Date()
    public var lastPlayedDate: Date?
    public var isPinned: Bool = false
    public var artworkCacheKey: String?
    public var itemKeys: [String] = []
    public var artKeys: [String] = []

    public init(
        id: UUID = UUID(),
        name: String,
        details: String = "",
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        lastPlayedDate: Date? = nil,
        isPinned: Bool = false,
        artworkCacheKey: String? = nil,
        itemKeys: [String] = [],
        artKeys: [String] = []
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.lastPlayedDate = lastPlayedDate
        self.isPinned = isPinned
        self.artworkCacheKey = artworkCacheKey
        self.itemKeys = itemKeys
        self.artKeys = artKeys
    }
}
