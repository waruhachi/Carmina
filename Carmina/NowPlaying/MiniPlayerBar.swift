//
//  MiniPlayerBar.swift
//  Carmina
//
//  Created by waru on 7/4/26.
//

import SwiftUI

struct MiniPlayerBar: View {
    @Environment(PlayerCoordinator.self) private var player
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    @State private var transportHaptic = 0
    @State private var forwardTrigger: PlayerButtonTrigger = .one(
        bouncing: false
    )

    var onExpand: () -> Void = {}

    private var isMinimized: Bool { placement == .inline }

    var body: some View {
        HStack(spacing: 12) {
            PlayerInfo(size: 30, song: player.current)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
                .onTapGesture { onExpand() }

            HStack(spacing: 0) {
                Button {
                    transportHaptic += 1
                    player.togglePlayPause()
                } label: {
                    PlayerButtonLabel(
                        type: player.isPlaying ? .pause : .play,
                        size: 20
                    )
                    .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(MiniPlayerButtonStyle())
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

                if !isMinimized {
                    Button {
                        forwardTrigger.toggle(bouncing: true)
                        transportHaptic += 1
                        player.next()
                    } label: {
                        PlayerButtonLabel(
                            type: .forward,
                            size: 26,
                            animationTrigger: forwardTrigger
                        )
                    }
                    .buttonStyle(MiniPlayerButtonStyle())
                    .accessibilityLabel("Next track")
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 15)
        .sensoryFeedback(.impact(weight: .light), trigger: transportHaptic)
    }
}

struct MiniPlayerButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 44, height: 44)
            .contentShape(.rect)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.82 : 1)
            .animation(
                reduceMotion ? nil : .snappy(duration: 0.25),
                value: configuration.isPressed
            )
    }
}
