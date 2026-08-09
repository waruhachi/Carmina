//
//  RecentlyAddedSection.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

struct RecentlyAddedSection: View {
    @Environment(Library.self) private var library
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: 16)]
            : [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
            ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added")
                .font(.title2.weight(.bold))
                .padding(.horizontal, 20)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(library.recentlyAdded) { song in
                    VStack(alignment: .leading, spacing: 8) {
                        TrackArtwork(song: song)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(song.title).font(.subheadline).lineLimit(1)
                            Text(song.artist).font(.subheadline)
                                .foregroundStyle(
                                    .secondary
                                ).lineLimit(1)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}
