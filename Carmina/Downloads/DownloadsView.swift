//
//  DownloadsView.swift
//  Carmina
//
//  Created by waru on 7/4/26.
//

import SwiftUI

struct DownloadsView: View {
    var body: some View {
        ContentUnavailableView(
            "Downloads",
            systemImage: "arrow.down.circle",
            description: Text("Downloaded songs will appear here.")
        )
        .navigationTitle("Downloads")
        .toolbarTitleDisplayMode(.inlineLarge)
    }
}
