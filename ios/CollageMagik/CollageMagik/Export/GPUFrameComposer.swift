import CoreImage
import Metal
import UIKit

/// Confined to the export's video queue after setup. The cache handles memory warnings separately.
final class GPUFrameComposer: @unchecked Sendable {
    enum SetupError: Error {
        case metalUnavailable, rasterAllocationFailed, simulatedFailure
    }

    private let context: CIContext
    private let outputSpace: CGColorSpace
    private let bounds: CGRect
    private let hdr: Bool
    private let project: Project
    private let items: [String: MediaItem]
    private let backdrop: CIImage
    private let foreground: [CIImage]
    private let sceneCaptions: [(Int, CIImage)]
    private let photos: [Int: CIImage]
    private let pieces = PrintPieceCache()

    init(snapshot: ExportSnapshot, photos: [String: CGImage], captions: CaptionLayers, width: Int, height: Int, hdr: Bool) throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw SetupError.metalUnavailable }
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        context = CIContext(mtlDevice: device, options: [
            .workingColorSpace: hdr ? HDR.linearSpace : sRGB,
            .workingFormat: hdr ? CIFormat.RGBAh : CIFormat.RGBA8,
            .cacheIntermediates: false,
        ])
        outputSpace = hdr ? HDR.hlgSpace : sRGB
        self.hdr = hdr
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        bounds = canvas
        let project = snapshot.project
        self.project = project
        items = snapshot.items
        let W = Double(width), H = Double(height), unit = W / project.canvasWidth
        backdrop = try Self.raster(canvas, height: H, hdr: hdr) { ctx in
            BackdropRenderer.draw(ctx: ctx, W: W, H: H, project: project) { id in
                snapshot.items[id].map { $0.preview ?? $0.thumbnail }
            }
        }

        var layers: [CIImage] = []
        for (index, overlay) in project.overlays.enumerated() {
            guard let item = snapshot.items[overlay.mediaId], let image = photos[overlay.mediaId] else { continue }
            let g = project.overlayGeometry(overlay, item: item, W: W, H: H)
            let center = g.outer.center
            let tilt = CGAffineTransform(translationX: -center.x, y: -center.y)
                .concatenating(CGAffineTransform(rotationAngle: g.outer.tilt * RAD))
                .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
            let pad = Self.printPadding(g.outer, frame: overlay.frame, unit: unit)
            let box = g.outer.cgRect.insetBy(dx: -pad, dy: -pad)
                .applying(tilt).integral.intersection(canvas)
            guard !box.isEmpty else { continue }
            layers.append(try Self.raster(box, height: H, hdr: hdr) { ctx in
                CollageRenderer.drawPrint(
                    ctx, outer: g.outer, picture: g.picture, radius: overlay.frame.printRadius(unit: unit),
                    frame: overlay.frame, frameColor: overlay.frameColor, edge: g.edge, seed: 1000 + index, unit: unit
                ) {
                    CollageRenderer.drawMedia(ctx, image, item: item, rect: g.picture, view: overlay.view)
                }
            })
        }
        if !project.stickers.isEmpty {
            layers.append(try Self.raster(canvas, height: H, hdr: hdr) {
                StickerRenderer.drawAll(ctx: $0, project: project, W: W, H: H)
            })
        }
        if let always = captions.always { layers.append(CIImage(cgImage: always)) }
        foreground = layers
        sceneCaptions = captions.scenes.sorted { $0.key < $1.key }
            .map { ($0.key, CIImage(cgImage: $0.value)) }

        var cellPhotos: [Int: CIImage] = [:]
        for (index, cell) in project.cells.prefix(project.cellCount).enumerated() {
            guard let id = cell.mediaId, let photo = photos[id] else { continue }
            cellPhotos[index] = CIImage(cgImage: PhotoLookRenderer.render(photo, cell.look) ?? photo)
        }
        self.photos = cellPhotos
    }

    func render(at time: Double, to output: CVPixelBuffer, video: (String) -> CIImage?) throws {
        let pose = project.posed(at: time)
        let W = bounds.width, H = bounds.height
        let unit = W / pose.canvasWidth
        let outers = pose.frameRects(W: W, H: H)
        var canvas = backdrop
        for i in pose.cellDrawOrder where i < outers.count && i < pose.cells.count {
            let alpha = pose.cellAlpha(i)
            guard alpha > 0.001 else { continue }
            let cell = pose.cells[i]
            let item = cell.mediaId.flatMap { items[$0] }
            let media = photos[i] ?? cell.mediaId.flatMap(video)
            let outer = outers[i]
            let edges = pose.frameEdges(i, outer, W: W)
            let picture = outer.inset(left: edges.side, top: edges.top, right: edges.side, bottom: edges.bottom)
            let frame = pose.frame(of: i)
            let pieces = try printPieces(
                index: i, outer: outer, picture: picture, radius: pose.pictureRadius(i, W: W),
                frame: frame, color: pose.frameColor, edge: edges.side, unit: unit,
                cell: cell, fitItem: media != nil && cell.fit ? item : nil
            )
            var print = pieces.under
            if let item, let media {
                let placed = Self.place(media, item: item, picture: picture, view: cell.view, height: H)
                    .cropped(to: Self.bottomLeft(picture.cgRect, height: H).integral)
                let clipped: CIImage
                if let mask = pieces.mask {
                    let clear = CIImage.empty().cropped(to: mask.extent)
                    clipped = placed.applyingFilter("CIBlendWithAlphaMask", parameters: [
                        kCIInputBackgroundImageKey: clear,
                        kCIInputMaskImageKey: mask,
                    ]).cropped(to: mask.extent)
                } else {
                    clipped = placed
                }
                print = print.map { clipped.composited(over: $0) } ?? clipped
            }
            if let top = pieces.over { print = print.map { top.composited(over: $0) } ?? top }
            guard var print else { continue }
            if outer.tilt != 0 {
                let x = outer.center.x, y = H - outer.center.y
                let rotation = CGAffineTransform(translationX: -x, y: -y)
                    .concatenating(CGAffineTransform(rotationAngle: -outer.tilt * RAD))
                    .concatenating(CGAffineTransform(translationX: x, y: y))
                print = print.transformed(by: rotation)
            }
            if alpha < 0.999 { print = Self.opacity(print, alpha) }
            canvas = print.composited(over: canvas)
        }
        for layer in foreground { canvas = layer.composited(over: canvas) }
        for (scene, layer) in sceneCaptions {
            let alpha = pose.captions.first { $0.scene == scene }.map(pose.captionAlpha) ?? 0
            if alpha > 0.001 { canvas = Self.opacity(layer, alpha).composited(over: canvas) }
        }
        let destination = CIRenderDestination(pixelBuffer: output)
        destination.colorSpace = outputSpace
        let task = try context.startTask(toRender: canvas, from: bounds, to: destination, at: .zero)
        _ = try task.waitUntilCompleted()
    }

    private func printPieces(
        index: Int, outer: PxRect, picture: PxRect, radius: Double, frame: PhotoFrame,
        color: String, edge: Double, unit: Double, cell: CellState, fitItem: MediaItem?
    ) throws -> PrintPieces {
        let H = bounds.height
        let pad = Self.printPadding(outer, frame: frame, unit: unit)
        let box = outer.cgRect.insetBy(dx: -pad, dy: -pad).integral
        let key = PrintPieceCache.Key(
            index: index, frame: frame, color: color, fitBars: fitItem == nil ? nil : cell.fitBars,
            blurMedia: cell.fitBars == fitBlur ? fitItem?.id : nil,
            geometry: [box.width, box.height, outer.x - box.minX, outer.y - box.minY, outer.w, outer.h,
                       picture.x - box.minX, picture.y - box.minY, picture.w, picture.h, radius, edge]
                .map { Int(($0 * 2).rounded()) }
        )
        let origin = Self.bottomLeft(box, height: H).origin
        if let cached = pieces.value(for: key) { return cached.shifted(to: origin) }
        let path = pictureClipPath(frame, rect: picture.cgRect, radius: radius)
        var result = PrintPieces()
        if frame != .none || fitItem != nil {
            result.under = try Self.raster(box, height: H, hdr: hdr) { ctx in
                CollageRenderer.drawPrintUnder(ctx, outer: outer, picture: picture, path: path, frame: frame,
                                               frameColor: color, edge: edge, seed: index, unit: unit)
                if let fitItem {
                    ctx.addPath(path)
                    ctx.clip()
                    BackdropRenderer.drawFitBars(ctx: ctx, rect: picture, cell: cell, item: fitItem)
                }
            }
        }
        switch frame {
        case .tape, .gallery, .date, .neon:
            result.over = try Self.raster(box, height: H, hdr: hdr) { ctx in
                FrameDecor.drawOver(ctx, frame: frame, outer: outer.cgRect, picture: picture.cgRect,
                                    color: color, unit: unit, seed: index)
            }
        default:
            break
        }
        if radius > 0 || frame.isShape || picture.cgRect != picture.cgRect.integral {
            result.mask = try Self.raster(picture.cgRect.integral, height: H, hdr: false) { ctx in
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.addPath(path)
                ctx.fillPath()
            }
        }
        pieces.insert(result.shifted(to: CGPoint(x: -origin.x, y: -origin.y)), for: key, hdr: hdr)
        return result
    }

    private static func printPadding(_ outer: PxRect, frame: PhotoFrame, unit: Double) -> Double {
        if frame == .none { return 0 }
        return frame == .tape ? max(64 * unit, outer.w * 0.18) : 64 * unit
    }

    /// Single conversion from top-left drawing coordinates to Core Image's bottom-left origin.
    private static func bottomLeft(_ rect: CGRect, height: Double) -> CGRect {
        CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func raster(_ box: CGRect, height: Double, hdr: Bool, draw: (CGContext) -> Void) throws -> CIImage {
        guard let ctx = CollageRenderer.makeContext(width: Int(box.width), height: Int(box.height), hdr: hdr) else {
            throw SetupError.rasterAllocationFailed
        }
        ctx.interpolationQuality = .high
        ctx.translateBy(x: -box.minX, y: -box.minY)
        draw(ctx)
        guard let image = ctx.makeImage() else { throw SetupError.rasterAllocationFailed }
        let origin = bottomLeft(box, height: height).origin
        return CIImage(cgImage: image).transformed(by: CGAffineTransform(translationX: origin.x, y: origin.y))
    }

    private static func place(_ image: CIImage, item: MediaItem, picture: PxRect, view: MediaView, height: Double) -> CIImage {
        let p = placeMedia(srcW: item.width, srcH: item.height, cell: picture, view: view)
        let source = image.extent
        let transform = CGAffineTransform(translationX: -source.midX, y: -source.midY)
            .concatenating(CGAffineTransform(scaleX: item.width * p.scale / source.width, y: item.height * p.scale / source.height))
            .concatenating(CGAffineTransform(rotationAngle: -p.rotationRad))
            .concatenating(CGAffineTransform(scaleX: p.flip ? -1 : 1, y: 1))
            .concatenating(CGAffineTransform(rotationAngle: -p.angleRad))
            .concatenating(CGAffineTransform(translationX: p.cx, y: height - p.cy))
        return image.transformed(by: transform)
    }

    private static func opacity(_ image: CIImage, _ alpha: Double) -> CIImage {
        image.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha)])
    }
}

