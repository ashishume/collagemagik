import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// What fills the design behind the pictures: a plain colour (`Project.bg`), a gradient, a blurred copy of one of the
/// person's own pictures, or a pattern drawn over the colour.
enum BackdropKind: String, CaseIterable, Identifiable, Codable {
    case color, gradient, blur, pattern
    var id: String { rawValue }
    var title: String {
        switch self {
        case .color: "Colour"
        case .gradient: "Gradient"
        case .blur: "Blur"
        case .pattern: "Pattern"
        }
    }
}

struct Backdrop: Hashable, Codable {
    var kind: BackdropKind = .color
    /// Index into `gradientPresets`.
    var gradient: Int = 0
    /// The picture blurred behind the design (blur), or nil for the first picture in the layout.
    var blurMediaId: String? = nil
    /// Index into `BackdropPattern.allCases`.
    var pattern: Int = 0
}

struct GradientPreset {
    let name: String
    let colors: [String]
    /// Direction, in degrees (0 = left to right, 90 = top to bottom). nil = radial from the centre.
    let angle: Double?
}

let gradientPresets: [GradientPreset] = [
    GradientPreset(name: "Magik", colors: ["#8b6cff", "#c94bd8", "#ff7f8c"], angle: 135),
    GradientPreset(name: "Sunset", colors: ["#ff9a5a", "#ff5f8f", "#7b4dff"], angle: 160),
    GradientPreset(name: "Peach", colors: ["#ffe1c6", "#ffc0cb"], angle: 120),
    GradientPreset(name: "Ocean", colors: ["#2fd3ff", "#3a6bff", "#1b1f6b"], angle: 150),
    GradientPreset(name: "Mint", colors: ["#d8fff0", "#7fe0c2"], angle: 110),
    GradientPreset(name: "Night", colors: ["#2b1055", "#7597de"], angle: 90),
    GradientPreset(name: "Lemon", colors: ["#fff6b7", "#f6c445"], angle: 135),
    GradientPreset(name: "Berry", colors: ["#5b0e2d", "#c2185b", "#ff8a80"], angle: 60),
    GradientPreset(name: "Glow", colors: ["#fff1fb", "#e2b8ff", "#6c4dff"], angle: nil),
    GradientPreset(name: "Mono", colors: ["#f2f2f2", "#9e9e9e"], angle: 90),
    GradientPreset(name: "Forest", colors: ["#0f3d2e", "#5fb37a"], angle: 135),
    GradientPreset(name: "Spotlight", colors: ["#3a3a46", "#0b0b10"], angle: nil),
]

enum BackdropPattern: Int, CaseIterable, Identifiable {
    case dots, grid, stripes, checks, confetti, hearts
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .dots: "Dots"
        case .grid: "Grid"
        case .stripes: "Stripes"
        case .checks: "Checks"
        case .confetti: "Confetti"
        case .hearts: "Hearts"
        }
    }
}

/// Draws the backdrop. The preview and every export use this, so what you see is what you get.
enum BackdropRenderer {
    private static let cache = NSCache<NSString, CGImage>()
    private static let ci = CIContext(options: [.cacheIntermediates: false])

    /// Fills `W` × `H` (top-left origin context) with the design's backdrop.
    /// `picture` gives the image to blur (only asked for when the backdrop is a blur).
    static func draw(ctx: CGContext, W: Double, H: Double, project: Project, picture: (String) -> UIImage?) {
        let rect = CGRect(x: 0, y: 0, width: W, height: H)
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.setFillColor(UIColor(hex: project.bg).cgColor)
        ctx.fill(rect)
        let b = project.backdrop
        switch b.kind {
        case .color:
            return
        case .gradient:
            drawGradient(ctx, rect: rect, preset: gradientPresets[clampIndex(b.gradient, gradientPresets.count)])
        case .pattern:
            let unit = W / project.canvasWidth
            drawPattern(ctx, rect: rect, pattern: BackdropPattern(rawValue: b.pattern) ?? .dots, base: UIColor(hex: project.bg), unit: unit)
        case .blur:
            guard let id = blurSource(project), let img = picture(id),
                  let blurred = blurredImage(img, key: id, W: W, H: H) else { return }
            ctx.saveGState()
            ctx.translateBy(x: 0, y: H)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(blurred, in: rect)
            ctx.restoreGState()
        }
    }

