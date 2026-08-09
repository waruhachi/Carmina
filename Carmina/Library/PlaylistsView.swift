//
//  PlaylistsView.swift
//  Carmina
//
//  Created by waru on 8/4/26.
//

import SwiftUI

struct PlaylistsView: View {
    @Environment(Library.self) private var library
    @Environment(PlayerCoordinator.self) private var player

    @AppStorage("playlistViewMode") private var viewMode: PlaylistViewMode =
        .list
    @AppStorage("playlistSort") private var sort: PlaylistSort = .dateAdded

    @State private var searchText = ""
    @State private var showingNew = false
    @State private var newName = ""
    @State private var addTarget: Playlist?
    @State private var editTarget: Playlist?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    private var displayed: [Playlist] {
        let base =
            searchText.isEmpty
            ? library.playlists
            : library.playlists.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        return base.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return sort.isBefore(a, b)
        }
    }

    var body: some View {
        Group {
            if viewMode == .list {
                listBody
            } else {
                gridBody
            }
        }
        .navigationTitle("Playlists")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic)
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newName = library.suggestedPlaylistName()
                    showingNew = true
                } label: {
                    Image(systemName: "plus")
                }
                .tint(.primary)
                .accessibilityLabel("New Playlist")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("View", selection: $viewMode) {
                        Label("List", systemImage: "list.bullet")
                            .tag(PlaylistViewMode.list)
                        Label("Grid", systemImage: "square.grid.2x2")
                            .tag(PlaylistViewMode.grid)
                    }
                    .pickerStyle(.inline)

                    Picker("Sort By", selection: $sort) {
                        ForEach(PlaylistSort.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .tint(.primary)
                .accessibilityLabel("Sort and View")
            }
        }
        .alert("New Playlist", isPresented: $showingNew) {
            TextField("Playlist Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let name = newName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                if !name.isEmpty { library.createPlaylist(name: name) }
            }
        } message: {
            Text("Enter a name for your playlist.")
        }
        .sheet(item: $addTarget) { playlist in
            AddToPlaylistView(songs: library.songs(in: playlist))
                .environment(library)
        }
        .sheet(item: $editTarget) { playlist in
            EditPlaylistView(playlist: playlist).environment(library)
        }
        .overlay {
            if library.playlists.isEmpty {
                ContentUnavailableView(
                    "No Playlists",
                    systemImage: "music.note.list",
                    description: Text(
                        "Create a playlist to organize your music."
                    )
                )
            }
        }
    }

    private var listBody: some View {
        List {
            ForEach(Array(displayed.enumerated()), id: \.element.id) {
                index,
                playlist in
                NavigationLink {
                    PlaylistDetailView(playlist: playlist)
                } label: {
                    PlaylistRow(playlist: playlist)
                }
                .listRowInsets(
                    EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
                )
                .listRowSeparator(
                    index == 0 ? .hidden : .automatic,
                    edges: .top
                )
                .listRowSeparator(
                    index == displayed.count - 1 ? .hidden : .automatic,
                    edges: .bottom
                )
                .contextMenu {
                    menu(for: playlist)
                } preview: {
                    preview(for: playlist)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation { library.deletePlaylist(playlist) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var gridBody: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(displayed) { playlist in
                    NavigationLink {
                        PlaylistDetailView(playlist: playlist)
                    } label: {
                        PlaylistGridCell(playlist: playlist)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        menu(for: playlist)
                    } preview: {
                        preview(for: playlist)
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func menu(for playlist: Playlist) -> some View {
        let songs = library.songs(in: playlist)
        Section {
            Button("Play", systemImage: "play.fill") {
                player.play(songs)
                library.markPlayed(playlist)
            }
            Button("Shuffle", systemImage: "shuffle") {
                player.shuffle(songs)
                library.markPlayed(playlist)
            }
        }
        Section {
            Button(
                playlist.isPinned ? "Unpin Playlist" : "Pin Playlist",
                systemImage: playlist.isPinned ? "pin.slash" : "pin"
            ) {
                library.setPinned(!playlist.isPinned, for: playlist)
            }
            Button("Add to Playlist", systemImage: "text.badge.plus") {
                addTarget = playlist
            }
            Button("Edit", systemImage: "pencil") { editTarget = playlist }
            Button("Move to Folder", systemImage: "folder") {}
                .disabled(true)
        }
        Section {
            Button(
                "Play Next",
                systemImage: "text.line.first.and.arrowtriangle.forward"
            ) {
                player.playNext(songs)
            }
        }
        Section {
            Button("Delete", systemImage: "trash", role: .destructive) {
                withAnimation { library.deletePlaylist(playlist) }
            }
        }
    }

    private func preview(for playlist: Playlist) -> some View {
        HStack(spacing: 12) {
            PlaylistArtwork(playlist: playlist, size: 60)
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name).font(.headline).lineLimit(1)
                if !playlist.details.isEmpty {
                    Text(playlist.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: 340)
        .environment(library)
    }
}

struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            PlaylistArtwork(playlist: playlist, size: 60, cornerRadius: 6)
            Text(playlist.name).lineLimit(1)
            Spacer(minLength: 8)
        }
    }
}

struct PlaylistGridCell: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                PlaylistArtwork(
                    playlist: playlist,
                    size: geo.size.width,
                    cornerRadius: 10
                )
            }
            .aspectRatio(1, contentMode: .fit)
            Text(playlist.name)
                .font(.subheadline)
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
    }
}

enum PlaylistViewMode: String {
    case list, grid
}

enum PlaylistSort: String, CaseIterable, Identifiable {
    case title, dateAdded, lastPlayed, updated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .title: "Title"
        case .dateAdded: "Date Added"
        case .lastPlayed: "Last Played"
        case .updated: "Updated"
        }
    }

    func isBefore(_ a: Playlist, _ b: Playlist) -> Bool {
        switch self {
        case .title:
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        case .dateAdded:
            return a.dateCreated > b.dateCreated
        case .updated:
            return a.dateModified > b.dateModified
        case .lastPlayed:
            switch (a.lastPlayedDate, b.lastPlayedDate) {
            case (let x?, let y?): return x > y
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.dateCreated > b.dateCreated
            }
        }
    }
}
