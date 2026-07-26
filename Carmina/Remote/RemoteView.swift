//
//  RemoteView.swift
//  Carmina
//
//  Created by waru on 7/4/26.
//

import SwiftUI

struct RemoteView: View {
    @ObserveInjection var inject

    var body: some View {
        ContentUnavailableView(
            "Remote",
            systemImage: "internaldrive",
            description: Text("Add and configure music servers.")
        )
        .navigationTitle("Remote")
        .toolbarTitleDisplayMode(.inlineLarge)
    }
}