    /// The sides around a picture resized to fit its cell: a blurred copy of the picture, or a plain colour.
    /// Drawn in `rect` of a top-left-origin context, before the picture itself.
    static func drawFitBars(ctx: CGContext, rect: PxRect, cell: CellState, item: MediaItem) {
        guard cell.fit else { return }
        ctx.saveGState()
        defer { ctx.restoreGState() }
        if cell.fitBars == fitBlur {
            guard let id = cell.mediaId,
                  let blurred = blurredImage(item.preview ?? item.thumbnail, key: id, W: rect.w, H: rect.h) else { return }
            ctx.translateBy(x: rect.x, y: rect.y + rect.h)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(blurred, in: CGRect(x: 0, y: 0, width: rect.w, height: rect.h))
        } else {
            ctx.setFillColor(UIColor(hex: cell.fitBars).cgColor)
            ctx.fill(rect.cgRect)
        }
    }

    /// The picture behind a blur backdrop: the chosen one, or the first picture in the layout.
    static func blurSource(_ project: Project) -> String? {
        project.backdrop.blurMediaId ?? project.cells.prefix(project.cellCount).compactMap(\.mediaId).first
    }

    /// A finished backdrop as an image (used by the live preview, which redraws it only when it changes).
    static func image(project: Project, W: Double, H: Double, picture: (String) -> UIImage?) -> CGImage? {
        let w = max(1, Int(W.rounded())), h = max(1, Int(H.rounded()))
        guard let ctx = CollageRenderer.makeContext(width: w, height: h) else { return nil }
        draw(ctx: ctx, W: Double(w), H: Double(h), project: project, picture: picture)
        return ctx.makeImage()
    }

    private static func clampIndex(_ i: Int, _ n: Int) -> Int { min(max(0, i), n - 1) }

