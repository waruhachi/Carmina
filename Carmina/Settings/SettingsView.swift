//
//  SettingsView.swift
//  Carmina
//
//  Created by waru on 7/14/26.
//

import SwiftUI

struct SettingsView: View {
    @ObserveInjection var inject

    @Environment(\.dismiss) private var dismiss

    @AppStorage("fullscreenArtwork") private var fullscreenArtwork = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Now Playing") {
                    Toggle("Full-Screen Artwork", isOn: $fullscreenArtwork)
                }
            }
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }
}
