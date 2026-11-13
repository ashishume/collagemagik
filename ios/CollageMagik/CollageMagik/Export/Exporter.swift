import AVFoundation
import CoreGraphics
import Photos
import UIKit
import UniformTypeIdentifiers

enum ExportQuality: String, CaseIterable, Identifiable {
    case standard, ultra
    var id: String { rawValue }
    var scale: Double { self == .ultra ? 2 : 1 }
    var title: String { self == .ultra ? "Ultra" : "Standard" }
}

struct ExportFailure: LocalizedError {
    let message: String
    init(_ m: String) { message = m }
    var errorDescription: String? { message }
}

/// Renders the collage to an MP4 (H.264 + AAC, 30 fps) or a PNG still.
final class CollageExporter: @unchecked Sendable {
    private let snapshot: ExportSnapshot
    private let total: Double
    private let fps = 30
    private var cancelled = false
    private let lock = NSLock()

    init(snapshot: ExportSnapshot) {
        self.snapshot = snapshot
        total = totalDuration(snapshot.project)
    }

    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    private var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }

    func size(quality: ExportQuality) -> (w: Int, h: Int) {
        let p = snapshot.project
        return (Int(p.canvasWidth * quality.scale), Int(p.canvasHeight * quality.scale))
    }

    /// Can this device encode H.264 at this size?
    static func canEncode(format: FormatId, quality: ExportQuality) -> Bool {
        let w = Int(format.width * quality.scale), h = Int(format.height * quality.scale)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("probe-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: tmp) }
        guard let writer = try? AVAssetWriter(url: tmp, fileType: .mp4) else { return false }
        return writer.canApply(outputSettings: videoSettings(w, h), forMediaType: .video)
    }

    private static func videoSettings(_ w: Int, _ h: Int) -> [String: Any] {
        // about 16 Mbps at 1080×1920, scaled with the picture size
        let bitrate = Int(16_000_000.0 * Double(w * h) / (1080.0 * 1920.0))
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(bitrate, 4_000_000),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoMaxKeyFrameIntervalKey: 60,
            ],
        ]
    }

    private func makeFeeders() -> [String: LaneFrameFeeder] {
        var out: [String: LaneFrameFeeder] = [:]
        for lane in placedLanes(snapshot.project) {
            if let item = snapshot.items[lane.mediaId] { out[lane.mediaId] = LaneFrameFeeder(lane: lane, url: item.url) }
        }
        return out
    }

    // MARK: PNG

    /// A still of the collage as it looks at timeline time `t`.
    func exportPNG(at t: Double, quality: ExportQuality) throws -> URL {
        let (w, h) = size(quality: quality)
        let photos = CollageRenderer.decodePhotos(snapshot: snapshot, W: Double(w), H: Double(h))
        let feeders = makeFeeders()
        guard let ctx = CollageRenderer.makeContext(width: w, height: h) else { throw ExportFailure("Couldn't create the picture.") }
        CollageRenderer.draw(ctx: ctx, W: Double(w), H: Double(h), snapshot: snapshot) { id in
            photos[id] ?? feeders[id]?.frame(at: t)
        }
        guard let image = ctx.makeImage() else { throw ExportFailure("Couldn't create the picture.") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Collage-\(Int(Date().timeIntervalSince1970)).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ExportFailure("Couldn't save the picture.")
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw ExportFailure("Couldn't save the picture.") }
        return url
    }

    // MARK: Carousel slides

    /// The whole carousel drawn once, then cut into one JPEG per slide (in order), ready to post as a carousel.
    func exportSlides() throws -> [URL] {
        let p = snapshot.project
        let slideW = Int(p.format.width), h = Int(p.format.height)
        let slides = p.slides
        let w = slideW * slides
        let photos = CollageRenderer.decodePhotos(snapshot: snapshot, W: Double(w), H: Double(h))
        guard let ctx = CollageRenderer.makeContext(width: w, height: h) else { throw ExportFailure("Couldn't create the pictures.") }
        CollageRenderer.draw(ctx: ctx, W: Double(w), H: Double(h), snapshot: snapshot) { photos[$0] }
        guard let full = ctx.makeImage() else { throw ExportFailure("Couldn't create the pictures.") }
        let stamp = Int(Date().timeIntervalSince1970)
        var urls: [URL] = []
        do {
            for i in 0..<slides {
                guard let slice = full.cropping(to: CGRect(x: i * slideW, y: 0, width: slideW, height: h)) else {
                    throw ExportFailure("Couldn't cut slide \(i + 1).")
                }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("Carousel-\(stamp)-\(i + 1).jpg")
                guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
                    throw ExportFailure("Couldn't save slide \(i + 1).")
                }
                CGImageDestinationAddImage(dest, slice, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
                guard CGImageDestinationFinalize(dest) else { throw ExportFailure("Couldn't save slide \(i + 1).") }
                urls.append(url)
            }
        } catch {
            for u in urls { try? FileManager.default.removeItem(at: u) }
            throw error
        }
        return urls
    }

    // MARK: MP4

    func exportVideo(quality: ExportQuality, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let (w, h) = size(quality: quality)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Collage-\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(url: url, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true
        let vSettings = Self.videoSettings(w, h)
        guard writer.canApply(outputSettings: vSettings, forMediaType: .video) else {
            throw ExportFailure("This iPhone can't encode \(w)×\(h) video. Try Standard quality.")
        }
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: vSettings)
        vInput.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: vInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: w,
                kCVPixelBufferHeightKey as String: h,
            ]
        )
        guard writer.canAdd(vInput) else { throw ExportFailure("Couldn't set up the video encoder.") }
        writer.add(vInput)

        // Sound: the videos' own audio plus the music, mixed.
        let audio = try await buildAudio()
        var aInput: AVAssetWriterInput?
        var aReader: AVAssetReader?
        var aOutput: AVAssetReaderAudioMixOutput?
        if let (comp, mix) = audio {
            let reader = try AVAssetReader(asset: comp)
            let out = AVAssetReaderAudioMixOutput(
                audioTracks: comp.tracks(withMediaType: .audio),
                audioSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 2,
                ]
            )
            out.audioMix = mix
            reader.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: total, preferredTimescale: 600))
            if reader.canAdd(out) {
                reader.add(out)
                let input = AVAssetWriterInput(
                    mediaType: .audio,
                    outputSettings: [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVSampleRateKey: 44100,
                        AVNumberOfChannelsKey: 2,
                        AVEncoderBitRateKey: 192_000,
                    ]
                )
                input.expectsMediaDataInRealTime = false
                if writer.canAdd(input) {
                    writer.add(input)
                    aInput = input
                    aReader = reader
                    aOutput = out
                }
            }
        }

        let photos = CollageRenderer.decodePhotos(snapshot: snapshot, W: Double(w), H: Double(h))
        let feeders = makeFeeders()
        let captionLayer = CaptionRenderer.layer(project: snapshot.project, W: w, H: h)
        let frameCount = max(1, Int((total * Double(fps)).rounded(.up)))

        guard writer.startWriting() else { throw ExportFailure(writer.error?.localizedDescription ?? "Couldn't start the export.") }
        writer.startSession(atSourceTime: .zero)
        if let aReader, !aReader.startReading() { throw ExportFailure(aReader.error?.localizedDescription ?? "Couldn't read the sound.") }

        let group = DispatchGroup()
        let videoQueue = DispatchQueue(label: "collagemagik.export.video")
        let audioQueue = DispatchQueue(label: "collagemagik.export.audio")
        var frameIndex = 0
        var failure: Error?

        group.enter()
        vInput.requestMediaDataWhenReady(on: videoQueue) { [self] in
            while vInput.isReadyForMoreMediaData {
                if isCancelled || failure != nil || frameIndex >= frameCount {
                    vInput.markAsFinished()
                    group.leave()
                    return
                }
                autoreleasepool {
                    guard let pool = adaptor.pixelBufferPool else { failure = ExportFailure("Couldn't allocate video memory."); return }
                    var pbOut: CVPixelBuffer?
                    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOut)
                    guard let pb = pbOut else { failure = ExportFailure("Couldn't allocate video memory."); return }
                    CVPixelBufferLockBaseAddress(pb, [])
                    if let ctx = CollageRenderer.makeContext(
                        width: w, height: h, data: CVPixelBufferGetBaseAddress(pb), bytesPerRow: CVPixelBufferGetBytesPerRow(pb)
                    ) {
                        let t = Double(frameIndex) / Double(fps)
                        CollageRenderer.draw(ctx: ctx, W: Double(w), H: Double(h), snapshot: snapshot, captionLayer: captionLayer) { id in
                            photos[id] ?? feeders[id]?.frame(at: t)
                        }
                    }
                    CVPixelBufferUnlockBaseAddress(pb, [])
                    if !adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps))) {
                        failure = writer.error ?? ExportFailure("The video encoder stopped.")
                        return
                    }
                    frameIndex += 1
                    progress(min(1, Double(frameIndex) / Double(frameCount)) * 0.97)
                }
            }
        }

        if let aInput, let aOutput {
            group.enter()
            aInput.requestMediaDataWhenReady(on: audioQueue) { [self] in
                while aInput.isReadyForMoreMediaData {
                    if isCancelled || failure != nil { aInput.markAsFinished(); group.leave(); return }
                    if let sb = aOutput.copyNextSampleBuffer() {
                        if !aInput.append(sb) { aInput.markAsFinished(); group.leave(); return }
                    } else {
                        aInput.markAsFinished()
                        group.leave()
                        return
                    }
                }
            }
        }

        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            group.notify(queue: .global()) { c.resume() }
        }

        if isCancelled {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            throw CancellationError()
        }
        if let failure {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            throw failure
        }
        await writer.finishWriting()
        guard writer.status == .completed else {
            try? FileManager.default.removeItem(at: url)
            throw ExportFailure(writer.error?.localizedDescription ?? "The export didn't finish.")
        }
        progress(1)
        return url
    }

    // MARK: Audio mix

    private func buildAudio() async throws -> (AVMutableComposition, AVMutableAudioMix)? {
        let project = snapshot.project
        let comp = AVMutableComposition()
        var params: [AVMutableAudioMixInputParameters] = []

        for lane in placedLanes(project) where lane.volume > 0 {
            guard let item = snapshot.items[lane.mediaId], item.hasAudio else { continue }
            let asset = AVURLAsset(url: item.url)
            guard let src = try await asset.loadTracks(withMediaType: .audio).first else { continue }
            let clips = lane.sortedClips
            guard let first = clips.first else { continue }
            let seqStart = first.start
            let seqEnd = clips.map(\.end).max() ?? seqStart
            let seqLen = seqEnd - seqStart
            var offsets: [Double] = [0]
            if lane.loop && seqLen > 0 {
                var k = 1.0
                while seqStart + k * seqLen < total { offsets.append(k * seqLen); k += 1 }
            }
            for off in offsets {
                for clip in clips {
                    let at = clip.start + off
                    let dur = min(clip.length, total - at)
                    if dur <= 0.01 { continue }
                    guard let track = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { continue }
                    do {
                        try track.insertTimeRange(
                            CMTimeRange(start: CMTime(seconds: clip.inPoint, preferredTimescale: 600), duration: CMTime(seconds: dur, preferredTimescale: 600)),
                            of: src, at: CMTime(seconds: at, preferredTimescale: 600)
                        )
                    } catch { continue }
                    let p = AVMutableAudioMixInputParameters(track: track)
                    p.setVolume(Float(lane.volume), at: .zero)
                    params.append(p)
                }
            }
        }

        if let m = project.music, m.volume > 0 {
            let asset = AVURLAsset(url: m.url)
            if let src = try await asset.loadTracks(withMediaType: .audio).first,
               let track = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                for seg in musicSegments(m, total: total) {
                    try? track.insertTimeRange(
                        CMTimeRange(start: CMTime(seconds: seg.from, preferredTimescale: 600), end: CMTime(seconds: seg.to, preferredTimescale: 600)),
                        of: src, at: CMTime(seconds: seg.at, preferredTimescale: 600)
                    )
                }
                let p = AVMutableAudioMixInputParameters(track: track)
                p.setVolume(Float(m.volume), at: .zero)
                if m.fadeOut {
                    let end = m.end(total: total)
                    let start = max(0, end - fadeSeconds)
                    p.setVolumeRamp(
                        fromStartVolume: Float(m.volume), toEndVolume: 0,
                        timeRange: CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), end: CMTime(seconds: end, preferredTimescale: 600))
                    )
                }
                params.append(p)
            }
        }

        guard !comp.tracks(withMediaType: .audio).isEmpty else { return nil }
        let mix = AVMutableAudioMix()
        mix.inputParameters = params
        return (comp, mix)
    }
}

// MARK: - Saving

/// Adding to Photos was refused. Only the person can change that, in Settings, so the UI offers a button for it.
struct PhotosAccessDenied: LocalizedError {
    var errorDescription: String? { "Insta Collage needs permission to add pictures to your Photos. You can allow it in Settings." }
}

/// Saves to Photos with add-only access: the app can add a collage but never read or change what is already there.
/// iOS shows its permission prompt the first time this runs, which is when the person taps Save to Photos.
enum PhotoSaver {
    /// Saves several pictures in one go (a carousel's slides), in order.
    static func saveAll(urls: [URL]) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw PhotosAccessDenied() }
        try await PHPhotoLibrary.shared().performChanges {
            for url in urls { PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url) }
        }
    }

    static func save(url: URL, isVideo: Bool) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw PhotosAccessDenied() }
        try await PHPhotoLibrary.shared().performChanges {
            if isVideo {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } else {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            }
        }
    }
}
