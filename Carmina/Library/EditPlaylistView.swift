//
//  EditPlaylistView.swift
//  Carmina
//
//  Created by waru on 8/4/26.
//

import PhotosUI
import SwiftUI
internal import UniformTypeIdentifiers

#if canImport(UIKit)
    import UIKit
#endif

struct EditPlaylistView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss

    let playlist: Playlist

    private enum CoverChoice: Hashable { case photo, collage }

    @State private var name: String
    @State private var details: String
    @State private var selection = Set<Int>()
    @State private var selectedCover: CoverChoice?
    @State private var pendingPhotoData: Data?
    @State private var addingMusic = false
    @State private var showPhotos = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showFiles = false
    @State private var showDiscardConfirm = false

    init(playlist: Playlist) {
        self.playlist = playlist
        _name = State(initialValue: playlist.name)
        _details = State(initialValue: playlist.details)
        _selectedCover = State(
            initialValue: playlist.artworkCacheKey == nil ? .collage : .photo
        )
    }

    private var songs: [Song] { library.songs(in: playlist) }

    private var neutralBackground: Color {
        #if canImport(UIKit)
            Color(uiColor: .secondarySystemBackground)
        #else
            Color.gray.opacity(0.15)
        #endif
    }

    private var hasChanges: Bool {
        name != playlist.name
            || details != playlist.details
            || pendingPhotoData != nil
            || selectedCover
                != (playlist.artworkCacheKey == nil ? .collage : .photo)
    }

    var body: some View {
        NavigationStack {
            editList
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(neutralBackground.ignoresSafeArea())
                .environment(\.editMode, .constant(.active))
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .modifier(pickers)
        }
    }

    // MARK: - List

    private var editList: some View {
        List(selection: $selection) {
            coverSection
            songsSection
        }
    }

    private var coverSection: some View {
        Section {
            carousel
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            TextField("Playlist Name", text: $name)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            TextField("Description", text: $details, axis: .vertical)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
        }
        .selectionDisabled()
        .moveDisabled(true)
        .listRowBackground(Color.clear)
    }

    private var songsSection: some View {
        Section {
            ForEach(Array(songs.enumerated()), id: \.offset) { _, song in
                songRow(song)
            }
            .onMove { from, to in
                library.moveItems(in: playlist, from: from, to: to)
            }
        }
        .listRowBackground(Color.clear)
    }

    private func songRow(_ song: Song) -> some View {
        HStack(spacing: 12) {
            TrackArtwork(song: song, size: 52)
            VStack(alignment: .leading, spacing: 1) {
                Text(song.title).lineLimit(1)
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .listRowInsets(
            EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if hasChanges {
                Button {
                    showDiscardConfirm = true
                } label: {
                    Image(systemName: "xmark")
                }
                .foregroundStyle(.white)
                .confirmationDialog(
                    Text(playlist.name),
                    isPresented: $showDiscardConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Discard Changes", role: .destructive) {
                        dismiss()
                    }
                } message: {
                    Text("Are you sure you want to discard your changes?")
                }
            } else {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .foregroundStyle(.white)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                save()
                dismiss()
            } label: {
                Image(systemName: "checkmark")
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
            }
            .tint(Color.red)
            .buttonStyle(.glassProminent)
        }
        ToolbarItemGroup(placement: .bottomBar) {
            Button(role: .destructive) {
                library.removeItems(at: IndexSet(selection), from: playlist)
                selection.removeAll()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(selection.isEmpty)

            Spacer()

            Button {
                addingMusic = true
            } label: {
                Label("Add", systemImage: "plus")
            }
            .tint(.white)
        }
    }

    // MARK: - Input modifiers

    private var pickers: some ViewModifier {
        PickersModifier(
            showPhotos: $showPhotos,
            photoItem: $photoItem,
            showFiles: $showFiles,
            addingMusic: $addingMusic,
            onPhoto: { data in
                pendingPhotoData = data
                selectedCover = .photo
            },
            onPrune: { library.pruneMissing(in: playlist) },
            addMusicSheet: {
                AnyView(AddMusicView(playlist: playlist).environment(library))
            }
        )
    }

    // MARK: - Cover carousel

    private var carousel: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let side: CGFloat = 260
                let inset = max(16, (geo.size.width - side) / 2)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            photoPage(side: side).id(CoverChoice.photo)
                            collagePage(side: side).id(CoverChoice.collage)
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, inset, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $selectedCover)
                    .onAppear {
                        DispatchQueue.main.async {
                            proxy.scrollTo(
                                selectedCover ?? .collage,
                                anchor: .center
                            )
                        }
                    }
                }
            }
            .frame(height: 260)

            pageIndicator
        }
        .padding(.vertical, 8)
    }

    private var pageIndicator: some View {
        HStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.system(size: 11))
                .foregroundStyle(
                    selectedCover == .photo ? Color.primary : Color.secondary
                )
            Circle()
                .fill(
                    selectedCover == .collage || selectedCover == nil
                        ? Color.primary : Color.secondary.opacity(0.4)
                )
                .frame(width: 7, height: 7)
        }
    }

    private func photoPage(side: CGFloat) -> some View {
        ZStack {
            if let data = pendingPhotoData, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill)
            } else if let cover = library.playlistCoverImage(for: playlist) {
                cover.resizable().aspectRatio(contentMode: .fill)
            } else {
                Color.primary.opacity(0.08)
            }

            Menu {
                Button("Choose Photo", systemImage: "photo.on.rectangle") {
                    showPhotos = true
                }
                Button("Choose Files", systemImage: "folder") {
                    showFiles = true
                }
            } label: {
                Circle()
                    .fill(Color.red)
                    .frame(width: side * 0.34, height: side * 0.34)
                    .overlay {
                        Image(systemName: "photo.fill")
                            .font(.system(size: side * 0.13))
                            .foregroundStyle(.white)
                    }
            }
            .buttonStyle(.plain)
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func collagePage(side: CGFloat) -> some View {
        PlaylistArtwork(
            playlist: playlist,
            size: side,
            cornerRadius: 12,
            forceCollage: true
        )
    }

    private var photoTile: some View {
        Menu {
            Button("Choose from Library", systemImage: "photo") {
                showPhotos = true
            }
            Button("Choose Files", systemImage: "folder") {
                showFiles = true
            }
        } label: {
            photoTileLabel
        }
        .buttonStyle(.plain)
    }

    private var photoTileLabel: some View {
        ZStack {
            if let data = pendingPhotoData, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill)
            } else if let cover = library.playlistCoverImage(for: playlist) {
                cover.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.primary.opacity(0.08)
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 240, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "camera.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .padding(7)
                .background(.black.opacity(0.55), in: Circle())
                .padding(8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Save

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? playlist.name : trimmed
        switch selectedCover {
        case .photo:
            library.updatePlaylist(
                playlist,
                name: finalName,
                details: details,
                newArtworkData: pendingPhotoData
            )
        case .collage, .none:
            library.updatePlaylist(
                playlist,
                name: finalName,
                details: details,
                newArtworkData: nil,
                clearArtwork: true
            )
        }
    }
}

