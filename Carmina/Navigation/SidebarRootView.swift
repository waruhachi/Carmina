//
//  SidebarRootView.swift
//  Carmina
//
//  Created by waru on 7/13/26.
//

import SwiftUI

struct SidebarRootView: View {
    @ObserveInjection var inject

    @State private var selection: AppSection? = .library

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
                MiniPlayerBar()
            }
        }
    }
}
