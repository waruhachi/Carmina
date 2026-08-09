//
//  SidebarRootView.swift
//  Carmina
//
//  Created by waru on 7/13/26.
//

import SwiftUI

struct SidebarRootView: View {
    @Namespace private var animation

    @Environment(PlayerCoordinator.self) private var player

    @AppStorage("hiddenSections") private var hiddenSections = ""

    @State private var selection: AppSection?
    @State private var expandNowPlaying = false

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
        NavigationSplitView {
            List(visibleSections, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Carmina")
        } detail: {
            NavigationStack {
                Group {
                    let section = selection ?? .library
                    if section == .library || section == .local {
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
        .onChange(of: hiddenSections) {
            if let sel = selection, !visibleSections.contains(sel) {
                selection = visibleSections.first
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
