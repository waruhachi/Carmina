//
//  SearchView.swift
//  Carmina
//
//  Created by waru on 7/4/26.
//

import SwiftUI

struct SearchView: View {
    @Environment(Library.self) private var library
    @Environment(PlayerCoordinator.self) private var player

    @State private var searchText = ""

    private var results: [Song] {
        guard !searchText.isEmpty else { return [] }
        return library.songs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.artist.localizedCaseInsensitiveContains(searchText)
                || $0.album.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            ForEach(Array(results.enumerated()), id: \.element.id) {
                index,
                song in
                SongRow(song: song, onDelete: { library.remove(song) })
                    .listRowInsets(
                        EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 8)
                    )
                    .contentShape(.rect)
                    .onTapGesture {
                        #if canImport(UIKit)
                            UIApplication.shared.endEditing()
                        #endif
                        player.play(results, startAt: index)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        #if canImport(UIKit)
                            UIApplication.shared.endEditing()
                        #endif
                        player.play(results, startAt: index)
                    }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Search")
        .toolbarTitleDisplayMode(.inlineLarge)
        .searchable(text: $searchText)
        .scrollDismissesKeyboard(.immediately)
        .overlay {
            if searchText.isEmpty {
                ContentUnavailableView(
                    "Search Your Library",
                    systemImage: "magnifyingglass",
                    description: Text("Find songs by title, artist, or album.")
                )
            } else if results.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
}
