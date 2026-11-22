import AVFoundation
import CoreGraphics
import CoreImage
import Photos
import UIKit
import UniformTypeIdentifiers
import VideoToolbox

#if DEBUG
private final class ExportMeasurement: @unchecked Sendable {
    private let started = CACurrentMediaTime()
    private var peakBytes: UInt64 = 0

    init() { sample() }

    func sample() {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        if status == KERN_SUCCESS { peakBytes = max(peakBytes, info.phys_footprint) }
    }

    func finish(engine: String, width: Int, height: Int, fps: Int, frames: Int) {
        sample()
        let line = String(format: "CM_EXPORT engine=%@ %d×%d fps=%d frames=%d seconds=%.3f peakMB=%.1f",
                          locale: Locale(identifier: "en_US_POSIX"),
                          engine, width, height, fps, frames, CACurrentMediaTime() - started, Double(peakBytes) / 1_048_576)
        NSLog("%@", line)
        if let path = ProcessInfo.processInfo.environment["CM_EXPORT_METRICS"] {
            try? line.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}
#endif

enum ExportEngine: String {
    case cpu, gpu

    static var requested: Self {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["CM_EXPORT_ENGINE"], let engine = Self(rawValue: raw) {
            return engine
        }
        #endif
        return .gpu
    }
}

private final class CPUVideoComposer {
    private let snapshot: ExportSnapshot
    private let photos: [String: CGImage]
    private let captions: CaptionLayers
    private let width: Int
    private let height: Int
    private let hdrContext: CGContext?

    init(snapshot: ExportSnapshot, photos: [String: CGImage], captions: CaptionLayers, width: Int, height: Int, hdr: Bool) throws {
        self.snapshot = snapshot
        self.photos = photos
        self.captions = captions
        self.width = width
        self.height = height
        hdrContext = hdr ? CollageRenderer.makeContext(width: width, height: height, hdr: true) : nil
        if hdr, hdrContext?.data == nil { throw ExportFailure(String(localized: "Couldn't set up HDR drawing.")) }
    }

    func render(at time: Double, to buffer: CVPixelBuffer, feeders: [String: LaneFrameFeeder]) throws {
        func draw(_ context: CGContext) {
            CollageRenderer.draw(ctx: context, W: Double(width), H: Double(height),
                                 snapshot: snapshot, t: time, captionLayers: captions) { id in
                photos[id] ?? feeders[id]?.frame(at: time)
            }
        }
        if let context = hdrContext, let canvas = context.data {
            draw(context)
            let rowBytes = context.bytesPerRow
            let data = Data(bytesNoCopy: canvas, count: rowBytes * height, deallocator: .none)
            let frame = CIImage(bitmapData: data, bytesPerRow: rowBytes, size: CGSize(width: width, height: height),
                                format: .RGBAh, colorSpace: HDR.linearSpace)
            HDR.ci.render(frame, to: buffer, bounds: frame.extent, colorSpace: HDR.hlgSpace)
        } else {
            guard CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess else {
                throw ExportFailure(String(localized: "Couldn't allocate video memory."))
            }
            defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
            guard let context = CollageRenderer.makeContext(width: width, height: height, data: CVPixelBufferGetBaseAddress(buffer),
                                                           bytesPerRow: CVPixelBufferGetBytesPerRow(buffer)) else {
                throw ExportFailure(String(localized: "Couldn't allocate video memory."))
            }
            draw(context)
        }
    }
}

/// Ownership transfers to the video queue when the writer starts.
private final class VideoExportFrames: @unchecked Sendable {
    private enum Composer {
        case cpu(CPUVideoComposer)
        case gpu(GPUFrameComposer)
        case closed
    }

    private struct Closed: Error {}

    private var makeCPU: (() throws -> CPUVideoComposer)?
    private let makeFeeders: (Bool) -> [String: LaneFrameFeeder]
    private let hdr: Bool
    private var composer: Composer
    private var feeders: [String: LaneFrameFeeder]
    private var preparedFrame: CVPixelBuffer?
    #if DEBUG
    /// `1` fails every GPU frame (the first-frame fallback catches it); `late` fails from half a second in, after the
    /// writer has started, which makes the whole export start again on the CPU.
    private let forceGPUFailure = ProcessInfo.processInfo.environment["CM_EXPORT_FORCE_GPU_FAILURE"]
    private var referenceFeeders: [String: LaneFrameFeeder] = [:]
    private(set) var comparedTimestamps = 0
    #endif

    /// The engine drawing the frames; it stays readable after `close()`.
    private(set) var engine: ExportEngine

    /// Drops the composer and closes the video readers, so a stopped export frees its memory even when the encoder
    /// never calls back again. Call it on the video queue, so it can't run in the middle of a frame.
    func close() {
        composer = .closed
        feeders.removeAll()
        preparedFrame = nil
        makeCPU = nil
        #if DEBUG
        referenceFeeders.removeAll()
        #endif
    }

    init(engine: ExportEngine, snapshot: ExportSnapshot, photos: [String: CGImage], captions: CaptionLayers,
         width: Int, height: Int, hdr: Bool, makeFeeders: @escaping (Bool) -> [String: LaneFrameFeeder]) throws {
        self.makeFeeders = makeFeeders
        self.hdr = hdr
        let makeCPU = {
            try CPUVideoComposer(snapshot: snapshot, photos: photos, captions: captions, width: width, height: height, hdr: hdr)
        }
        if engine == .gpu {
            do {
                composer = .gpu(try GPUFrameComposer(snapshot: snapshot, photos: photos, captions: captions,
                                                     width: width, height: height, hdr: hdr))
                feeders = makeFeeders(true)
                self.makeCPU = makeCPU
                self.engine = .gpu
                #if DEBUG
                if ProcessInfo.processInfo.environment["CM_EXPORT_VERIFY_TIMESTAMPS"] == "1" {
                    referenceFeeders = makeFeeders(false)
                }
                #endif
                return
            } catch {
                Self.logFallback(error)
            }
        }
        composer = .cpu(try makeCPU())
        feeders = makeFeeders(false)
        self.engine = .cpu
    }

    /// Validate a planar GPU frame before creating the writer pool so fallback can keep the RGB CPU path.
    func prepareFirstFrame(in buffer: CVPixelBuffer) throws {
        do {
            try render(at: 0, to: buffer, firstFrame: false)
            preparedFrame = buffer
            makeCPU = nil
        } catch {
            try fallBackToCPU(error)
        }
    }

    func takePreparedFrame() -> CVPixelBuffer? {
        defer { preparedFrame = nil }
        return preparedFrame
    }

    func fallBackToCPU(_ error: Error) throws {
        guard let makeCPU else { throw error }
        Self.logFallback(error)
        composer = .cpu(try makeCPU())
        feeders = makeFeeders(false)
        engine = .cpu
        self.makeCPU = nil
        #if DEBUG
        referenceFeeders.removeAll()
        #endif
    }

    func render(at time: Double, to buffer: CVPixelBuffer, firstFrame: Bool) throws {
        switch composer {
        case .gpu(let gpu):
            do {
                #if DEBUG
                if forceGPUFailure == "1" || (forceGPUFailure == "late" && time >= 0.5) {
                    throw GPUFrameComposer.SetupError.simulatedFailure
                }
                #endif
                try gpu.render(at: time, to: buffer) { id in
                    guard let feeder = self.feeders[id] else { return nil }
                    let pixelBuffer = feeder.pixelBuffer(at: time)
                    #if DEBUG
                    if let reference = self.referenceFeeders[id] {
                        _ = reference.frame(at: time)
                        precondition(reference.selectedTimestamp == feeder.selectedTimestamp,
                                     "CPU and GPU selected different video timestamps at \(time)")
                        self.comparedTimestamps += 1
                    }
                    #endif
                    if let pixelBuffer { return CIImage(cvPixelBuffer: pixelBuffer) }
                    return feeder.heldImage.map { CIImage(cgImage: $0) }
                }
                if firstFrame { makeCPU = nil }
            } catch {
                guard firstFrame else { throw error }
                try fallBackToCPU(error)
                try render(at: time, to: buffer, firstFrame: false)
            }
        case .cpu(let cpu):
            try cpu.render(at: time, to: buffer, feeders: feeders)
        case .closed:
            throw Closed()
        }
        if hdr {
            CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_2020, .shouldPropagate)
            CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_2100_HLG, .shouldPropagate)
            CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_2020, .shouldPropagate)
        }
    }

    private static func logFallback(_ error: Error) {
        #if DEBUG
        NSLog("CM_EXPORT engine=cpu (fallback: %@)", String(describing: error))
        #endif
    }
}

