//
//  SongMenu.swift
//  Carmina
//
//  Created by waru on 7/20/26.
//

import SwiftUI

struct SongMenu: View {
    @ObserveInjection var inject

    @Environment(PlayerCoordinator.self) private var player

    let song: Song
    var onDelete: (() -> Void)? = nil
    var onEditMetadata: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onAddToPlaylist: (() -> Void)? = nil

    var body: some View {
        #if canImport(UIKit)
            Section {
                if song.isLocal, let onShare {
                    Section {
                        Button("Share", systemImage: "square.and.arrow.up") {
                            onShare()
                        }
                    }
                }
            }
        #endif
        Section {
            Button("Add to Playlist", systemImage: "text.badge.plus") {
                onAddToPlaylist?()
            }
        }
        Section {
            Button(
                "Play Next",
                systemImage: "text.line.first.and.arrowtriangle.forward"
            ) { player.playNext(song) }
            if player.hasQueue {
                Button(
                    "Play Last",
                    systemImage: "text.line.last.and.arrowtriangle.forward"
                ) { player.playLast(song) }
            }
        }
        Section {
            if let onEditMetadata {
                Section {
                    Button("Edit Metadata", systemImage: "pencil") {
                        onEditMetadata()
                    }
                }
            }
            Button("View Credits", systemImage: "info.circle") {}
        }
        if let onDelete, song.isLocal {
            Section {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete from Library", systemImage: "trash")
                }
                .tint(.red)
            }
        }
    }
}
