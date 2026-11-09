import AVFoundation
import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImportError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// Reads photos, videos and music from files and checks that this iPhone can actually play and export them,
/// so a bad file is rejected with a clear message instead of failing later in the preview or the export.
enum MediaLoader {
    static let importFolder: URL = {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Imports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Copies a file into the app's own folder so it stays readable (security-scoped and picker URLs are short-lived).
    static func copyIntoApp(_ url: URL) throws -> URL {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension
        let dest = importFolder.appendingPathComponent(UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)"))
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
    }

    static func kind(of url: URL) -> MediaKind? {
        if let t = UTType(filenameExtension: url.pathExtension.lowercased()) {
            if t.conforms(to: .movie) || t.conforms(to: .video) || t.conforms(to: .audiovisualContent) && !t.conforms(to: .audio) { return .video }
            if t.conforms(to: .image) { return .photo }
            return nil
        }
        // No usable extension: look inside the file.
        if let src = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(src) > 0 { return .photo }
        return .video
    }

    static func isAudioFile(_ url: URL) -> Bool {
        guard let t = UTType(filenameExtension: url.pathExtension.lowercased()) else { return false }
        return t.conforms(to: .audio)
    }

    static func load(url: URL, name: String) async throws -> MediaItem {
        switch kind(of: url) {
        case .photo: return try loadPhoto(url: url, name: name)
        case .video: return try await loadVideo(url: url, name: name)
        case nil: throw ImportError("\(name): only photos and videos can be added.")
        }
    }

    // MARK: Photos

    static func loadPhoto(url: URL, name: String) throws -> MediaItem {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let pw = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let ph = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue
        else { throw ImportError("\(name): this picture couldn't be read.") }
        let orientation = (props[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let swapped = (5...8).contains(orientation)
        func thumb(_ maxPixels: Int) -> UIImage? {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            ]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
            return UIImage(cgImage: cg)
        }
        guard let preview = thumb(1600), let small = thumb(420) else { throw ImportError("\(name): this picture couldn't be read.") }
        return MediaItem(
            id: newId(), kind: .photo, url: url, name: name,
            width: swapped ? ph : pw, height: swapped ? pw : ph,
            duration: 0, hasAudio: false, thumbnail: small, preview: preview
        )
    }

    // MARK: Videos

    static func codecName(_ track: AVAssetTrack) async -> String? {
        guard let descs = try? await track.load(.formatDescriptions), let d = descs.first else { return nil }
        let sub = CMFormatDescriptionGetMediaSubType(d)
        let bytes = [UInt8((sub >> 24) & 0xFF), UInt8((sub >> 16) & 0xFF), UInt8((sub >> 8) & 0xFF), UInt8(sub & 0xFF)]
        return String(bytes: bytes, encoding: .macOSRoman)?.trimmingCharacters(in: .whitespaces)
    }

    static func loadVideo(url: URL, name: String) async throws -> MediaItem {
        let asset = AVURLAsset(url: url)
        let ext = url.pathExtension.uppercased()
        let supported = "Use an MP4 or MOV video (H.264 or HEVC)."

        let playable: Bool, readable: Bool, duration: CMTime
        do {
            (playable, readable, duration) = try await asset.load(.isPlayable, .isReadable, .duration)
        } catch {
            let what = ext.isEmpty ? "" : " format .\(ext)"
            throw ImportError("\(name): this video\(what) can't be played on iPhone. \(supported)")
        }
        guard let track = try? await asset.loadTracks(withMediaType: .video).first else {
            throw ImportError("\(name): no video was found in this file. \(supported)")
        }
        let codec = await codecName(track)
        let decodable = (try? await track.load(.isDecodable)) ?? true
        guard playable, readable, decodable else {
            let what = [ext.isEmpty ? nil : ".\(ext)", codec.map { "(\($0))" }].compactMap { $0 }.joined(separator: " ")
            throw ImportError("\(name): this video format \(what) can't be played on iPhone. \(supported)")
        }
        let seconds = duration.seconds
        guard seconds.isFinite, seconds > 0.1 else { throw ImportError("\(name): this video is empty.") }

        let (natural, transform) = try await track.load(.naturalSize, .preferredTransform)
        let box = CGRect(origin: .zero, size: natural).applying(transform)
        let w = abs(box.width), h = abs(box.height)
        guard w > 1, h > 1 else { throw ImportError("\(name): this video has no picture size.") }
        let hasAudio = ((try? await asset.loadTracks(withMediaType: .audio))?.isEmpty == false)

        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 640, height: 640)
        gen.requestedTimeToleranceBefore = .positiveInfinity
        gen.requestedTimeToleranceAfter = .positiveInfinity
        var thumb: UIImage?
        for t in [min(0.15, seconds / 2), 0] {
            if let r = try? await gen.image(at: CMTime(seconds: t, preferredTimescale: 600)) {
                thumb = UIImage(cgImage: r.image)
                break
            }
        }
        guard let thumbnail = thumb else {
            throw ImportError("\(name): the pictures in this video can't be decoded on this iPhone. \(supported)")
        }
        return MediaItem(
            id: newId(), kind: .video, url: url, name: name,
            width: w, height: h, duration: seconds, hasAudio: hasAudio, thumbnail: thumbnail, preview: nil
        )
    }

    // MARK: Music

    static func loadMusic(url: URL, name: String) async throws -> Double {
        let asset = AVURLAsset(url: url)
        guard let (playable, duration) = try? await asset.load(.isPlayable, .duration), playable,
              (try? await asset.loadTracks(withMediaType: .audio))?.isEmpty == false
        else { throw ImportError("\(name): this audio file can't be played. Use MP3, M4A, AAC or WAV.") }
        let s = duration.seconds
        guard s.isFinite, s > 0.2 else { throw ImportError("\(name): this audio file is empty.") }
        return s
    }
}
