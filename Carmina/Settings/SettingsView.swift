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
    @Environment(PlayerCoordinator.self) private var player

    @AppStorage("fullscreenArtwork") private var fullscreenArtwork = false
    @AppStorage("mixWithOthers") private var mixWithOthers = false
    @AppStorage("resumeAfterInterruption") private var resumeAfterInterruption =
        false

    var body: some View {
        NavigationStack {
            Form {
                Section("Now Playing") {
                    Toggle("Full-Screen Artwork", isOn: $fullscreenArtwork)
                }
                Section {
                    Toggle("Mix with Other Audio", isOn: $mixWithOthers)
                    Toggle(
                        "Resume After Interruption",
                        isOn: $resumeAfterInterruption
                    )
                } header: {
                    Text("Playback")
                } footer: {
                    Text(
                        "Mix with Other Audio lets Carmina play alongside other apps instead of pausing them (and stops other apps from pausing Carmina). Resume After Interruption picks playback back up after a phone call or another app finishes."
                    )
                }
                .onChange(of: mixWithOthers) { player.mixSettingChanged() }
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
