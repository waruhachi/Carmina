//
//  SearchView.swift
//  Carmina
//
//  Created by waru on 7/4/26.
//

import SwiftUI

struct SearchView: View {
    @ObserveInjection var inject

    var body: some View {
        ContentUnavailableView(
            "Search",
            systemImage: "magnifyingglass",
            description: Text("Search your library and sources.")
        )
        .navigationTitle("Search")
        .toolbarTitleDisplayMode(.inlineLarge)
    }
}
