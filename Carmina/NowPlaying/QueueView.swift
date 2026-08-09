//
//  QueueView.swift
//  Carmina
//
//  Created by waru on 7/28/26.
//

import SwiftUI

struct QueueView: View {
    @Environment(PlayerCoordinator.self) private var player
    @Environment(\.dismiss) private var dismiss

    private var upNext: [Song] {
        guard player.currentIndex + 1 < player.queue.count else { return [] }
        return Array(player.queue[(player.currentIndex + 1)...])
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(upNext.enumerated()), id: \.element.id) {
                    offset,
                    song in
                    HStack(spacing: 12) {
                        TrackArtwork(song: song, size: 44)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(song.title).lineLimit(1)
                            Text(song.artist).font(.caption)
                                .foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 8)
                    }
                    .contentShape(.rect)
                    .onTapGesture {
                        player.play(at: player.currentIndex + 1 + offset)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        player.play(at: player.currentIndex + 1 + offset)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Playing Next")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
            .overlay {
                if upNext.isEmpty {
                    ContentUnavailableView(
                        "Nothing Up Next",
                        systemImage: "list.bullet",
                        description: Text("Songs you queue will appear here.")
                    )
                }
            }
        }
    }
}
