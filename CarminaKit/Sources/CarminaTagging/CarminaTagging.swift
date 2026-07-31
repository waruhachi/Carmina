//
//  CarminaTagging.swift
//  CarminaKit
//
//  Created by waru on 7/4/26.
//

import AVFoundation
import Foundation
import ID3TagEditor

public struct TagMetadata: Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var artwork: Data?

    public init(title: String, artist: String, album: String, artwork: Data?) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artwork = artwork
    }
}

public enum TagWriteError: Error { case unsupportedFormat, exportFailed }

public struct TagWriter: Sendable {
    public init() {}

    public func write(_ meta: TagMetadata, to url: URL) async throws {
        switch url.pathExtension.lowercased() {
        case "mp3":
            try writeMP3(meta, to: url)
        case "m4a", "mp4", "m4b", "aac":
            try await writeMP4(meta, to: url)
        default:
            throw TagWriteError.unsupportedFormat
        }
    }

    private func writeMP3(_ meta: TagMetadata, to url: URL) throws {
        var builder = ID32v3TagBuilder()
            .title(frame: ID3FrameWithStringContent(content: meta.title))
            .artist(frame: ID3FrameWithStringContent(content: meta.artist))
            .album(frame: ID3FrameWithStringContent(content: meta.album))
        if let art = meta.artwork {
            let format: ID3PictureFormat =
                art.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? .png : .jpeg
            builder = builder.attachedPicture(
                pictureType: .frontCover,
                frame: ID3FrameAttachedPicture(
                    picture: art,
                    type: .frontCover,
                    format: format
                )
            )
        }
        let tag = builder.build()

        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent("\(UUID().uuidString).mp3")
        try ID3TagEditor().write(tag: tag, to: url.path, andSaveTo: tmp.path)
        try replace(url, with: tmp)
    }

    private func writeMP4(_ meta: TagMetadata, to url: URL) async throws {
        let asset = AVURLAsset(url: url)
        guard
            let export = AVAssetExportSession(
                asset: asset,
                presetName: AVAssetExportPresetPassthrough
            )
        else { throw TagWriteError.exportFailed }

        var items: [AVMetadataItem] = [
            string(.commonIdentifierTitle, meta.title),
            string(.commonIdentifierArtist, meta.artist),
            string(.commonIdentifierAlbumName, meta.album),
        ]
        if let art = meta.artwork {
            items.append(data(.commonIdentifierArtwork, art))
        }
        export.metadata = items

        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent("\(UUID().uuidString).m4a")
        try await export.export(to: tmp, as: .m4a)
        try replace(url, with: tmp)
    }

    private func string(
        _ id: AVMetadataIdentifier,
        _ value: String
    ) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = id
        item.value = value as NSString
        item.extendedLanguageTag = "und"
        return item
    }

    private func data(
        _ id: AVMetadataIdentifier,
        _ value: Data
    ) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = id
        item.value = value as NSData
        item.extendedLanguageTag = "und"
        return item
    }

    private func replace(_ dest: URL, with temp: URL) throws {
        _ = try FileManager.default.replaceItemAt(dest, withItemAt: temp)
    }
}
