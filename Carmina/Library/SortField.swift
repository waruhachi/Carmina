//
//  SortField.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import Foundation

enum SortField: CaseIterable {
    case title, dateAdded, artist

    var title: String {
        switch self {
        case .title: "Title"
        case .dateAdded: "Date Added"
        case .artist: "Artist"
        }
    }
    var defaultAscending: Bool { self == .dateAdded ? false : true }
    func subtitle(ascending: Bool) -> String {
        switch self {
        case .title, .artist: ascending ? "A to Z" : "Z to A"
        case .dateAdded: ascending ? "Oldest First" : "Newest First"
        }
    }
    var showsAlphabetIndex: Bool { self == .title || self == .artist }
}

struct SortState: Equatable {
    var field: SortField
    var ascending: Bool
    static let `default` = SortState(field: .dateAdded, ascending: false)

    func apply(to songs: [Song]) -> [Song] {
        switch field {
        case .title: songs.sorted { compare($0.title, $1.title) }
        case .artist: songs.sorted { compare($0.artist, $1.artist) }
        case .dateAdded:
            songs.sorted {
                ascending
                    ? $0.dateAdded < $1.dateAdded : $0.dateAdded > $1.dateAdded
            }
        }
    }
    private func compare(_ a: String, _ b: String) -> Bool {
        let r = a.localizedCaseInsensitiveCompare(b)
        return ascending ? r == .orderedAscending : r == .orderedDescending
    }
}
