//
//  LocalView.swift
//  Carmina
//
//  Created by waru on 7/4/26.
//

import SwiftUI
internal import UniformTypeIdentifiers

struct LocalView: View {
    @ObserveInjection var inject

    @State private var showImporter = false

    var body: some View {
        ContentUnavailableView {
            Label("Local", systemImage: "folder")
        } description: {
            Text("Import and manage local files.")
        } actions: {
            Button("Import Files") { showImporter = true }
                .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Local")
        .toolbarTitleDisplayMode(.inlineLarge)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { _ in
            // TODO: import selected files into a local store
        }
    }
}
