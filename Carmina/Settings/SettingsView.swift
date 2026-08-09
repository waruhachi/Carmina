//
//  SettingsView.swift
//  Carmina
//
//  Created by waru on 7/14/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerCoordinator.self) private var player

    @AppStorage("fillArtworkSpace") private var fillArtworkSpace = false
    @AppStorage("fullscreenArtwork") private var fullscreenArtwork = false
    @AppStorage("mixWithOthers") private var mixWithOthers = false
    @AppStorage("resumeAfterInterruption") private var resumeAfterInterruption =
        false
    @AppStorage("startupSection") private var startupSection = "library"
    @AppStorage("hiddenSections") private var hiddenSections = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Tabs") {
                    Picker("Start On", selection: $startupSection) {
                        ForEach(
                            AppSection.visible(hiddenRaw: hiddenSections)
                        ) { section in
                            Label(
                                section.title,
                                systemImage: section.systemImage
                            )
                            .tag(section.rawValue)
                        }
                    }
                }

                Section {
                    ForEach(AppSection.allCases) { section in
                        Toggle(isOn: visibilityBinding(section)) {
                            Label(
                                section.title,
                                systemImage: section.systemImage
                            )
                        }
                        .disabled(
                            !hidden.contains(section.rawValue)
                                && visibleCount == 1
                        )
                    }
                } footer: {
                    Text(
                        "Hide the tabs you don't use. "
                            + "At least one tab stays visible."
                    )
                }
                Section("Now Playing") {
                    Toggle("Full-Screen Artwork", isOn: $fullscreenArtwork)
                    Toggle(
                        "Fill Space for Non-Square Artwork",
                        isOn: $fillArtworkSpace
                    )
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

    private var hidden: Set<String> {
        Set(hiddenSections.split(separator: ",").map(String.init))
    }

    private var visibleCount: Int {
        AppSection.visible(hiddenRaw: hiddenSections).count
    }

    private func visibilityBinding(_ section: AppSection) -> Binding<Bool> {
        Binding(
            get: { !hidden.contains(section.rawValue) },
            set: { show in
                var set = hidden
                if show {
                    set.remove(section.rawValue)
                } else {
                    set.insert(section.rawValue)
                }
                hiddenSections = set.sorted().joined(separator: ",")
                if !show, startupSection == section.rawValue {
                    startupSection =
                        AppSection.visible(hiddenRaw: hiddenSections)
                        .first?.rawValue ?? "library"
                }
            }
        )
    }
}
