import Foundation
import PhotosUI
import SwiftUI

/// What the import loader shows while photos and videos are being added: "Adding 2 of 5" and a progress bar.
struct ImportProgress: Equatable {
    let total: Int
    /// The item being worked on, 1-based.
    private(set) var current = 1
    /// How many have been added so far.
    private(set) var added = 0
    /// How far the current item is (0...1): fetching it from Photos, then reading it.
    private(set) var itemFraction = 0.0
    private(set) var detail = ""

    init(total: Int) { self.total = max(1, total) }

    /// The whole import, 0...1.
    var fraction: Double { min(1, (Double(current - 1) + itemFraction) / Double(total)) }
    var title: String { total == 1 ? "Adding 1 item" : "Adding \(current) of \(total)" }

    mutating func start(item: Int, detail: String) {
        current = min(max(1, item), total)
        itemFraction = 0
        self.detail = detail
    }

    mutating func update(fraction: Double, detail: String) {
        itemFraction = max(itemFraction, min(1, fraction))
        self.detail = detail
    }

    mutating func finishItem(added: Int) {
        self.added = added
        itemFraction = 1
    }
}

/// One thing being added to the tray.
enum ImportSource {
    /// Still in the photo library (may need downloading from iCloud).
    case picker(PhotosPickerItem)
    /// A file outside the app (Files): copied in first.
    case external(URL)
    /// Already in the app's own folder.
    case local(URL)

    /// What happens before the item can be read: "Getting video…" (from Photos, maybe iCloud), "Copying photo…".
    var fetchVerb: String {
        switch self {
        case .picker: return "Getting"
        case .external: return "Copying"
        case .local: return "Reading"
        }
    }

    /// What the item is, before its file is fetched (nil = neither a photo nor a video).
    var kindHint: MediaKind? {
        switch self {
        case .picker(let p):
            if p.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) { return .video }
            if p.supportedContentTypes.contains(where: { $0.conforms(to: .image) }) { return .photo }
            return p.supportedContentTypes.isEmpty ? .photo : nil
        case .external(let u), .local(let u):
            return MediaLoader.kind(of: u)
        }
    }

    /// The name shown in the tray, when the source knows a better one than the copied file's.
    var name: String? {
        switch self {
        case .picker: return nil
        case .external(let u): return u.deletingPathExtension().lastPathComponent
        case .local: return nil
        }
    }

    var label: String {
        switch self {
        case .picker: return kindHint == .video ? "A video" : "A photo"
        case .external(let u), .local(let u): return u.lastPathComponent
        }
    }

    /// Gets the file into the app's own folder, off the main thread. `onProgress` gets 0...1 on the main actor.
    func resolve(onProgress: @escaping @MainActor (Double) -> Void) async throws -> URL {
        switch self {
        case .local(let u):
            return u
        case .external(let u):
            let copied = try await Task.detached(priority: .userInitiated) { try MediaLoader.copyIntoApp(u) }.value
            await onProgress(1)
            return copied
        case .picker(let p):
            if kindHint == .video, let url = try await Self.transfer(p, as: PickedMovie.self, onProgress: onProgress) { return url }
            if let url = try await Self.transfer(p, as: PickedImage.self, onProgress: onProgress) { return url }
            throw ImportError("this item couldn't be read.")
        }
    }

    /// `loadTransferable` with its byte progress reported, and cancelled when the import is cancelled.
    private static func transfer<T: Transferable & PickedFile>(
        _ item: PhotosPickerItem, as type: T.Type, onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> URL? {
        let box = ProgressBox()
        defer { box.finish() }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL?, Error>) in
                let progress = item.loadTransferable(type: T.self) { result in
                    cont.resume(with: result.map { $0?.url })
                }
                box.attach(progress) { f in Task { @MainActor in onProgress(f) } }
            }
        } onCancel: {
            box.cancel()
        }
    }
}

/// A picked file copied into the app.
protocol PickedFile { var url: URL { get } }
extension PickedMovie: PickedFile {}
extension PickedImage: PickedFile {}

/// Holds the `Progress` of one transfer so it can be watched and cancelled from another thread.
private final class ProgressBox: @unchecked Sendable {
    private let lock = NSLock()
    private var progress: Progress?
    private var observation: NSKeyValueObservation?
    private var cancelled = false

    func attach(_ p: Progress, onChange: @escaping @Sendable (Double) -> Void) {
        lock.lock(); defer { lock.unlock() }
        progress = p
        observation = p.observe(\.fractionCompleted, options: [.initial, .new]) { p, _ in onChange(p.fractionCompleted) }
        if cancelled { p.cancel() }
    }

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        progress?.cancel()
    }

    func finish() {
        lock.lock(); defer { lock.unlock() }
        observation?.invalidate()
        observation = nil
        progress = nil
    }
}
