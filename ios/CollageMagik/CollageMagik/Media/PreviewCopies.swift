import AVFoundation
import Foundation

/// Small copies of videos for the live preview. Playing three iPhone videos (often 4K HEVC, sometimes HDR) at once is
/// three full-size decodes plus HDR conversion, every frame. The editor only shows them a few hundred points wide, so
/// each big or HDR video gets a 720p SDR copy, made in the background one at a time; the preview switches to it when
/// it's ready. Exports, thumbnails and drafts always use the original file, so nothing saved loses quality.
///
/// The copies live in the temporary folder (`PreviewCopies/`), which is cleared at launch with the other working files;
/// a reopened draft makes them again.
@MainActor
final class PreviewCopies {
    static let shared = PreviewCopies()

    /// Longest side of a copy. A video already this small (and not HDR) plays from its own file.
    nonisolated static let maxSide: Double = 1280

    nonisolated static let folder: URL = {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("PreviewCopies", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Copies made so far, by media id.
    private var ready: [String: URL] = [:]
    /// Videos waiting for a copy, oldest first, and the ones already looked at (made, being made, or not needed).
    private var queue: [(id: String, url: URL)] = []
    private var seen: Set<String> = []
    private var working = false

    /// Called when a video's copy is ready, so its player can switch to it.
    var onReady: ((String, URL) -> Void)?

    /// Debug builds: `CM_NO_PREVIEW_COPY=1` plays the originals, to compare.
    private var disabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["CM_NO_PREVIEW_COPY"] == "1"
        #else
        false
        #endif
    }

    /// The file the live preview should play for this video: its small copy when there is one, otherwise the original.
    func playbackURL(for item: MediaItem) -> URL { ready[item.id] ?? item.url }

    /// Asks for a copy of `item` (once per video; a video that doesn't need one is left alone).
    func request(_ item: MediaItem) {
        guard item.kind == .video, !disabled, !seen.contains(item.id) else { return }
        seen.insert(item.id)
        // small SDR videos play fine as they are; HDR is only known once the file is read, so those are checked there
        queue.append((item.id, item.url))
        startNext()
    }

    private func startNext() {
        guard !working, !queue.isEmpty else { return }
        working = true
        let job = queue.removeFirst()
        Task.detached(priority: .utility) {
            let start = Date()
            let made = await Self.makeCopy(of: job.url, id: job.id)
            await MainActor.run {
                if let made {
                    self.ready[job.id] = made
                    NSLog("CM_PREVIEW_COPY ready %@ in %.1fs", job.id, Date().timeIntervalSince(start))
                    self.onReady?(job.id, made)
                }
                self.working = false
                self.startNext()
            }
        }
    }

    /// A 720p SDR copy of the video at `url`, or nil when the video is already small and SDR (or can't be copied:
    /// the preview then simply keeps playing the original).
    nonisolated private static func makeCopy(of url: URL, id: String) async -> URL? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let (natural, transform) = try? await track.load(.naturalSize, .preferredTransform)
        else { return nil }
        let box = CGRect(origin: .zero, size: natural).applying(transform)
        let longSide = max(abs(box.width), abs(box.height))
        let hdr = (try? await track.load(.mediaCharacteristics))?.contains(.containsHDRVideo) ?? false
        guard longSide > maxSide + 1 || hdr else { return nil }

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else { return nil }
        if hdr {
            // the copy is plain SDR (BT.709): no HDR conversion while it plays
            let comp = AVMutableVideoComposition(propertiesOf: asset)
            comp.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
            comp.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
            comp.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
            session.videoComposition = comp
        }
        // the folder may have been cleared at launch after it was first made
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let out = folder.appendingPathComponent("\(id)-\(UUID().uuidString.prefix(8)).mp4")
        do {
            try await session.export(to: out, as: .mp4)
        } catch {
            try? FileManager.default.removeItem(at: out)
            return nil
        }
        return out
    }
}
