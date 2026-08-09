//
//  RootView.swift
//  Carmina
//
//  Created by waru on 7/4/26.
//

import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    @AppStorage("appAccent") private var accent: AppAccent = .red

    var body: some View {
        Group {
            if sizeClass == .compact {
                TabRootView()
            } else {
                SidebarRootView()
            }
        }
        .tint(accent.color)
    }
}