private struct PrintPieces {
    var under: CIImage?
    var mask: CIImage?
    var over: CIImage?

    func shifted(to origin: CGPoint) -> PrintPieces {
        let shift = CGAffineTransform(translationX: origin.x, y: origin.y)
        return PrintPieces(under: under?.transformed(by: shift), mask: mask?.transformed(by: shift), over: over?.transformed(by: shift))
    }

    func bytes(hdr: Bool) -> Int {
        func bytes(_ image: CIImage?, pixel: Int) -> Int {
            guard let image else { return 0 }
            return Int(image.extent.width * image.extent.height) * pixel
        }
        return bytes(under, pixel: hdr ? 8 : 4) + bytes(mask, pixel: 4) + bytes(over, pixel: hdr ? 8 : 4)
    }
}

private final class PrintPieceCache: @unchecked Sendable {
    struct Key: Hashable {
        let index: Int
        let frame: PhotoFrame
        let color: String
        let fitBars: String?
        let blurMedia: String?
        // Local geometry rounded to half a pixel. Pan, zoom, alpha and tilt do not change the pieces.
        let geometry: [Int]
    }

    private struct Entry {
        let pieces: PrintPieces
        let bytes: Int
        var accessed: Int
    }

    private let lock = NSLock()
    private var entries: [Key: Entry] = [:]
    private var bytes = 0
    private var tick = 0
    private let byteLimit = 96 * 1024 * 1024
    private var warning: NSObjectProtocol?

    init() {
        warning = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
                                                          object: nil, queue: nil) { [weak self] _ in self?.clear() }
    }

    deinit {
        if let warning { NotificationCenter.default.removeObserver(warning) }
    }

    func value(for key: Key) -> PrintPieces? {
        lock.lock()
        defer { lock.unlock() }
        guard var entry = entries[key] else { return nil }
        tick += 1
        entry.accessed = tick
        entries[key] = entry
        return entry.pieces
    }

    func insert(_ pieces: PrintPieces, for key: Key, hdr: Bool) {
        let cost = pieces.bytes(hdr: hdr)
        guard cost <= byteLimit else { return }
        lock.lock()
        defer { lock.unlock() }
        if let replaced = entries.removeValue(forKey: key) { bytes -= replaced.bytes }
        while entries.count >= 64 || bytes + cost > byteLimit {
            guard let (oldest, entry) = entries.min(by: { $0.value.accessed < $1.value.accessed }) else { break }
            entries.removeValue(forKey: oldest)
            bytes -= entry.bytes
        }
        tick += 1
        entries[key] = Entry(pieces: pieces, bytes: cost, accessed: tick)
        bytes += cost
    }

    private func clear() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
        bytes = 0
    }
}
