//
//  TabRootView.swift
//  Carmina
//
//  Created by waru on 7/13/26.
//

import SwiftUI

struct TabRootView: View {
    @ObserveInjection var inject

    @Environment(PlayerCoordinator.self) private var player

    @Namespace private var animation

    @State private var expandNowPlaying = false

    private static let miniPlayerID = "nowPlaying"

    var body: some View {
        TabView {
            ForEach(AppSection.allCases) { section in
                Tab(
                    section.title,
                    systemImage: section.systemImage,
                    role: section == .search ? .search : nil
                ) {
                    NavigationStack {
                        if section == .library {
                            section.destination
                        } else {
                            section.destination.settingsToolbar()
                        }
                    }
                }
            }
        }
        .tabBarMinimizeBehavior(player.current != nil ? .onScrollDown : .never)
        .tabViewBottomAccessory(isEnabled: player.current != nil) {
            MiniPlayerBar(onExpand: { expandNowPlaying = true })
                .contentShape(.rect)
                .matchedTransitionSource(id: Self.miniPlayerID, in: animation)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onEnded {
                            if $0.translation.height < -30 {
                                expandNowPlaying = true
                            }
                        }
                )
        }
        .fullScreenCover(isPresented: $expandNowPlaying) {
            NowPlayingScreen()
                .navigationTransition(
                    .zoom(sourceID: Self.miniPlayerID, in: animation)
                )
        }
    }
}