    static func drawGradient(_ ctx: CGContext, rect: CGRect, preset: GradientPreset) {
        let colors = preset.colors.map { UIColor(hex: $0).cgColor } as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: nil) else { return }
        ctx.saveGState()
        ctx.clip(to: rect)
        if let angle = preset.angle {
            let a = angle * .pi / 180
            let c = CGPoint(x: rect.midX, y: rect.midY)
            // long enough to reach both corners whatever the angle
            let half = (abs(cos(a)) * rect.width + abs(sin(a)) * rect.height) / 2
            let dx = cos(a) * half, dy = sin(a) * half
            ctx.drawLinearGradient(g, start: CGPoint(x: c.x - dx, y: c.y - dy), end: CGPoint(x: c.x + dx, y: c.y + dy),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        } else {
            let c = CGPoint(x: rect.midX, y: rect.midY * 0.9)
            ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: hypot(rect.width, rect.height) * 0.6,
                                   options: [.drawsAfterEndLocation])
        }
        ctx.restoreGState()
    }

    /// Patterns are drawn in a soft tone of the background colour (lighter on dark, darker on light).
    static func drawPattern(_ ctx: CGContext, rect: CGRect, pattern: BackdropPattern, base: UIColor, unit: Double) {
        var bri: CGFloat = 0
        base.getHue(nil, saturation: nil, brightness: &bri, alpha: nil)
        let ink = (bri < 0.55 ? UIColor.white : UIColor.black).withAlphaComponent(0.13).cgColor
        let step = 54 * unit
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.setFillColor(ink)
        ctx.setStrokeColor(ink)
        switch pattern {
        case .dots:
            let r = 6 * unit
            var row = 0
            for y in stride(from: step / 2, to: rect.maxY + step, by: step) {
                let shift = row % 2 == 0 ? 0 : step / 2
                for x in stride(from: shift, to: rect.maxX + step, by: step) {
                    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                }
                row += 1
            }
        case .grid:
            ctx.setLineWidth(2 * unit)
            for x in stride(from: 0, to: rect.maxX, by: step) { ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: rect.maxY)) }
            for y in stride(from: 0, to: rect.maxY, by: step) { ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: rect.maxX, y: y)) }
            ctx.strokePath()
        case .stripes:
            ctx.setLineWidth(step * 0.32)
            let span = rect.width + rect.height
            for d in stride(from: -rect.height, to: span, by: step) {
                ctx.move(to: CGPoint(x: d, y: 0))
                ctx.addLine(to: CGPoint(x: d + rect.height, y: rect.height))
            }
            ctx.strokePath()
        case .checks:
            let s = step * 1.2
            var row = 0
            for y in stride(from: 0, to: rect.maxY, by: s) {
                var col = 0
                for x in stride(from: 0, to: rect.maxX, by: s) {
                    if (row + col) % 2 == 0 { ctx.fill(CGRect(x: x, y: y, width: s, height: s)) }
                    col += 1
                }
                row += 1
            }
        case .confetti:
            // fixed seed: the same confetti in the preview and the export
            var rng = SeededRandom(seed: 7)
            let palette = ["#ff5fa2", "#6c4dff", "#4dc7ff", "#ffd166", "#52d98c"].map { UIColor(hex: $0).withAlphaComponent(0.7).cgColor }
            let count = Int(rect.width * rect.height / (step * step) * 0.9)
            for _ in 0..<count {
                let x = rng.next() * rect.width, y = rng.next() * rect.height
                ctx.setFillColor(palette[Int(rng.next() * Double(palette.count)) % palette.count])
                ctx.saveGState()
                ctx.translateBy(x: x, y: y)
                ctx.rotate(by: rng.next() * .pi)
                if rng.next() < 0.5 {
                    ctx.fill(CGRect(x: -7 * unit, y: -2.5 * unit, width: 14 * unit, height: 5 * unit))
                } else {
                    ctx.fillEllipse(in: CGRect(x: -4 * unit, y: -4 * unit, width: 8 * unit, height: 8 * unit))
                }
                ctx.restoreGState()
            }
        case .hearts:
            let s = step * 1.3
            let size = 16 * unit
            var row = 0
            for y in stride(from: s / 2, to: rect.maxY + s, by: s) {
                let shift = row % 2 == 0 ? 0 : s / 2
                for x in stride(from: shift, to: rect.maxX + s, by: s) {
                    ctx.addPath(heartPath(center: CGPoint(x: x, y: y), size: size))
                }
                row += 1
            }
            ctx.fillPath()
        }
        ctx.restoreGState()
    }

    private static func heartPath(center c: CGPoint, size s: Double) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: c.x, y: c.y + s * 0.45))
        p.addCurve(to: CGPoint(x: c.x - s * 0.5, y: c.y - s * 0.1), control1: CGPoint(x: c.x - s * 0.15, y: c.y + s * 0.25), control2: CGPoint(x: c.x - s * 0.5, y: c.y + s * 0.15))
        p.addArc(center: CGPoint(x: c.x - s * 0.25, y: c.y - s * 0.15), radius: s * 0.25, startAngle: .pi, endAngle: 0, clockwise: false)
        p.addArc(center: CGPoint(x: c.x + s * 0.25, y: c.y - s * 0.15), radius: s * 0.25, startAngle: .pi, endAngle: 0, clockwise: false)
        p.addCurve(to: CGPoint(x: c.x, y: c.y + s * 0.45), control1: CGPoint(x: c.x + s * 0.5, y: c.y + s * 0.15), control2: CGPoint(x: c.x + s * 0.15, y: c.y + s * 0.25))
        p.closeSubpath()
        return p
    }

    /// The picture covering W × H, heavily blurred and a little darkened so the pictures on it stand out.
    /// Made at a modest size (it is blurred anyway) and kept, so a video export makes it once.
    static func blurredImage(_ img: UIImage, key id: String, W: Double, H: Double) -> CGImage? {
        let scale = min(1, 720 / max(W, H))
        let w = max(1, Int(W * scale)), h = max(1, Int(H * scale))
        let key = "\(id)-\(w)x\(h)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let cg = img.cgImage ?? CIContext().createCGImage(CIImage(image: img) ?? CIImage(), from: CGRect(origin: .zero, size: img.size)) else { return nil }
        var input = CIImage(cgImage: cg)
        // orientation of the source image
        input = input.oriented(CGImagePropertyOrientation(img.imageOrientation))
        let ext = input.extent
        let cover = max(Double(w) / ext.width, Double(h) / ext.height)
        input = input.transformed(by: CGAffineTransform(scaleX: cover, y: cover))
        let e2 = input.extent
        input = input.transformed(by: CGAffineTransform(translationX: -e2.minX - (e2.width - Double(w)) / 2, y: -e2.minY - (e2.height - Double(h)) / 2))
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = input.clampedToExtent()
        blur.radius = Float(max(w, h)) * 0.035
        let dim = CIFilter.colorControls()
        dim.inputImage = blur.outputImage
        dim.brightness = -0.08
        dim.saturation = 1.15
        guard let out = dim.outputImage,
              let made = ci.createCGImage(out, from: CGRect(x: 0, y: 0, width: w, height: h)) else { return nil }
        cache.setObject(made, forKey: key)
        return made
    }
}

/// A small repeatable random generator (the same numbers every time for the same seed).
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    /// 0..<1
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
