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

    var body: some View {
        NavigationStack {
            Color.clear
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
