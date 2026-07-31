//
//  SongsView.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

struct SongsView: View {
    @ObserveInjection var inject

    @Environment(PlayerCoordinator.self) private var player
    @Environment(Library.self) private var library

    @AppStorage("appAccent") private var accent: AppAccent = .red
    @AppStorage("songSort") private var sort: SortOption = .dateNewest

    @State private var searchText = ""

    private var displayed: [Song] {
        let base =
            searchText.isEmpty
            ? library.songs
            : library.songs.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || $0.artist.localizedCaseInsensitiveContains(searchText)
            }
        return sort.apply(to: base)
    }

    var body: some View {
        List {
            if !displayed.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        actionButton("Play", "play.fill") {
                            player.play(displayed)
                        }
                        actionButton("Shuffle", "shuffle") {
                            player.shuffle(displayed)
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(
                        EdgeInsets(
                            top: 8,
                            leading: 16,
                            bottom: 20,
                            trailing: 16
                        )
                    )
                }
            }

            Section {
                ForEach(Array(displayed.enumerated()), id: \.element.id) {
                    index,
                    song in
                    SongRow(
                        song: song,
                        onDelete: { library.remove(song) }
                    )
                    .listRowInsets(
                        EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 8)
                    )
                    .contentShape(.rect)
                    .onTapGesture {
                        #if canImport(UIKit)
                            UIApplication.shared.endEditing()
                        #endif
                        player.play(displayed, startAt: index)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        #if canImport(UIKit)
                            UIApplication.shared.endEditing()
                        #endif
                        player.play(displayed, startAt: index)
                    }
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
                        if song.isLocal {
                            Button(role: .destructive) {
                                library.remove(song)
                            } label: {
                                Label(
                                    "Delete from Library",
                                    systemImage: "trash"
                                )
                                .labelStyle(.iconOnly)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("Songs")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic)
        )
        .toolbar {
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
        }
        .overlay {
            switch library.state {
            case .idle, .loading:
                ProgressView().controlSize(.large)
            case .denied:
                ContentUnavailableView {
                    Label("No Music Access", systemImage: "music.note.house")
                } description: {
                    Text("Allow music access in Settings to see your library.")
                } actions: {
                    #if canImport(UIKit)
                        Button("Open Settings") {
                            if let url = URL(
                                string: UIApplication.openSettingsURLString
                            ) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    #endif
                }
            case .authorized where library.songs.isEmpty:
                ContentUnavailableView(
                    "No Songs",
                    systemImage: "music.note",
                    description: Text(
                        "Songs you've added to your library will appear here."
                    )
                )
            default:
                EmptyView()
            }
        }
    }

    private func actionButton(
        _ title: String,
        _ symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(accent.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.primary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#if canImport(UIKit)
    import UIKit

    extension UIApplication {
        func endEditing() {
            sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
#endif
