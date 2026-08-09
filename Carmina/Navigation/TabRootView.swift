//
//  TabRootView.swift
//  Carmina
//
//  Created by waru on 7/13/26.
//

import SwiftUI

struct TabRootView: View {
    @Namespace private var animation

    @Environment(PlayerCoordinator.self) private var player

    @AppStorage("hiddenSections") private var hiddenSections = ""

    @State private var expandNowPlaying = false
    @State private var selection: AppSection

    private static let miniPlayerID = "nowPlaying"

    init() {
        let hidden =
            UserDefaults.standard.string(forKey: "hiddenSections") ?? ""
        let visible = AppSection.visible(hiddenRaw: hidden)
        let raw =
            UserDefaults.standard.string(forKey: "startupSection") ?? "library"
        let startup = AppSection(rawValue: raw) ?? .library
        _selection = State(
            initialValue: visible.contains(startup)
                ? startup : (visible.first ?? .library)
        )
    }

    private var visibleSections: [AppSection] {
        AppSection.visible(hiddenRaw: hiddenSections)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(visibleSections) { section in
                Tab(
                    section.title,
                    systemImage: section.systemImage,
                    value: section,
                    role: section == .search ? .search : nil
                ) {
                    NavigationStack {
                        if section == .library || section == .local {
                            section.destination
                        } else {
                            section.destination.settingsToolbar()
                        }
                    }
                }
            }
        }
        .onChange(of: hiddenSections) {
            if !visibleSections.contains(selection) {
                selection = visibleSections.first ?? .library
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