/// The video queue uses these together until it marks the input finished.
private struct VideoEncoder: @unchecked Sendable {
    let writer: AVAssetWriter
    let input: AVAssetWriterInput
    let adaptor: AVAssetWriterInputPixelBufferAdaptor
}

/// Shared by the waiting export and its video and audio queues. Any reason to stop (Cancel, a cancelled task, a failed
/// frame or encoder) sets `shouldStop`, which both queues check before each sample.
private final class ExportQueueState: @unchecked Sendable {
    private let lock = NSLock()
    private var error: Error?
    private var stopped = false
    private var finished = false

    var failure: Error? { lock.withLock { error } }
    var shouldStop: Bool { lock.withLock { stopped || error != nil } }
    var isFinished: Bool { lock.withLock { finished } }
    func fail(_ error: Error) { lock.withLock { if self.error == nil { self.error = error } } }
    func stop() { lock.withLock { stopped = true } }
    func finish() { lock.withLock { finished = true } }
}

/// The GPU export failed after it had started writing. The whole export is made again with the CPU engine.
private struct GPUExportFailed: Error {
    let underlying: Error
}

enum ExportQuality: String, CaseIterable, Identifiable {
    case standard, ultra
    var id: String { rawValue }
    var scale: Double { self == .ultra ? 2 : 1 }
    /// Ultra is 2160 pixels wide: 4K (2160 × 3840) for a Story.
    var title: String { self == .ultra ? "4K" : "HD" }
}

