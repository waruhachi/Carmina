//
//  LocalView.swift
//  Carmina
//
//  Created by waru on 7/4/26.
//

import SwiftUI

struct LocalView: View {
    @ObserveInjection var inject

    var body: some View {
        ContentUnavailableView(
            "Local",
            systemImage: "folder",
            description: Text("Import and manage local files.")
        )
        .navigationTitle("Local")
        .toolbarTitleDisplayMode(.inlineLarge)
    }
}
