//
//  AddMusicView.swift
//  Carmina
//
//  Created by waru on 8/4/26.
//

import SwiftUI

struct AddMusicView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss

    let playlist: Playlist

    @State private var searchText = ""
    @State private var addedIDs: Set<UUID> = []

    private var displayed: [Song] {
        searchText.isEmpty
            ? library.songs
            : library.songs.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || $0.artist.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        NavigationStack {
            List(displayed) { song in
                HStack(spacing: 12) {
                    TrackArtwork(song: song, size: 52)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(song.title).lineLimit(1)
                        Text(song.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Button {
                        library.addSong(song, to: playlist)
                        addedIDs.insert(song.id)
                    } label: {
                        Image(
                            systemName: addedIDs.contains(song.id)
                                ? "checkmark.circle.fill" : "plus.circle"
                        )
                        .font(.title2)
                        .foregroundStyle(
                            addedIDs.contains(song.id) ? .green : .accentColor
                        )
                    }
                    .buttonStyle(.plain)
                }
                .listRowInsets(
                    EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
                )
            }
            .listStyle(.plain)
            .navigationTitle("Add Music")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
