//
//  SidebarRootView.swift
//  Carmina
//
//  Created by waru on 7/13/26.
//

import SwiftUI

struct SidebarRootView: View {
    @ObserveInjection var inject

    @Environment(PlayerCoordinator.self) private var player

    @Namespace private var animation

    @State private var selection: AppSection? = .library
    @State private var expandNowPlaying = false

    private static let miniPlayerID = "nowPlaying"

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Carmina")
        } detail: {
            NavigationStack {
                Group {
                    let section = selection ?? .library
                    if section == .library {
                        section.destination
                    } else {
                        section.destination.settingsToolbar()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if player.current != nil {
                    MiniPlayerBar()
                        .contentShape(.rect)
                        .matchedTransitionSource(
                            id: Self.miniPlayerID,
                            in: animation
                        )
                        .onTapGesture { expandNowPlaying = true }
                }
            }
        }
        .fullScreenCover(isPresented: $expandNowPlaying) {
            NowPlayingScreen()
                .navigationTransition(
                    .zoom(sourceID: Self.miniPlayerID, in: animation)
                )
        }
    }
}
