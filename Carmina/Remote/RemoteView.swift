//
//  RemoteView.swift
//  Carmina
//
//  Created by waru on 7/4/26.
//

import SwiftUI

struct RemoteView: View {
    @State private var showAddServer = false

    var body: some View {
        ContentUnavailableView {
            Label("Remote", systemImage: "internaldrive")
        } description: {
            Text("Add and configure music servers.")
        } actions: {
            Button("Add Server") { showAddServer = true }
                .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Remote")
        .toolbarTitleDisplayMode(.inlineLarge)
        .sheet(isPresented: $showAddServer) { AddServerView() }
    }
}

private struct AddServerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Add Server")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        // TODO: persist + connect
                        dismiss()
                    }
                    .disabled(address.isEmpty)
                }
            }
        }
    }
}
