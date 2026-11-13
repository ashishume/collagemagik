import AVFoundation
import CoreGraphics
import ImageIO
import UIKit
import VideoToolbox

/// Everything the export needs, copied out of the store so it can run off the main thread.
struct ExportSnapshot {
    var project: Project
    var items: [String: MediaItem]
}

/// Draws the whole collage into a Core Graphics context. Mirrors the live preview, so what you see is what you get.
enum CollageRenderer {
    static func draw(
        ctx: CGContext, W: Double, H: Double, snapshot: ExportSnapshot,
        captionLayer: CGImage? = nil,
        image: (String) -> CGImage?
    ) {
        let project = snapshot.project
        ctx.saveGState()
        ctx.interpolationQuality = .high
        ctx.setFillColor(UIColor(hex: project.bg).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

        let rects = project.cellRects(W: W, H: H)
        let outers = project.frameRects(W: W, H: H)
        let unit = W / project.canvasWidth
        for (i, r) in rects.enumerated() {
            guard i < project.cells.count else { break }
            let cell = project.cells[i]
            let framed = project.isFramed(i)
            drawPrint(
                ctx, outer: outers[i], picture: r, radius: project.pictureRadius(i, W: W),
                frame: framed ? project.frame : .none, frameColor: project.frameColor,
                edge: project.frameEdges(i, outers[i], W: W).side, seed: i, unit: unit
            ) {
                if let id = cell.mediaId, let item = snapshot.items[id], let img = image(id) {
                    drawMedia(ctx, img, item: item, rect: r, view: cell.view)
                }
            }
        }
        // Photos laid on top of the layout, in order.
        for (k, o) in project.overlays.enumerated() {
            guard let item = snapshot.items[o.mediaId], let img = image(o.mediaId) else { continue }
            let g = project.overlayGeometry(o, aspect: item.height / item.width, W: W, H: H)
            drawPrint(
                ctx, outer: g.outer, picture: g.picture, radius: o.frame == .torn ? 0 : 3 * unit,
                frame: o.frame, frameColor: o.frameColor, edge: g.edge, seed: 1000 + k, unit: unit
            ) {
                drawMedia(ctx, img, item: item, rect: g.picture, view: MediaView())
            }
        }
        // Captions go on top. A video hands in a ready-made layer so the words aren't laid out again for every frame.
        if let captionLayer {
            ctx.saveGState()
            ctx.translateBy(x: 0, y: H)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(captionLayer, in: CGRect(x: 0, y: 0, width: W, height: H))
            ctx.restoreGState()
        } else {
            CaptionRenderer.drawAll(ctx: ctx, project: project, W: W, H: H)
        }
        ctx.restoreGState()
    }

    /// One photo with its frame and drop shadow, turned by `outer.tilt` about its centre. `content` draws the picture,
    /// clipped to `picture` (canvas coordinates, before the turn).
    static func drawPrint(
        _ ctx: CGContext, outer: PxRect, picture: PxRect, radius: Double,
        frame: PhotoFrame, frameColor: String, edge: Double, seed: Int, unit: Double,
        content: () -> Void
    ) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        if outer.tilt != 0 {
            let c = outer.center
            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: outer.tilt * RAD)
            ctx.translateBy(x: -c.x, y: -c.y)
        }
        let rr = max(0, min(radius, picture.w / 2, picture.h / 2))
        let path = CGPath(roundedRect: picture.cgRect, cornerWidth: rr, cornerHeight: rr, transform: nil)
        if frame != .none {
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: 7 * unit), blur: 22 * unit, color: UIColor.black.withAlphaComponent(0.38).cgColor)
            if frame.hasEdge {
                let shape = frameOutline(frame, size: CGSize(width: outer.w, height: outer.h), radius: 3 * unit, edge: edge, seed: seed)
                var move = CGAffineTransform(translationX: outer.x, y: outer.y)
                if let placed = shape.copy(using: &move) { ctx.addPath(placed) }
                ctx.setFillColor(UIColor(hex: frameColor).cgColor)
            } else {
                ctx.addPath(path)
                ctx.setFillColor(UIColor.black.cgColor)
            }
            ctx.fillPath()
            ctx.restoreGState()
        }
        ctx.addPath(path)
        ctx.clip()
        content()
    }

    /// The context must have a top-left origin (flipped). The picture is drawn with zoom, pan, rotation, flip and straighten.
    static func drawMedia(_ ctx: CGContext, _ img: CGImage, item: MediaItem, rect: PxRect, view: MediaView) {
        let p = placeMedia(srcW: item.width, srcH: item.height, cell: rect, view: view)
        let w = item.width * p.scale
        let h = item.height * p.scale
        ctx.saveGState()
        ctx.translateBy(x: p.cx, y: p.cy)
        ctx.rotate(by: p.angleRad)
        if p.flip { ctx.scaleBy(x: -1, y: 1) }
        ctx.rotate(by: p.rotationRad)
        ctx.scaleBy(x: 1, y: -1) // images are drawn upright in a flipped context
        ctx.draw(img, in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        ctx.restoreGState()
    }

    /// Photos decoded straight to the size each cell needs (never upscaled).
    static func decodePhotos(snapshot: ExportSnapshot, W: Double, H: Double) -> [String: CGImage] {
        let project = snapshot.project
        let rects = project.cellRects(W: W, H: H)
        var out: [String: CGImage] = [:]
        for (i, cell) in project.cells.enumerated() where i < rects.count {
            guard let id = cell.mediaId, let item = snapshot.items[id], item.kind == .photo else { continue }
            let need = neededPhotoSize(srcW: item.width, srcH: item.height, cell: rects[i], view: cell.view)
            let maxPx = max(need.w, need.h)
            if let existing = out[id], max(existing.width, existing.height) >= maxPx { continue }
            guard let src = CGImageSourceCreateWithURL(item.url as CFURL, nil) else { continue }
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPx,
            ]
            if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) { out[id] = cg }
        }
        // photos on top: the same photo may also be in a cell, so keep whichever copy is bigger
        for o in project.overlays {
            guard let item = snapshot.items[o.mediaId], item.kind == .photo else { continue }
            let g = project.overlayGeometry(o, aspect: item.height / item.width, W: W, H: H)
            let need = neededPhotoSize(srcW: item.width, srcH: item.height, cell: g.picture, view: MediaView())
            let maxPx = max(need.w, need.h)
            if let existing = out[o.mediaId], max(existing.width, existing.height) >= maxPx { continue }
            guard let src = CGImageSourceCreateWithURL(item.url as CFURL, nil) else { continue }
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPx,
            ]
            if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) { out[o.mediaId] = cg }
        }
        return out
    }

    static func makeContext(width: Int, height: Int, data: UnsafeMutableRawPointer? = nil, bytesPerRow: Int = 0) -> CGContext? {
        let ctx = CGContext(
            data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        ctx?.translateBy(x: 0, y: CGFloat(height))
        ctx?.scaleBy(x: 1, y: -1)
        return ctx
    }
}

