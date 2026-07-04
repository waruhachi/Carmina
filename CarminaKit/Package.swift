// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "CarminaKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(
            name: "CarminaKit",
            targets: [
                "CarminaModels", "CarminaPlayback", "CarminaSources",
                "SubsonicKit", "JellyfinKit", "WebDAVKit",
                "CarminaTagging", "CarminaLyrics", "CarminaArtwork",
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/chicio/ID3TagEditor", from: "5.0.0")
    ],
    targets: [
        .target(name: "CarminaModels"),
        .target(name: "CarminaPlayback", dependencies: ["CarminaModels"]),
        .target(
            name: "CarminaSources",
            dependencies: [
                "CarminaModels", "SubsonicKit", "JellyfinKit", "WebDAVKit",
            ]
        ),
        .target(name: "SubsonicKit"),
        .target(name: "JellyfinKit"),
        .target(name: "WebDAVKit", dependencies: ["CarminaTagging"]),
        .target(name: "CarminaTagging", dependencies: ["ID3TagEditor"]),
        .target(name: "CarminaLyrics"),
        .target(name: "CarminaArtwork"),
        .testTarget(
            name: "CarminaLyricsTests",
            dependencies: ["CarminaLyrics"]
        ),
        .testTarget(name: "SubsonicKitTests", dependencies: ["SubsonicKit"]),
    ]
)
