//
//  MetadataEditorView.swift
//  Carmina
//
//  Created by waru on 7/31/26.
//

import CarminaMatch
import PhotosUI
import SwiftUI
internal import UniformTypeIdentifiers

#if canImport(UIKit)
    import UIKit
#endif

struct MetadataEditorView: View {
    @ObserveInjection var inject

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss

    let song: Song

    @State private var title: String
    @State private var artist: String
    @State private var album: String
    @State private var pendingArtwork: Data?
    @State private var showMatchSearch = false
    @State private var showImageImporter = false
    @State private var showURLPrompt = false
    @State private var urlText = ""
    @State private var saving = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?

    init(song: Song) {
        self.song = song
        _title = State(initialValue: song.title)
        _artist = State(initialValue: song.artist)
        _album = State(initialValue: song.album)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        artworkPreview
                        Menu {
                            Button("Photos", systemImage: "photo.on.rectangle")
                            {
                                showPhotoPicker = true
                            }
                            Button("Files", systemImage: "folder") {
                                showImageImporter = true
                            }
                            Button("From URL", systemImage: "link") {
                                showURLPrompt = true
                            }
                        } label: {
                            Label(
                                "Change Artwork",
                                systemImage: "photo.badge.plus"
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("Details") {
                    field("Title", $title)
                    field("Artist", $artist)
                    field("Album", $album)
                }

                Section {
                    Button {
                        showMatchSearch = true
                    } label: {
                        Label(
                            "Find Match on iTunes",
                            systemImage: "sparkle.magnifyingglass"
                        )
                    }
                }

                if library.canRevert(song) {
                    Section {
                        Button(role: .destructive) {
                            Task {
                                await library.revertToOriginal(song)
                                dismiss()
                            }
                        } label: {
                            Label(
                                "Revert to Original",
                                systemImage: "arrow.uturn.backward"
                            )
                        }
                    }
                }
            }
            .navigationTitle("Edit Metadata")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(saving)
                }
            }
            .sheet(isPresented: $showMatchSearch) {
                MatchSearchView(
                    initialTerm: [artist, title]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                ) { candidate in
                    title = candidate.title
                    artist = candidate.artist
                    album = candidate.album
                    if let url = candidate.artworkURL {
                        Task { await downloadArtwork(from: url) }
                    }
                }
            }
            .fileImporter(
                isPresented: $showImageImporter,
                allowedContentTypes: [.image]
            ) { result in
                if case .success(let url) = result {
                    loadLocalImage(url)
                }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $photoItem,
                matching: .images
            )
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(
                        type: Data.self
                    ) {
                        pendingArtwork = data
                    }
                }
            }
            .alert("Image URL", isPresented: $showURLPrompt) {
                TextField("https://…", text: $urlText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Use") {
                    let text = urlText.trimmingCharacters(in: .whitespaces)
                    urlText = ""
                    if let url = URL(string: text) {
                        Task { await downloadArtwork(from: url) }
                    }
                }
                Button("Cancel", role: .cancel) { urlText = "" }
            } message: {
                Text("Enter a direct link to an image.")
            }
        }
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        LabeledContent(label) {
            TextField(label, text: text)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
    }

    private var artworkPreview: some View {
        Group {
            if let data = pendingArtwork, let image = image(from: data) {
                image.resizable().scaledToFit()
            } else if let image = library.artworkImage(
                for: song,
                size: CGSize(width: 240, height: 240)
            ) {
                image.resizable().scaledToFit()
            } else {
                placeholderArt
            }
        }
        .frame(width: 160, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var placeholderArt: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.secondary.opacity(0.2))
            .overlay {
                Image(systemName: "music.note").foregroundStyle(.secondary)
            }
    }

    private func image(from data: Data) -> Image? {
        #if canImport(UIKit)
            UIImage(data: data).map { Image(uiImage: $0) }
        #else
            nil
        #endif
    }

    private func loadLocalImage(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if let data = try? Data(contentsOf: url) {
            pendingArtwork = data
        }
    }

    private func downloadArtwork(from url: URL) async {
        if let (data, _) = try? await URLSession.shared.data(from: url) {
            pendingArtwork = data
        }
    }

    private func save() {
        saving = true
        Task {
            await library.applyEdit(
                to: song,
                title: title,
                artist: artist,
                album: album,
                newArtworkData: pendingArtwork
            )
            dismiss()
        }
    }
}
