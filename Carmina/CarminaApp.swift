//
//  CarminaApp.swift
//  Carmina
//
//  Created by waru on 7/3/26.
//

@_exported import Inject
import SwiftData
import SwiftUI

@main
struct CarminaApp: App {
    @State private var library = DeviceLibrary()
    @State private var player = PlayerCoordinator()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(player)
                .task {
                    player.library = library
                    await library.load()
                    player.restoreState()
                }
                .enableInjection()
        }
        .modelContainer(sharedModelContainer)
    }
}
