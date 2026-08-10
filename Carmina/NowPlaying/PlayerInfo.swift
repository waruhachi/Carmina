//
//  PlayerInfo.swift
//  Carmina
//
//  Created by waru on 7/16/26.
//

import SwiftUI

struct PlayerInfo: View {
    var size: CGFloat = 30
    var previousSong: Song?
    var song: Song?
    var nextSong: Song?
    var textOffset: CGFloat = 0
    @Binding var textPageWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if let song {
                    TrackArtwork(song: song, size: size, radius: size / 5)
                } else {
                    RoundedRectangle(cornerRadius: size / 5, style: .continuous)
                        .fill(.quaternary)
                        .frame(width: size, height: size)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }
            }

            SongTextPager(
                previousSong: previousSong,
                currentSong: song,
                nextSong: nextSong,
                offset: textOffset,
                height: 34,
                pageWidth: $textPageWidth
            ) { song in
                MiniPlayerSongText(song: song)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct MiniPlayerSongText: View {
    let song: Song?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            MarqueeText(song?.title ?? "Not Playing")
                .font(.subheadline.weight(.semibold))
                .id(song?.title ?? "Not Playing")
            if let artist = song?.artist, !artist.isEmpty {
                MarqueeText(artist)
                    .font(.footnote)
                    .id(artist)
            }
        }
    }
}