// MARK: - Pickers / sheets / dialogs modifier

private struct PickersModifier: ViewModifier {
    @Binding var showPhotos: Bool
    @Binding var photoItem: PhotosPickerItem?
    @Binding var showFiles: Bool
    @Binding var addingMusic: Bool
    let onPhoto: (Data) -> Void
    let onPrune: () -> Void
    let addMusicSheet: () -> AnyView

    func body(content: Content) -> some View {
        content
            .photosPicker(
                isPresented: $showPhotos,
                selection: $photoItem,
                matching: .images
            )
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(
                        type: Data.self
                    ) {
                        onPhoto(data)
                    }
                    photoItem = nil
                }
            }
            .fileImporter(
                isPresented: $showFiles,
                allowedContentTypes: [.image]
            ) { result in
                if case .success(let url) = result {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer {
                        if scoped { url.stopAccessingSecurityScopedResource() }
                    }
                    if let data = try? Data(contentsOf: url) {
                        onPhoto(data)
                    }
                }
            }
            .sheet(isPresented: $addingMusic) { addMusicSheet() }
            .task { onPrune() }
    }
}

struct AbstractArtwork: View {
    let colors: [Color]

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                .init(0, 0), .init(0.5, 0), .init(1, 0),
                .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                .init(0, 1), .init(0.5, 1), .init(1, 1),
            ],
            colors: meshColors
        )
    }

    private var meshColors: [Color] {
        let base = colors.isEmpty ? [Color.gray, Color.secondary] : colors
        func c(_ i: Int) -> Color { base[i % base.count] }
        return [
            c(0), c(1), c(2),
            c(3), c(0), c(1),
            c(2), c(3), c(0),
        ]
    }
}