/// Reads frames of one video lane in order, as the export walks along the timeline.
/// Works for every format AVFoundation can decode: H.264, HEVC (including HDR / Dolby Vision, converted to SDR),
/// any rotation or mirroring, and variable frame rates.
final class LaneFrameFeeder {
    let lane: Lane
    private let asset: AVURLAsset
    private let generator: AVAssetImageGenerator
    private var reader: AVAssetReader?
    private var output: AVAssetReaderVideoCompositionOutput?
    private var clipId = ""
    private var lastSourceTime = -1.0
    private var current: CGImage?
    private var pending: (image: CGImage, pts: Double)?
    private var holdCache: [Int: CGImage] = [:]
    private let halfFrame = 1.0 / 60.0

    init(lane: Lane, url: URL) {
        self.lane = lane
        asset = AVURLAsset(url: url)
        generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
    }

    func frame(at t: Double) -> CGImage? {
        guard let r = resolveLane(lane, t) else { return nil }
        guard r.active else { return hold(at: r.time) }
        let needsRestart = reader == nil || r.clip.id != clipId || r.time < lastSourceTime - 0.001 || r.time > lastSourceTime + 0.75
        if needsRestart { startReader(clip: r.clip, from: r.time) }
        lastSourceTime = r.time
        while true {
            if pending == nil { pending = readNext() }
            guard let next = pending else { break }
            if next.pts <= r.time + halfFrame {
                current = next.image
                pending = nil
            } else {
                break
            }
        }
        return current ?? pending?.image ?? hold(at: r.time)
    }

    private func startReader(clip: Clip, from time: Double) {
        reader?.cancelReading()
        reader = nil
        output = nil
        current = nil
        pending = nil
        clipId = clip.id
        guard let track = asset.tracks(withMediaType: .video).first else { return }
        let comp = AVMutableVideoComposition(propertiesOf: asset)
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            // Convert HDR (HLG / Dolby Vision / HDR10) iPhone clips to ordinary SDR colour.
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]
        guard let r = try? AVAssetReader(asset: asset) else { return }
        let out = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: settings)
        out.videoComposition = comp
        out.alwaysCopiesSampleData = false
        guard r.canAdd(out) else {
            // Colour conversion not available for this clip: read it plainly.
            let plain = AVAssetReaderVideoCompositionOutput(
                videoTracks: [track], videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            )
            plain.videoComposition = comp
            if r.canAdd(plain) { r.add(plain); output = plain }
            r.timeRange = CMTimeRange(start: CMTime(seconds: time, preferredTimescale: 600), end: CMTime(seconds: clip.outPoint, preferredTimescale: 600))
            r.startReading()
            reader = r
            return
        }
        r.add(out)
        r.timeRange = CMTimeRange(start: CMTime(seconds: time, preferredTimescale: 600), end: CMTime(seconds: clip.outPoint, preferredTimescale: 600))
        guard r.startReading() else { return }
        reader = r
        output = out
    }

    private func readNext() -> (CGImage, Double)? {
        guard let output, let sb = output.copyNextSampleBuffer(), let pb = CMSampleBufferGetImageBuffer(sb) else { return nil }
        var cg: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pb, options: nil, imageOut: &cg)
        guard let img = cg else { return nil }
        return (img, CMSampleBufferGetPresentationTimeStamp(sb).seconds)
    }

    /// The frame to show while a lane is waiting to start or has finished (the first / last frame held).
    func hold(at time: Double) -> CGImage? {
        let key = Int((time * 1000).rounded())
        if let c = holdCache[key] { return c }
        let cg = try? generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil)
        if let cg { holdCache[key] = cg }
        return cg
    }
}