struct ExportFailure: LocalizedError {
    let message: String
    init(_ m: String) { message = m }
    var errorDescription: String? { message }
}

/// Renders the collage to an MP4 (H.264 + AAC, 30 fps; or 10-bit HEVC HLG for HDR) or a PNG still.
final class CollageExporter: @unchecked Sendable {
    private let snapshot: ExportSnapshot
    private let total: Double
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

    /// Can this device encode this size (H.264, or 10-bit HEVC HLG for HDR)?
    static func canEncode(format: FormatId, quality: ExportQuality, hdr: Bool = false) -> Bool {
        let w = Int(format.width * quality.scale), h = Int(format.height * quality.scale)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("probe-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: tmp) }
        guard let writer = try? AVAssetWriter(url: tmp, fileType: .mp4) else { return false }
        return writer.canApply(outputSettings: videoSettings(w, h, hdr: hdr), forMediaType: .video)
    }

    private static func videoSettings(_ w: Int, _ h: Int, hdr: Bool = false, fps: Int = 30) -> [String: Any] {
        // more frames need more bits: about 1.5× at 60 fps
        let rateBoost = fps > 30 ? 1.5 : 1.0
        if hdr {
            // HDR: 10-bit HEVC tagged BT.2020 / HLG, the format iPhone records and Instagram and TikTok accept.
            let bitrate = Int(20_000_000.0 * rateBoost * Double(w * h) / (1080.0 * 1920.0))
            return [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: w,
                AVVideoHeightKey: h,
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
                ],
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: max(bitrate, 6_000_000),
                    AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel as String,
                    AVVideoExpectedSourceFrameRateKey: fps,
                    AVVideoMaxKeyFrameIntervalKey: fps * 2,
                ],
            ]
        }
        // about 16 Mbps at 1080×1920, scaled with the picture size
        let bitrate = Int(16_000_000.0 * rateBoost * Double(w * h) / (1080.0 * 1920.0))
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
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoMaxKeyFrameIntervalKey: fps * 2,
            ],
        ]
    }

    /// One frame reader per placed video. For HDR, frames are scaled to the biggest size a cell shows them at.
    private func makeFeeders(W: Double = 0, H: Double = 0, hdr: Bool = false, fps: Int = 30,
                             metalCompatible: Bool = false, planarSDR: Bool = false) -> [String: LaneFrameFeeder] {
        let project = snapshot.project
        // a motion design shows a video at many sizes: read it for the biggest
        let poses = hdr ? project.motionSamples() : []
        var out: [String: LaneFrameFeeder] = [:]
        for lane in placedLanes(project) {
            guard let item = snapshot.items[lane.mediaId] else { continue }
            var maxPx = 0
            for pose in poses {
                let rects = pose.cellRects(W: W, H: H)
                for (i, cell) in pose.cells.enumerated() where i < rects.count && cell.mediaId == lane.mediaId && pose.cellAlpha(i) > 0.001 {
                    let need = neededPhotoSize(srcW: item.width, srcH: item.height, cell: rects[i], view: cell.view)
                    maxPx = max(maxPx, need.w, need.h)
                }
            }
            out[lane.mediaId] = LaneFrameFeeder(lane: lane, url: item.url, hdr: hdr, maxPixels: maxPx, fps: fps,
                                                metalCompatible: metalCompatible, planarSDR: planarSDR)
        }
        return out
    }

    // MARK: PNG

    /// A still of the collage as it looks at timeline time `t`.
    func exportPNG(at t: Double, quality: ExportQuality) throws -> URL {
        let (w, h) = size(quality: quality)
        let photos = CollageRenderer.decodePhotos(snapshot: snapshot, W: Double(w), H: Double(h))
        let feeders = makeFeeders()
        guard let ctx = CollageRenderer.makeContext(width: w, height: h) else { throw ExportFailure(String(localized: "Couldn't create the picture.")) }
        CollageRenderer.draw(ctx: ctx, W: Double(w), H: Double(h), snapshot: snapshot, t: t) { id in
            photos[id] ?? feeders[id]?.frame(at: t)
        }
        guard let image = ctx.makeImage() else { throw ExportFailure(String(localized: "Couldn't create the picture.")) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Collage-\(Int(Date().timeIntervalSince1970)).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ExportFailure(String(localized: "Couldn't save the picture."))
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw ExportFailure(String(localized: "Couldn't save the picture.")) }
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
        guard let ctx = CollageRenderer.makeContext(width: w, height: h) else { throw ExportFailure(String(localized: "Couldn't create the pictures.")) }
        CollageRenderer.draw(ctx: ctx, W: Double(w), H: Double(h), snapshot: snapshot) { photos[$0] }
        guard let full = ctx.makeImage() else { throw ExportFailure(String(localized: "Couldn't create the pictures.")) }
        let stamp = Int(Date().timeIntervalSince1970)
        var urls: [URL] = []
        do {
            for i in 0..<slides {
                guard let slice = full.cropping(to: CGRect(x: i * slideW, y: 0, width: slideW, height: h)) else {
                    throw ExportFailure(String(localized: "Couldn't cut slide \(i + 1)."))
                }
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("Carousel-\(stamp)-\(i + 1).jpg")
                guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
                    throw ExportFailure(String(localized: "Couldn't save slide \(i + 1)."))
                }
                CGImageDestinationAddImage(dest, slice, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
                guard CGImageDestinationFinalize(dest) else { throw ExportFailure(String(localized: "Couldn't save slide \(i + 1).")) }
                urls.append(url)
            }
        } catch {
            for u in urls { try? FileManager.default.removeItem(at: u) }
            throw error
        }
        return urls
    }

    // MARK: MP4

    /// Writes the MP4 with the GPU engine (Debug builds can pick one with `CM_EXPORT_ENGINE`). If the GPU export fails
    /// once it has started writing, the whole video is made again with the CPU engine, so engines never mix in one file.
    func exportVideo(quality: ExportQuality, hdr: Bool = false, fps: Int = 30, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        do {
            return try await writeVideo(engine: .requested, quality: quality, hdr: hdr, fps: fps, progress: progress)
        } catch let failed as GPUExportFailed {
            if isCancelled || Task.isCancelled { throw CancellationError() }
            #if DEBUG
            NSLog("CM_EXPORT engine=cpu (retry after GPU failure: %@)", String(describing: failed.underlying))
            #endif
            progress(0)
            return try await writeVideo(engine: .cpu, quality: quality, hdr: hdr, fps: fps, progress: progress)
        }
    }

    private func writeVideo(engine: ExportEngine, quality: ExportQuality, hdr: Bool, fps requestedFPS: Int,
                            progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        #if DEBUG
        let measurement = ExportMeasurement()
        #endif
        let fps = requestedFPS == 60 ? 60 : 30
        let (w, h) = size(quality: quality)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Collage-\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(url: url, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true
        let vSettings = Self.videoSettings(w, h, hdr: hdr, fps: fps)
        guard writer.canApply(outputSettings: vSettings, forMediaType: .video) else {
            throw ExportFailure(hdr
                ? String(localized: "This iPhone can't encode \(w)×\(h) HDR video. Try Standard quality, or turn HDR off.")
                : String(localized: "This iPhone can't encode \(w)×\(h) video. Try Standard quality."))
        }
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: vSettings)
        vInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(vInput) else { throw ExportFailure(String(localized: "Couldn't set up the video encoder.")) }
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
            out.audioTimePitchAlgorithm = .spectral // sped-up or slowed clips keep their pitch
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

        let planarSDR: Bool
        #if DEBUG
        let planarOverride = ProcessInfo.processInfo.environment["CM_EXPORT_PLANAR_SDR"].map { $0 == "1" }
        planarSDR = !hdr && (planarOverride ?? (w * h > 4_000_000))
        #else
        planarSDR = !hdr && w * h > 4_000_000
        #endif
        let photos = CollageRenderer.decodePhotos(snapshot: snapshot, W: Double(w), H: Double(h))
        let captionLayers = CaptionRenderer.layers(project: snapshot.project, W: w, H: h)
        let frames = try VideoExportFrames(engine: engine, snapshot: snapshot, photos: photos, captions: captionLayers,
                                           width: w, height: h, hdr: hdr) { [self, planarSDR] metalCompatible in
            makeFeeders(W: Double(w), H: Double(h), hdr: hdr, fps: fps,
                        metalCompatible: metalCompatible, planarSDR: planarSDR)
        }
        var poolAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: hdr ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange : kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            kCVPixelBufferWidthKey as String: w,
            kCVPixelBufferHeightKey as String: h,
        ]
        if frames.engine == .gpu { poolAttributes[kCVPixelBufferMetalCompatibilityKey as String] = true }
        if planarSDR && frames.engine == .gpu {
            // There is no RGB-to-YUV conversion in the writer when the composer supplies encoder-ready buffers.
            let format = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            var planarAttributes = poolAttributes
            planarAttributes[kCVPixelBufferPixelFormatTypeKey as String] = format
            var first: CVPixelBuffer?
            let status = CVPixelBufferCreate(nil, w, h, format, planarAttributes as CFDictionary, &first)
            if status == kCVReturnSuccess, let first {
                try frames.prepareFirstFrame(in: first)
                if frames.engine == .gpu { poolAttributes = planarAttributes }
            } else {
                try frames.fallBackToCPU(GPUFrameComposer.SetupError.rasterAllocationFailed)
            }
            if frames.engine == .cpu { poolAttributes[kCVPixelBufferMetalCompatibilityKey as String] = nil }
        }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vInput, sourcePixelBufferAttributes: poolAttributes)
        let frameCount = max(1, Int((total * Double(fps)).rounded(.up)))

        guard writer.startWriting() else { throw ExportFailure(writer.error?.localizedDescription ?? String(localized: "Couldn't start the export.")) }
        writer.startSession(atSourceTime: .zero)
        if let aReader, !aReader.startReading() { throw ExportFailure(aReader.error?.localizedDescription ?? String(localized: "Couldn't read the sound.")) }

        let group = DispatchGroup()
        let videoQueue = DispatchQueue(label: "collagemagik.export.video")
        let audioQueue = DispatchQueue(label: "collagemagik.export.audio")
        let audioReader = aReader
        // However the export ends, drop the composer and close the readers. Queued, so it never runs mid-frame.
        defer {
            videoQueue.async { frames.close() }
            audioQueue.async { audioReader?.cancelReading() }
        }
        let encoder = VideoEncoder(writer: writer, input: vInput, adaptor: adaptor)
        var frameIndex = 0
        let queues = ExportQueueState()

        group.enter()
        vInput.requestMediaDataWhenReady(on: videoQueue) { [self] in
            while encoder.input.isReadyForMoreMediaData {
                if isCancelled || queues.shouldStop || frameIndex >= frameCount {
                    encoder.input.markAsFinished()
                    group.leave()
                    return
                }
                autoreleasepool {
                    let pb: CVPixelBuffer
                    if let preparedFrame = frames.takePreparedFrame() {
                        pb = preparedFrame
                    } else {
                        guard let pool = encoder.adaptor.pixelBufferPool else {
                            queues.fail(ExportFailure(String(localized: "Couldn't allocate video memory.")))
                            return
                        }
                        var pbOut: CVPixelBuffer?
                        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOut)
                        guard let created = pbOut else {
                            queues.fail(ExportFailure(String(localized: "Couldn't allocate video memory.")))
                            return
                        }
                        pb = created
                        let time = Double(frameIndex) / Double(fps)
                        do {
                            try frames.render(at: time, to: pb, firstFrame: frameIndex == 0)
                        } catch {
                            queues.fail(error)
                            return
                        }
                    }
                    if !encoder.adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps))) {
                        queues.fail(encoder.writer.error ?? ExportFailure(String(localized: "The video encoder stopped.")))
                        return
                    }
                    frameIndex += 1
                    #if DEBUG
                    if frameIndex.isMultiple(of: 30) { measurement.sample() }
                    #endif
                    progress(min(1, Double(frameIndex) / Double(frameCount)) * 0.97)
                }
            }
        }

        if let aInput, let aOutput {
            group.enter()
            aInput.requestMediaDataWhenReady(on: audioQueue) { [self] in
                while aInput.isReadyForMoreMediaData {
                    if isCancelled || queues.shouldStop { aInput.markAsFinished(); group.leave(); return }
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

        // Writer failures can stop readiness callbacks altogether. Check its state while waiting so a failed
        // encoder or cancelled job cannot leave the export waiting for a callback that will never arrive.
        group.notify(queue: .global()) { queues.finish() }
        while !queues.isFinished {
            if isCancelled || Task.isCancelled || queues.failure != nil ||
                writer.status == .failed || writer.status == .cancelled {
                queues.stop()
                break
            }
            await Self.pause(milliseconds: 25)
        }
        // Stopping early: let both queues finish the sample they're on and mark their inputs finished, so the writer
        // is never cancelled under an append. A failed writer may never call them again, so wait two seconds at most.
        let deadline = CACurrentMediaTime() + 2
        while !queues.isFinished && CACurrentMediaTime() < deadline {
            await Self.pause(milliseconds: 25)
        }

        // A GPU export that fails after writing started is made again with the CPU engine (see `exportVideo`).
        func failed(_ error: Error) -> Error {
            frames.engine == .gpu ? GPUExportFailed(underlying: error) : error
        }
        if isCancelled || Task.isCancelled {
            if writer.status == .writing { writer.cancelWriting() }
            try? FileManager.default.removeItem(at: url)
            throw CancellationError()
        }
        if let error = queues.failure ?? writer.error {
            if writer.status == .writing { writer.cancelWriting() }
            try? FileManager.default.removeItem(at: url)
            throw failed(error)
        }
        guard writer.status == .writing else {
            try? FileManager.default.removeItem(at: url)
            throw failed(ExportFailure(String(localized: "The export didn't finish.")))
        }
        await writer.finishWriting()
        guard writer.status == .completed else {
            try? FileManager.default.removeItem(at: url)
            throw failed(ExportFailure(writer.error?.localizedDescription ?? String(localized: "The export didn't finish.")))
        }
        #if DEBUG
        measurement.finish(engine: frames.engine.rawValue, width: w, height: h, fps: fps, frames: frameIndex)
        if frames.comparedTimestamps > 0 {
            NSLog("CM_EXPORT verified %d matching CPU/GPU timestamps", frames.comparedTimestamps)
        }
        #endif
        progress(1)
        return url
    }

    /// Waits without throwing: `Task.sleep` returns at once in a cancelled task, which would turn the waits above
    /// into a busy loop.
    private static func pause(milliseconds: Int) async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(milliseconds)) { c.resume() }
        }
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
                    // the source plays `speed` times faster: take dur × speed of it and squeeze (or stretch) it to dur
                    let sourceDur = CMTime(seconds: dur * clip.speed, preferredTimescale: 60000)
                    let atTime = CMTime(seconds: at, preferredTimescale: 60000)
                    do {
                        try track.insertTimeRange(
                            CMTimeRange(start: CMTime(seconds: clip.inPoint, preferredTimescale: 60000), duration: sourceDur),
                            of: src, at: atTime
                        )
                        if clip.speed != 1 {
                            track.scaleTimeRange(CMTimeRange(start: atTime, duration: sourceDur), toDuration: CMTime(seconds: dur, preferredTimescale: 60000))
                        }
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
    var errorDescription: String? { String(localized: "Collage Magic needs permission to add pictures to your Photos. You can allow it in Settings.") }
}

/// Saves to Photos with add-only access: the app can add a collage but never read or change what is already there.
/// iOS shows its permission prompt the first time this runs, which is when the person taps Save to Photos.
enum PhotoSaver {
    /// Saves a carousel's slides in one go, each with its own creation date so their order is fixed rather than left to
    /// Photos to break a tie. Slide 1 is the newest: Instagram's picker lists newest first, so the slides sit at its
    /// top-left as 1, 2, 3… and people tap them in posting order. (The Photos app lists newest last, so there they read
    /// backwards at the bottom.)
    static func saveAll(urls: [URL]) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw PhotosAccessDenied() }
        let now = Date()
        try await PHPhotoLibrary.shared().performChanges {
            for (i, url) in urls.enumerated() {
                let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                request?.creationDate = now.addingTimeInterval(-Double(i))
            }
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
