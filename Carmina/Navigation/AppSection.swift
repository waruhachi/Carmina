//
//  AppSection.swift
//  Carmina
//
//  Created by waru on 7/4/26.
//

import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case local, remote, downloads, library, search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: "Local"
        case .remote: "Remote"
        case .downloads: "Downloads"
        case .library: "Library"
        case .search: "Search"
        }
    }

    var systemImage: String {
        switch self {
        case .local: "folder"
        case .remote: "internaldrive"
        case .downloads: "arrow.down.circle"
        case .library: "music.note.square.stack"
        case .search: "magnifyingglass"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .local: LocalView()
        case .remote: RemoteView()
        case .downloads: DownloadsView()
        case .library: LibraryView()
        case .search: SearchView()
        }
    }
}
