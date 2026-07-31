//
//  ArtworkStore.swift
//  Carmina
//
//  Created by waru on 7/30/26.
//

import ImageIO
import SwiftUI
internal import UniformTypeIdentifiers

#if canImport(UIKit)
    import UIKit
#endif

struct ArtworkStore {
    var maxPixel: CGFloat = 1000

    private var dir: URL? {
        let fm = FileManager.default
        guard
            let base = try? fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        else { return nil }
        let d = base.appendingPathComponent("Artwork", isDirectory: true)
        try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private func fileURL(for key: String) -> URL? {
        dir?.appendingPathComponent("\(key).jpg")
    }

    func hasImage(for key: String) -> Bool {
        guard let u = fileURL(for: key) else { return false }
        return FileManager.default.fileExists(atPath: u.path)
    }

    func store(_ data: Data, key: String) {
        guard let u = fileURL(for: key) else { return }
        let output = downsample(data) ?? data
        try? output.write(to: u, options: .atomic)
    }

    #if canImport(UIKit)
        func uiImage(for key: String) -> UIImage? {
            guard let u = fileURL(for: key),
                let data = try? Data(contentsOf: u)
            else { return nil }
            return UIImage(data: data)
        }

        func image(for key: String) -> Image? {
            uiImage(for: key).map { Image(uiImage: $0) }
        }
    #else
        func image(for key: String) -> Image? { nil }
    #endif

    func data(for key: String) -> Data? {
        guard let u = fileURL(for: key) else { return nil }
        return try? Data(contentsOf: u)
    }

    func remove(_ key: String) {
        guard let u = fileURL(for: key) else { return }
        try? FileManager.default.removeItem(at: u)
    }

    private func downsample(_ data: Data) -> Data? {
        guard
            let source = CGImageSourceCreateWithData(
                data as CFData,
                [kCGImageSourceShouldCache: false] as CFDictionary
            )
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard
            let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                options as CFDictionary
            )
        else { return nil }
        let out = NSMutableData()
        guard
            let dest = CGImageDestinationCreateWithData(
                out,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        else { return nil }
        CGImageDestinationAddImage(
            dest,
            thumbnail,
            [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary
        )
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
