//
//  SongRow.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

struct SongRow: View {
    @Environment(PlayerCoordinator.self) private var player
    @Environment(Library.self) private var library

    @State private var editing = false
    @State private var addingToPlaylist = false
    #if canImport(UIKit)
        @State private var shareItem: ShareURL?
    #endif

    let song: Song
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TrackArtwork(song: song, size: 52)
            VStack(alignment: .leading, spacing: 1) {
                Text(song.title).lineLimit(1)
                Text(song.artist).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if library.needsReviewIDs.contains(song.id) {
                Image(systemName: "questionmark.circle")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Needs review")
            }
            Menu {
                SongMenu(
                    song: song,
                    onDelete: onDelete,
                    onEditMetadata: { editing = true },
                    onShare: {
                        #if canImport(UIKit)
                            Task {
                                if let url = await library.exportForSharing(
                                    song
                                ) {
                                    shareItem = ShareURL(url: url)
                                }
                            }
                        #endif
                    },
                    onAddToPlaylist: { addingToPlaylist = true }
                )
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("More")
        }
        .tint(.primary)
        .contentShape(.rect)
        .contextMenu {
            SongMenu(
                song: song,
                onDelete: onDelete,
                onEditMetadata: { editing = true },
                onAddToPlaylist: { addingToPlaylist = true }
            )
            .environment(player)
        } preview: {
            menuPreview
                .environment(library)
                .environment(player)
        }
        .sheet(isPresented: $addingToPlaylist) {
            AddToPlaylistView(songs: [song]).environment(library)
        }
        .sheet(isPresented: $editing) {
            MetadataEditorView(song: song).environment(library)
                .environment(player)
        }
        #if canImport(UIKit)
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
        #endif
    }

    private var menuPreview: some View {
        HStack(spacing: 12) {
            TrackArtwork(song: song, size: 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title).font(.headline).lineLimit(1)
                Text(song.artist).font(.subheadline).foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(song.album).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxWidth: 340)
    }
}
