//
//  LocalView.swift
//  Carmina
//
//  Created by waru on 7/4/26.
//

import SwiftUI
internal import UniformTypeIdentifiers

struct LocalView: View {
    @Environment(Library.self) private var library
    @Environment(PlayerCoordinator.self) private var player

    @AppStorage("localSort") private var sort: SortOption = .dateNewest

    @State private var showImporter = false

    private var localSongs: [Song] {
        sort.apply(to: library.songs.filter(\.isLocal))
    }

    var body: some View {
        Group {
            if localSongs.isEmpty {
                ContentUnavailableView {
                    Label("Local", systemImage: "folder")
                } description: {
                    Text("Import and manage local files.")
                } actions: {
                    Button("Import Files") { showImporter = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(localSongs) { song in
                        SongRow(song: song) { library.remove(song) }
                            .listRowInsets(
                                EdgeInsets(
                                    top: 4,
                                    leading: 16,
                                    bottom: 4,
                                    trailing: 8
                                )
                            )
                            .contentShape(.rect)
                            .onTapGesture {
                                if let i = localSongs.firstIndex(
                                    where: { $0.id == song.id }
                                ) {
                                    player.play(localSongs, startAt: i)
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Local")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            if !localSongs.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import", systemImage: "plus") {
                        showImporter = true
                    }
                    .tint(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort By", selection: $sort) {
                            ForEach(SortOption.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .tint(.primary)
                    .accessibilityLabel("Sort")
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            ToolbarItem(placement: .topBarTrailing) { SettingsButton() }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                library.importFiles(urls)
            }
        }
    }
}
