import SwiftUI
import UIKit

// Enums saved in drafts (they save as their raw names).
extension FormatId: Codable {}
extension EditMode: Codable {}
extension PhotoFrame: Codable {}
extension CaptionFont: Codable {}
extension CaptionLook: Codable {}
extension CaptionAlign: Codable {}
extension CaptionOrnament: Codable {}
extension CaptionMix: Codable {}

/// One photo or video a draft uses, stored in the draft's own `media` folder.
struct DraftItem: Codable {
    var id: String
    var isVideo: Bool
    var file: String
    var name: String
}

/// What `draft.json` holds: the whole design, and which files it uses.
struct DraftFile: Codable {
    var version = 1
    var id: String
    var createdAt: Date
    var updatedAt: Date
    var items: [DraftItem]
    /// The background song's file in `media`, if there is one (the project's own music URL is replaced on opening).
    var musicFile: String?
    var project: Project
}

/// A draft as My Library lists it.
struct DraftSummary: Identifiable, Hashable {
    let id: String
    let updatedAt: Date
    let mode: EditMode
    let format: FormatId
    let slides: Int
    let photos: Int
    let videos: Int
    let thumbURL: URL
    let bytes: Int64

    /// Width / height of the thumbnail (the whole carousel strip for a carousel).
    var aspect: Double { (mode == .carousel ? Double(slides) : 1) * format.width / format.height }
    var summary: String {
        var parts: [String] = []
        if photos > 0 { parts.append("\(photos) \(photos == 1 ? "photo" : "photos")") }
        if videos > 0 { parts.append("\(videos) \(videos == 1 ? "video" : "videos")") }
        return parts.isEmpty ? format.label : parts.joined(separator: " · ")
    }
}

/// Drafts live in the app's Documents folder, one folder each: `draft.json`, `thumb.jpg` and copies of the photos,
/// videos and song they use (hard links where possible, so saving a video costs no extra space or time). They stay
/// on this iPhone only, and survive the app being closed; iOS doesn't clear them the way it clears temporary files.
enum DraftDisk {
    static let root: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Drafts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Writes happen one at a time, off the main thread.
    static let queue = DispatchQueue(label: "collagemagik.drafts", qos: .utility)

    static func folder(_ id: String) -> URL { root.appendingPathComponent(id, isDirectory: true) }
    static func media(_ id: String) -> URL { folder(id).appendingPathComponent("media", isDirectory: true) }

    /// Puts `src` into the draft's media folder as `name` (a hard link if it can, a copy if not). Already there: nothing to do.
    private static func bring(_ src: URL, into dir: URL, as name: String) -> Bool {
        let fm = FileManager.default
        let dest = dir.appendingPathComponent(name)
        if fm.fileExists(atPath: dest.path) { return true }
        guard fm.fileExists(atPath: src.path) else { return false }
        if (try? fm.linkItem(at: src, to: dest)) != nil { return true }
        return (try? fm.copyItem(at: src, to: dest)) != nil
    }

    struct Media { var id: String; var isVideo: Bool; var url: URL; var name: String }

    static func write(id: String, createdAt: Date, project: Project, items: [Media], thumb: Data?) throws {
        let fm = FileManager.default
        let dir = folder(id)
        let mediaDir = media(id)
        try fm.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        var saved: [DraftItem] = []
        for m in items {
            let ext = m.url.pathExtension
            let file = m.id + (ext.isEmpty ? "" : ".\(ext)")
            if bring(m.url, into: mediaDir, as: file) { saved.append(DraftItem(id: m.id, isVideo: m.isVideo, file: file, name: m.name)) }
        }
        var p = project
        var musicFile: String?
        if let m = p.music {
            let file = m.url.deletingLastPathComponent().standardizedFileURL == mediaDir.standardizedFileURL
                ? m.url.lastPathComponent
                : "music-" + m.url.lastPathComponent
            if bring(m.url, into: mediaDir, as: file) {
                musicFile = file
                p.music?.url = URL(fileURLWithPath: "/" + file)
            } else {
                p.music = nil
            }
        }
        // files the design no longer uses
        let keep = Set(saved.map(\.file) + [musicFile].compactMap { $0 })
        for name in (try? fm.contentsOfDirectory(atPath: mediaDir.path)) ?? [] where !keep.contains(name) {
            try? fm.removeItem(at: mediaDir.appendingPathComponent(name))
        }
        let file = DraftFile(id: id, createdAt: createdAt, updatedAt: Date(), items: saved, musicFile: musicFile, project: p)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        try enc.encode(file).write(to: dir.appendingPathComponent("draft.json"), options: .atomic)
        if let thumb { try? thumb.write(to: dir.appendingPathComponent("thumb.jpg"), options: .atomic) }
    }

