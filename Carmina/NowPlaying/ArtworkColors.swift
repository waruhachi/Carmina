//
//  ArtworkColors.swift
//  Carmina
//
//  Created by waru on 7/17/26.
//

import SwiftUI

#if canImport(UIKit)
    import UIKit
    typealias PlatformImage = UIImage
#elseif canImport(AppKit)
    import AppKit
    typealias PlatformImage = NSImage
#endif

enum ArtworkColors {
    static func meshColors(from image: PlatformImage) -> [Color] {
        guard let cg = image.cgImageForColors else { return [] }
        let side = 3
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        guard
            let ctx = CGContext(
                data: &pixels,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return [] }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        return (0..<side * side).map { i in
            let o = i * 4
            return Color(
                red: Double(pixels[o]) / 255,
                green: Double(pixels[o + 1]) / 255,
                blue: Double(pixels[o + 2]) / 255
            )
        }
    }
}

extension PlatformImage {
    fileprivate var cgImageForColors: CGImage? {
        #if canImport(UIKit)
            return cgImage
        #elseif canImport(AppKit)
            var rect = CGRect(origin: .zero, size: size)
            return cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #else
            return nil
        #endif
    }
}
