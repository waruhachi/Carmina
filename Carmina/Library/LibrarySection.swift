//
//  LibrarySection.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

enum LibrarySection: String, CaseIterable, Identifiable {
    case playlists, artists, albums, songs, genres, composers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playlists: "Playlists"
        case .artists: "Artists"
        case .albums: "Albums"
        case .songs: "Songs"
        case .genres: "Genres"
        case .composers: "Composers"
        }
    }

    var systemImage: String {
        switch self {
        case .playlists: "music.note.list"
        case .artists: "music.mic"
        case .albums: "square.stack"
        case .songs: "music.note"
        case .genres: "guitars"
        case .composers: "music.quarternote.3"
        }
    }
}
