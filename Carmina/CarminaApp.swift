//
//  CarminaApp.swift
//  Carmina
//
//  Created by waru on 7/3/26.
//

@_exported import CarminaModels
@_exported import CarminaPlayback
@_exported import CarminaSources
@_exported import Inject
import SwiftData
import SwiftUI

@main
struct CarminaApp: App {
    let sharedModelContainer: ModelContainer

    @State private var library: Library
    @State private var player: PlayerCoordinator

    init() {
        let schema = Schema([Track.self, MetadataOverride.self, Playlist.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        self.sharedModelContainer = container

        let device = DeviceLibrary()
        let coordinator = PlayerCoordinator()
        coordinator.library = device
        let lib = Library(device: device, context: container.mainContext)
        lib.player = coordinator

        _library = State(initialValue: lib)
        _player = State(initialValue: coordinator)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(player)
                .task {
                    #if canImport(MediaPlayer)
                        player.artworkProvider = {
                            [weak library = library] song in
                            library?.artworkUIImage(for: song)
                        }
                    #endif
                    await library.load()
                    player.restoreState()
                }
                .enableInjection()
        }
        .modelContainer(sharedModelContainer)
    }
}
