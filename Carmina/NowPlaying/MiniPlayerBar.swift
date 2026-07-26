//
//  MiniPlayerBar.swift
//  Carmina
//
//  Created by waru on 7/4/26.
//

import SwiftUI

struct MiniPlayerBar: View {
    @ObserveInjection var inject

    @Environment(PlayerCoordinator.self) private var player
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    private var isMinimized: Bool { placement == .inline }

    var body: some View {
        HStack(spacing: 15) {
            PlayerInfo(size: 30, song: player.current)

            Spacer(minLength: 0)

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .contentShape(.rect)
            }

            if !isMinimized {
                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill").contentShape(.rect)
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 15)
    }
}