    /// Reads a draft. Fields added to the app after the draft was saved take their defaults, so older drafts still open.
    static func read(_ id: String) throws -> DraftFile {
        let data = try Data(contentsOf: folder(id).appendingPathComponent("draft.json"))
        guard var top = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let saved = top["project"] as? [String: Any] else { throw ImportError("This draft is damaged.") }
        top["project"] = withDefaults(saved)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(DraftFile.self, from: try JSONSerialization.data(withJSONObject: top))
    }

    private static func json<T: Encodable>(_ v: T) -> [String: Any] {
        guard let d = try? JSONEncoder().encode(v), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return o
    }

    private static func fill(_ saved: [String: Any], _ defaults: [String: Any]) -> [String: Any] {
        var out = saved
        for (k, v) in defaults where out[k] == nil { out[k] = v }
        return out
    }

    private static func withDefaults(_ saved: [String: Any]) -> [String: Any] {
        var p = fill(saved, json(Project()))
        func each(_ key: String, _ template: [String: Any], _ inner: ((inout [String: Any]) -> Void)? = nil) {
            guard let arr = p[key] as? [[String: Any]] else { return }
            p[key] = arr.map { e -> [String: Any] in
                var f = fill(e, template)
                inner?(&f)
                return f
            }
        }
        each("cells", json(CellState()))
        each("captions", json(Caption()))
        each("overlays", json(PhotoOverlay(mediaId: "", cx: 0.5, cy: 0.5)))
        let clip = json(Clip(id: "", start: 0, inPoint: 0, outPoint: 0))
        each("lanes", json(Lane(mediaId: "", clips: [], loop: false, volume: 1))) { lane in
            if let clips = lane["clips"] as? [[String: Any]] { lane["clips"] = clips.map { fill($0, clip) } }
        }
        if let m = p["music"] as? [String: Any] {
            p["music"] = fill(m, json(MusicTrack(url: URL(fileURLWithPath: "/"), name: "", duration: 0, volume: 0.7, start: 0, inPoint: 0, outPoint: 0, loop: false, fadeOut: true)))
        }
        return p
    }

    /// Every draft, most recently edited first.
    static func list() -> [DraftSummary] {
        let fm = FileManager.default
        guard let ids = try? fm.contentsOfDirectory(atPath: root.path) else { return [] }
        return ids.compactMap { id -> DraftSummary? in
            guard let f = try? read(id) else { return nil }
            var bytes: Int64 = 0
            if let e = fm.enumerator(at: folder(id), includingPropertiesForKeys: [.fileAllocatedSizeKey]) {
                for case let u as URL in e { bytes += Int64((try? u.resourceValues(forKeys: [.fileAllocatedSizeKey]))?.fileAllocatedSize ?? 0) }
            }
            return DraftSummary(
                id: id, updatedAt: f.updatedAt, mode: f.project.mode, format: f.project.format, slides: f.project.slides,
                photos: f.items.filter { !$0.isVideo }.count, videos: f.items.filter(\.isVideo).count,
                thumbURL: folder(id).appendingPathComponent("thumb.jpg"), bytes: bytes
            )
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    static func remove(_ id: String) {
        try? FileManager.default.removeItem(at: folder(id))
    }

    /// A small picture of the design for the Drafts list, drawn from the tray thumbnails (quick enough for every save).
    @MainActor
    static func thumbnail(project: Project, items: [MediaItem]) -> Data? {
        let maxSide = 420.0
        let cw = project.canvasWidth, ch = project.canvasHeight
        let k = maxSide / max(cw, ch)
        let w = max(1, Int((cw * k).rounded())), h = max(1, Int((ch * k).rounded()))
        guard let ctx = CollageRenderer.makeContext(width: w, height: h) else { return nil }
        let byId = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let snapshot = ExportSnapshot(project: project, items: byId)
        CollageRenderer.draw(ctx: ctx, W: Double(w), H: Double(h), snapshot: snapshot) { id in
            guard let item = byId[id] else { return nil }
            return (item.preview ?? item.thumbnail).cgImage
        }
        guard let img = ctx.makeImage() else { return nil }
        return UIImage(cgImage: img).jpegData(compressionQuality: 0.8)
    }
}
