//
//  TrackArtwork.swift
//  Carmina
//
//  Created by waru on 7/20/26.
//

import SwiftUI

struct TrackArtwork: View {
    @ObserveInjection var inject

    @Environment(DeviceLibrary.self) private var library

    @State private var image: Image?

    let song: Song
    var size: CGFloat? = nil
    var radius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fillStyle)
            .aspectRatio(1, contentMode: .fit)
            .frame(width: size, height: size)
            .overlay {
                if let image {
                    image
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .task(id: song.id) {
                let px = (size ?? 300) * 2
                image = library.artworkImage(
                    for: song.persistentID,
                    size: CGSize(width: px, height: px)
                )
            }
    }

    private var fillStyle: Color {
        #if canImport(UIKit)
            Color(uiColor: .secondarySystemBackground)
        #else
            Color.gray.opacity(0.2)
        #endif
    }
}
