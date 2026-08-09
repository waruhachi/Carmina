//
//  SettingsButton.swift
//  Carmina
//
//  Created by waru on 7/21/26.
//

import SwiftUI

struct SettingsButton: View {
    @State private var showingSettings = false

    var body: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.title3)
        }
        .tint(.primary)
        .accessibilityLabel("Settings")
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}
