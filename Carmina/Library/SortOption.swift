//
//  SortOption.swift
//  Carmina
//
//  Created by waru on 7/19/26.
//

import Foundation

enum SortOption: String, CaseIterable, Identifiable {
    case titleAsc = "Title (A–Z)"
    case titleDesc = "Title (Z–A)"
    case dateNewest = "Date Added (Newest)"
    case dateOldest = "Date Added (Oldest)"
    case artistAsc = "Artist (A–Z)"
    case artistDesc = "Artist (Z–A)"

    var id: String { rawValue }

    func apply(to songs: [Song]) -> [Song] {
        switch self {
        case .titleAsc:
            songs.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title)
                    == .orderedAscending
            }
        case .titleDesc:
            songs.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title)
                    == .orderedDescending
            }
        case .dateNewest: songs.sorted { $0.dateAdded > $1.dateAdded }
        case .dateOldest: songs.sorted { $0.dateAdded < $1.dateAdded }
        case .artistAsc:
            songs.sorted {
                $0.artist.localizedCaseInsensitiveCompare($1.artist)
                    == .orderedAscending
            }
        case .artistDesc:
            songs.sorted {
                $0.artist.localizedCaseInsensitiveCompare($1.artist)
                    == .orderedDescending
            }
        }
    }
}
