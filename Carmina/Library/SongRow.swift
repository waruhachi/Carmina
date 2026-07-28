//
//  SongRow.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

struct SongRow: View {
    @ObserveInjection var inject

    @Environment(PlayerCoordinator.self) private var player
    @Environment(DeviceLibrary.self) private var library

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
            Menu {
                SongMenu(song: song, onDelete: onDelete)
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
            SongMenu(song: song, onDelete: onDelete)
                .environment(player)
        } preview: {
            menuPreview
                .environment(library)
                .environment(player)
        }
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
