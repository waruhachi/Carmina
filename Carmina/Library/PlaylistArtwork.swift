//
//  PlaylistArtwork.swift
//  Carmina
//
//  Created by waru on 8/4/26.
//

import SwiftUI

#if canImport(UIKit)
    import CoreImage
    import UIKit
#endif

struct PlaylistArtwork: View {
    @Environment(Library.self) private var library

    let playlist: Playlist
    var size: CGFloat
    var cornerRadius: CGFloat = 8
    var forceCollage: Bool = false

    var body: some View {
        Group {
            if !forceCollage,
                let cover = library.playlistCoverImage(for: playlist)
            {
                cover.resizable().aspectRatio(contentMode: .fill)
            } else {
                collage
            }
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    @ViewBuilder private var collage: some View {
        let images = collageImages()
        if images.isEmpty {
            placeholder
        } else if images.count == 1 {
            tile(images[0], size)
        } else {
            let cell = size / 2
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    tile(images[0], cell)
                    tile(images[1 % images.count], cell)
                }
                HStack(spacing: 0) {
                    tile(images[2 % images.count], cell)
                    tile(images[3 % images.count], cell)
                }
            }
        }
    }

    private func tile(_ image: Image, _ side: CGFloat) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: side, height: side)
            .clipped()
    }

    private var placeholder: some View {
        ZStack {
            Color.primary.opacity(0.1)
            Image(systemName: "music.note.list")
                .font(.system(size: size * 0.34))
                .foregroundStyle(.secondary)
        }
    }

    private func collageImages() -> [Image] {
        let cell = CGSize(width: size, height: size)
        var seen = Set<String>()
        var result: [Image] = []
        for song in library.artSongs(in: playlist) {
            let key =
                song.artworkCacheKey
                ?? song.persistentID.map(String.init)
                ?? song.id.uuidString
            guard !seen.contains(key) else { continue }
            if let image = library.artworkImage(for: song, size: cell) {
                seen.insert(key)
                result.append(image)
                if result.count == 4 { break }
            }
        }
        return result
    }
}

#if canImport(UIKit)
    enum DominantColor {
        static func average(of images: [UIImage]) -> Color? {
            let rgbs = images.compactMap { rgb(of: $0) }
            guard !rgbs.isEmpty else { return nil }
            let n = Double(rgbs.count)
            return Color(
                red: rgbs.reduce(0) { $0 + $1.0 } / n,
                green: rgbs.reduce(0) { $0 + $1.1 } / n,
                blue: rgbs.reduce(0) { $0 + $1.2 } / n
            )
        }

        static func from(_ image: UIImage) -> Color? {
            rgb(of: image).map { Color(red: $0.0, green: $0.1, blue: $0.2) }
        }

        private static func rgb(
            of image: UIImage
        ) -> (Double, Double, Double)? {
            guard let cg = image.cgImage else { return nil }
            let input = CIImage(cgImage: cg)
            guard
                let filter = CIFilter(
                    name: "CIAreaAverage",
                    parameters: [
                        kCIInputImageKey: input,
                        kCIInputExtentKey: CIVector(cgRect: input.extent),
                    ]
                ),
                let output = filter.outputImage
            else { return nil }
            var bitmap = [UInt8](repeating: 0, count: 4)
            let context = CIContext(options: [.workingColorSpace: NSNull()])
            context.render(
                output,
                toBitmap: &bitmap,
                rowBytes: 4,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                format: .RGBA8,
                colorSpace: nil
            )
            return (
                Double(bitmap[0]) / 255,
                Double(bitmap[1]) / 255,
                Double(bitmap[2]) / 255
            )
        }
    }
#endif
