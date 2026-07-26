//
//  LibrarySectionPage.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

struct LibrarySectionPage: View {
    @ObserveInjection var inject

    let section: LibrarySection

    var body: some View {
        switch section {
        case .songs:
            SongsView()
        default:
            ContentUnavailableView(
                section.title,
                systemImage: section.systemImage,
                description: Text("\(section.title) will appear here.")
            )
            .navigationTitle(section.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
