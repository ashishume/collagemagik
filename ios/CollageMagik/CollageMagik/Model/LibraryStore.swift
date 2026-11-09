import AVFoundation
import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// One finished collage kept in My Library.
struct LibraryEntry: Codable, Identifiable, Hashable {
    let id: String
    let isVideo: Bool
    let createdAt: Date
    /// Pixels.
    let width: Int
    let height: Int
    /// Seconds. 0 for pictures.
    let duration: Double
    /// "Story 9:16", "Post 4:5" or "Square 1:1".
    let formatLabel: String
    let fileName: String
    let thumbName: String
    let bytes: Int64
    /// Carousels: the slide pictures in order (`fileName` is the first one). Nil for a single collage.
    var slideFiles: [String]? = nil

    var isCarousel: Bool { slideFiles != nil }
    var slideCount: Int { slideFiles?.count ?? 1 }
    /// Every file this entry owns, apart from its thumbnail.
    var allFileNames: [String] { slideFiles ?? [fileName] }
}

/// The files behind My Library. Everything lives in the app's own Documents folder on this iPhone: there is no account,
/// no server and no iCloud sync. Deleting the app deletes the library.
enum LibraryDisk {
    static let folder: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("MyLibrary", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static var indexURL: URL { folder.appendingPathComponent("library.json") }

    static func fileURL(_ name: String) -> URL { folder.appendingPathComponent(name) }

    /// Copies a finished export into the library and makes a small thumbnail for the grid.
    static func store(
        file: URL, id: String, isVideo: Bool, width: Int, height: Int, duration: Double, formatLabel: String, createdAt: Date
    ) async throws -> LibraryEntry {
        let fileName = "\(id).\(isVideo ? "mp4" : "png")"
        let thumbName = "\(id)-thumb.jpg"
        let dest = fileURL(fileName)
        let thumbDest = fileURL(thumbName)
        do {
            try FileManager.default.copyItem(at: file, to: dest)
            guard let jpeg = await thumbnailJPEG(of: dest, isVideo: isVideo) else {
                throw ImportError("The collage couldn't be read back after saving.")
            }
            try jpeg.write(to: thumbDest, options: .atomic)
            let bytes = Int64((try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            return LibraryEntry(
                id: id, isVideo: isVideo, createdAt: createdAt, width: width, height: height,
                duration: duration, formatLabel: formatLabel, fileName: fileName, thumbName: thumbName, bytes: bytes
            )
        } catch {
            // Don't leave half-written files behind (a full disk is the usual reason).
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.removeItem(at: thumbDest)
            throw error
        }
    }

    /// Copies a carousel's slide pictures into the library. The thumbnail is the first slide.
    static func storeCarousel(
        files: [URL], id: String, width: Int, height: Int, formatLabel: String, createdAt: Date
    ) async throws -> LibraryEntry {
        var copied: [String] = []
        let thumbName = "\(id)-thumb.jpg"
        do {
            for (i, file) in files.enumerated() {
                let name = "\(id)-\(i + 1).jpg"
                try FileManager.default.copyItem(at: file, to: fileURL(name))
                copied.append(name)
            }
            guard let first = copied.first, let jpeg = await thumbnailJPEG(of: fileURL(first), isVideo: false) else {
                throw ImportError("The carousel couldn't be read back after saving.")
            }
            try jpeg.write(to: fileURL(thumbName), options: .atomic)
            let bytes = copied.reduce(Int64(0)) { $0 + Int64((try? fileURL($1).resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
            return LibraryEntry(
                id: id, isVideo: false, createdAt: createdAt, width: width, height: height, duration: 0,
                formatLabel: formatLabel, fileName: copied[0], thumbName: thumbName, bytes: bytes, slideFiles: copied
            )
        } catch {
            for n in copied + [thumbName] { try? FileManager.default.removeItem(at: fileURL(n)) }
            throw error
        }
    }

    static func thumbnailJPEG(of url: URL, isVideo: Bool) async -> Data? {
        let maxSide = 480
        var image: UIImage?
        if isVideo {
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: maxSide, height: maxSide)
            gen.requestedTimeToleranceBefore = .positiveInfinity
            gen.requestedTimeToleranceAfter = .positiveInfinity
            for t in [0.2, 0] {
                if let r = try? await gen.image(at: CMTime(seconds: t, preferredTimescale: 600)) {
                    image = UIImage(cgImage: r.image)
                    break
                }
            }
        } else if let src = CGImageSourceCreateWithURL(url as CFURL, nil) {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxSide,
            ]
            if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) { image = UIImage(cgImage: cg) }
        }
        return image?.jpegData(compressionQuality: 0.8)
    }
}

/// My Library: the collages you have exported, kept on this iPhone only.
@MainActor
@Observable
final class LibraryStore {
    /// Newest first.
    private(set) var entries: [LibraryEntry] = []

    @ObservationIgnored private let thumbCache = NSCache<NSString, UIImage>()

    init() { load() }

    var totalBytes: Int64 { entries.reduce(0) { $0 + $1.bytes } }

    func url(for entry: LibraryEntry) -> URL { LibraryDisk.fileURL(entry.fileName) }
    /// A carousel's slide pictures in order (a single collage has one).
    func urls(for entry: LibraryEntry) -> [URL] { entry.allFileNames.map(LibraryDisk.fileURL) }

    func thumbnail(for entry: LibraryEntry) -> UIImage? {
        if let hit = thumbCache.object(forKey: entry.id as NSString) { return hit }
        guard let img = UIImage(contentsOfFile: LibraryDisk.fileURL(entry.thumbName).path) else { return nil }
        thumbCache.setObject(img, forKey: entry.id as NSString)
        return img
    }

    // MARK: Changes

    /// Keeps a copy of a finished export. The export itself stays where it is (it is still being shared or saved).
    @discardableResult
    func add(file: URL, isVideo: Bool, width: Int, height: Int, duration: Double, formatLabel: String) async throws -> LibraryEntry {
        let id = UUID().uuidString
        let now = Date()
        let entry = try await Task.detached(priority: .utility) {
            try await LibraryDisk.store(
                file: file, id: id, isVideo: isVideo, width: width, height: height,
                duration: duration, formatLabel: formatLabel, createdAt: now
            )
        }.value
        entries.insert(entry, at: 0)
        persist()
        return entry
    }

    /// Keeps a copy of a carousel's slides as one entry.
    @discardableResult
    func addCarousel(files: [URL], width: Int, height: Int, formatLabel: String) async throws -> LibraryEntry {
        let id = UUID().uuidString
        let now = Date()
        let entry = try await Task.detached(priority: .utility) {
            try await LibraryDisk.storeCarousel(files: files, id: id, width: width, height: height, formatLabel: formatLabel, createdAt: now)
        }.value
        entries.insert(entry, at: 0)
        persist()
        return entry
    }

    func remove(_ entry: LibraryEntry) {
        entries.removeAll { $0.id == entry.id }
        thumbCache.removeObject(forKey: entry.id as NSString)
        for name in entry.allFileNames + [entry.thumbName] { try? FileManager.default.removeItem(at: LibraryDisk.fileURL(name)) }
        persist()
    }

    func removeAll() {
        for e in entries {
            for name in e.allFileNames + [e.thumbName] { try? FileManager.default.removeItem(at: LibraryDisk.fileURL(name)) }
        }
        entries = []
        thumbCache.removeAllObjects()
        persist()
    }

    // MARK: Index

    private func load() {
        guard let data = try? Data(contentsOf: LibraryDisk.indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let all = try? decoder.decode([LibraryEntry].self, from: data) else { return }
        // Forget entries whose file has gone (for example it was removed from the Files app).
        let present = all.filter { FileManager.default.fileExists(atPath: LibraryDisk.fileURL($0.fileName).path) }
        entries = present.sorted { $0.createdAt > $1.createdAt }
        if present.count != all.count { persist() }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: LibraryDisk.indexURL, options: .atomic)
    }
}

// MARK: - Formatting

extension LibraryEntry {
    var summary: String {
        var parts = [formatLabel, "\(width)×\(height)"]
        if isCarousel { parts.insert("\(slideCount) slides", at: 1) }
        if isVideo { parts.append(formatTime(duration)) }
        parts.append(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
        return parts.joined(separator: " · ")
    }
}

// MARK: - Temporary files

extension MediaLoader {
    /// Clears the working copies of imported media and finished exports left in the temporary folder by earlier sessions.
    /// Run at launch, when nothing is open. Collages you want to keep are already in My Library.
    static func purgeTemporaryFiles() {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        guard let names = try? fm.contentsOfDirectory(atPath: tmp.path) else { return }
        for name in names where name == "Imports" || name.hasPrefix("Collage-") || name.hasPrefix("Carousel-") || name.hasPrefix("probe-") {
            try? fm.removeItem(at: tmp.appendingPathComponent(name))
        }
    }
}
