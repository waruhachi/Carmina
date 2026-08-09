//
//  AddToPlaylistView.swift
//  Carmina
//
//  Created by waru on 8/4/26.
//

import SwiftUI

struct AddToPlaylistView: View {
    @ObserveInjection var inject

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss

    let songs: [Song]

    @State private var showingNew = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        newName = library.suggestedPlaylistName()
                        showingNew = true
                    } label: {
                        Label("New Playlist", systemImage: "plus")
                    }
                }

                if !library.playlists.isEmpty {
                    Section("Playlists") {
                        ForEach(library.playlists) { playlist in
                            Button {
                                library.addSongs(songs, to: playlist)
                                dismiss()
                            } label: {
                                PlaylistRow(playlist: playlist)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("New Playlist", isPresented: $showingNew) {
                TextField("Playlist Name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    let name = newName.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    guard !name.isEmpty else { return }
                    let playlist = library.createPlaylist(name: name)

                    library.addSongs(songs, to: playlist)
                    dismiss()
                }
            }
        }
    }
}
