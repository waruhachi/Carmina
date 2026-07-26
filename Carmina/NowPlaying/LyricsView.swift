//
//  LyricsView.swift
//  Carmina
//
//  Created by waru on 7/21/26.
//

import SwiftUI

struct LyricsView: View {
    @ObserveInjection var inject

    @Environment(\.dismiss) private var dismiss

    let title: String
    let lyrics: String

    var body: some View {
        NavigationStack {
            Group {
                if lyrics.isEmpty {
                    ContentUnavailableView(
                        "No Lyrics",
                        systemImage: "quote.bubble"
                    )
                } else {
                    ScrollView {
                        Text(lyrics)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
            }
            .navigationTitle(title.isEmpty ? "Lyrics" : title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }
}
