//
//  Song.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import Foundation

struct Song: Identifiable, Hashable, Codable {
    var id = UUID()
    let title: String
    let artist: String
    let album: String
    let dateAdded: Date
    let isLocal: Bool
    var persistentID: UInt64? = nil
    var assetURL: URL? = nil
    var lyrics: String? = nil

    var audioURL: URL? { assetURL }
}
