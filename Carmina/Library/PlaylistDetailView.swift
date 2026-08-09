//
//  PlaylistDetailView.swift
//  Carmina
//
//  Created by waru on 8/4/26.
//

import SwiftUI

struct PlaylistDetailView: View {
    @ObserveInjection var inject

    @Environment(PlayerCoordinator.self) private var player
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss

    let playlist: Playlist

    @State private var songSort: PlaylistSongSort = .playlistOrder
    @State private var addingToPlaylist = false
    @State private var addingMusic = false
    @State private var editing = false
    @State private var bgColor: Color = .clear
    @State private var searchText = ""

    private var sortedSongs: [Song] {
        let base = library.songs(in: playlist)
        let filtered =
            searchText.isEmpty
            ? base
            : base.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || $0.artist.localizedCaseInsensitiveContains(searchText)
            }
        return songSort.apply(to: filtered)
    }

    private var pillForeground: Color {
        #if canImport(UIKit)
            Color(uiColor: .systemBackground)
        #else
            Color.black
        #endif
    }

    private var coverIdentity: String {
        "\(playlist.artworkCacheKey ?? "none")|"
            + playlist.artKeys.joined(separator: ",") + "|"
            + playlist.itemKeys.joined(separator: ",")
    }

    var body: some View {
        List {
            Section {
                header
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                ForEach(Array(sortedSongs.enumerated()), id: \.offset) {
                    index,
                    song in
                    SongRow(song: song, onDelete: { library.remove(song) })
                        .listRowInsets(
                            EdgeInsets(
                                top: 4,
                                leading: 16,
                                bottom: 4,
                                trailing: 8
                            )
                        )
                        .listRowBackground(Color.clear)
                        .contentShape(.rect)
                        .onTapGesture {
                            player.play(sortedSongs, startAt: index)
                            library.markPlayed(playlist)
                        }
                        .modifier(FirstRowSeparator(isFirst: index == 0))
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                player.playNext(song)
                            } label: {
                                Label(
                                    "Play Next",
                                    systemImage:
                                        "text.line.first.and.arrowtriangle.forward"
                                )
                                .labelStyle(.iconOnly)
                            }
                            .tint(.indigo)
                            if player.hasQueue {
                                Button {
                                    player.playLast(song)
                                } label: {
                                    Label(
                                        "Play Last",
                                        systemImage:
                                            "text.line.last.and.arrowtriangle.forward"
                                    )
                                    .labelStyle(.iconOnly)
                                }
                                .tint(.orange)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                library.removeSong(song, from: playlist)
                            } label: {
                                Label(
                                    "Remove from Playlist",
                                    systemImage: "minus.circle.fill"
                                )
                                .labelStyle(.iconOnly)
                            }
                        }
                }

                addMusicRow
            } footer: {
                if !sortedSongs.isEmpty {
                    Text(footerText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(
                            EdgeInsets(
                                top: 12,
                                leading: 16,
                                bottom: 12,
                                trailing: 16
                            )
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(bgColor.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchableIf(
            !library.songs(in: playlist).isEmpty,
            text: $searchText
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { menu }
        }
        .sheet(isPresented: $addingToPlaylist) {
            AddToPlaylistView(songs: library.songs(in: playlist))
                .environment(library)
        }
        .sheet(isPresented: $addingMusic) {
            AddMusicView(playlist: playlist).environment(library)
        }
        .sheet(isPresented: $editing) {
            EditPlaylistView(playlist: playlist).environment(library)
        }
        .task(id: coverIdentity) {
            library.pruneMissing(in: playlist)
            refreshBackground()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                PlaylistArtwork(
                    playlist: playlist,
                    size: geo.size.width,
                    cornerRadius: 12
                )
                .shadow(radius: 14, y: 8)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 72)

            VStack(spacing: 4) {
                Text(playlist.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                if !playlist.details.isEmpty {
                    Text(playlist.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            HStack(spacing: 12) {
                circleButton("shuffle", "Shuffle") {
                    player.shuffle(sortedSongs)
                    library.markPlayed(playlist)
                }

                Button {
                    player.play(sortedSongs)
                    library.markPlayed(playlist)
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(pillForeground)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 40)
                        .background(Color.primary, in: Capsule())
                }
                .buttonStyle(.plain)

                circleButton("arrow.down", "Download") {}
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var addMusicRow: some View {
        Button {
            addingMusic = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 52, height: 52)
                    .background(
                        Color.primary.opacity(0.1),
                        in: RoundedRectangle(
                            cornerRadius: 6,
                            style: .continuous
                        )
                    )
                Text("Add Music")
                Spacer(minLength: 8)
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 8))
        .listRowBackground(Color.clear)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .listRowSeparator(
            sortedSongs.isEmpty ? .visible : .automatic,
            edges: .top
        )
        .listRowSeparator(
            sortedSongs.isEmpty ? .hidden : .visible,
            edges: .bottom
        )
    }

    private func circleButton(
        _ symbol: String,
        _ label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 52, height: 52)
                .background(Color.primary.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Menu

    private var menu: some View {
        Menu {
            Section {
                Button(
                    playlist.isPinned ? "Unpin Playlist" : "Pin Playlist",
                    systemImage: playlist.isPinned ? "pin.slash" : "pin"
                ) {
                    library.setPinned(!playlist.isPinned, for: playlist)
                }
                Button("Add to Playlist", systemImage: "text.badge.plus") {
                    addingToPlaylist = true
                }
            }
            Section {
                Button("Edit", systemImage: "pencil") { editing = true }
                Menu {
                    Picker("Sort By", selection: $songSort) {
                        ForEach(PlaylistSongSort.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort By", systemImage: "arrow.up.arrow.down")
                }
                Button("Move to Folder", systemImage: "folder") {}
                    .disabled(true)
            }
            Section {
                Button(
                    "Play Next",
                    systemImage: "text.line.first.and.arrowtriangle.forward"
                ) {
                    player.playNext(sortedSongs)
                }
            }
            Section {
                Button(role: .destructive) {
                    library.deletePlaylist(playlist)
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .tint(.primary)
        .accessibilityLabel("More")
    }

    private var footerText: String {
        let count = sortedSongs.count
        let songLabel = count == 1 ? "1 song" : "\(count) songs"
        let total = sortedSongs.reduce(0.0) { $0 + ($1.duration ?? 0) }
        guard total > 0 else { return songLabel }
        let minutes = Int((total / 60).rounded())
        let minLabel = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        return "\(songLabel), \(minLabel)"
    }

    private func refreshBackground() {
        #if canImport(UIKit)
            bgColor =
                DominantColor.average(
                    of: library.playlistArtUIImages(for: playlist)
                ) ?? .clear
        #endif
    }
}

extension View {
    @ViewBuilder
    func searchableIf(_ condition: Bool, text: Binding<String>) -> some View {
        if condition {
            searchable(text: text)
        } else {
            self
        }
    }
}

private struct FirstRowSeparator: ViewModifier {
    let isFirst: Bool
    func body(content: Content) -> some View {
        if isFirst {
            content
                .listRowSeparator(.visible, edges: .top)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        } else {
            content
        }
    }
}

enum PlaylistSongSort: String, CaseIterable, Identifiable {
    case playlistOrder, title, artist, album

    var id: String { rawValue }

    var label: String {
        switch self {
        case .playlistOrder: "Playlist Order"
        case .title: "Title"
        case .artist: "Artist"
        case .album: "Album"
        }
    }

    func apply(to songs: [Song]) -> [Song] {
        switch self {
        case .playlistOrder:
            return songs
        case .title:
            return songs.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        case .artist:
            return songs.sorted {
                $0.artist.localizedStandardCompare($1.artist)
                    == .orderedAscending
            }
        case .album:
            return songs.sorted {
                $0.album.localizedStandardCompare($1.album) == .orderedAscending
            }
        }
    }
}
