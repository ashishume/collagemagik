import SwiftUI
import UIKit

/// Most captions on one design, and the longest a caption can be.
let maxCaptions = 8
let maxCaptionLength = 140
/// Caption size in pixels at 1080 wide.
let captionSizeRange: ClosedRange<Double> = 28...240
/// A caption wraps so it never gets wider than this much of one slide.
let captionMaxWidth = 0.88

/// The lettering styles. All of them ship with iOS, so nothing is bundled or downloaded.
enum CaptionFont: String, CaseIterable, Identifiable {
    case classic, rounded, serif, italic, script, hand, marker, poster, typewriter, chalk
    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic: "Classic"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .italic: "Elegant"
        case .script: "Script"
        case .hand: "Hand"
        case .marker: "Marker"
        case .poster: "Poster"
        case .typewriter: "Typed"
        case .chalk: "Chalk"
        }
    }

    /// Some typefaces look small or large at the same point size: this evens them out.
    private var sizeFactor: Double {
        switch self {
        case .script: 1.3
        case .italic, .hand: 1.1
        case .poster: 1.12
        case .chalk: 0.82
        default: 1
        }
    }

    /// Extra room around the letters, as a fraction of the size (script letters swing far outside their line box).
    var overhang: Double { self == .script ? 0.3 : 0.12 }

    func uiFont(size: Double) -> UIFont {
        let s = CGFloat(size * sizeFactor)
        func system(_ weight: UIFont.Weight, _ design: UIFontDescriptor.SystemDesign) -> UIFont {
            let base = UIFont.systemFont(ofSize: s, weight: weight)
            return base.fontDescriptor.withDesign(design).map { UIFont(descriptor: $0, size: s) } ?? base
        }
        func named(_ name: String) -> UIFont { UIFont(name: name, size: s) ?? .systemFont(ofSize: s, weight: .bold) }
        switch self {
        case .classic: return .systemFont(ofSize: s, weight: .bold)
        case .rounded: return system(.heavy, .rounded)
        case .serif: return system(.bold, .serif)
        case .italic: return named("Baskerville-SemiBoldItalic")
        case .script: return named("SnellRoundhand-Bold")
        case .hand: return named("BradleyHandITCTT-Bold")
        case .marker: return named("MarkerFelt-Wide")
        case .poster: return named("Futura-CondensedExtraBold")
        case .typewriter: return named("AmericanTypewriter-Semibold")
        case .chalk: return named("Chalkduster")
        }
    }
}

/// What sits behind the letters so they stay readable on any photo.
enum CaptionLook: String, CaseIterable, Identifiable {
    /// Letters with a soft shadow.
    case plain
    /// A solid rounded label in the caption's colour, with the letters in black or white.
    case label
    /// A see-through dark (or light) plate behind the letters.
    case plate
    /// Letters with a thick contrasting edge.
    case outline
    var id: String { rawValue }

    var title: String {
        switch self {
        case .plain: "Shadow"
        case .label: "Label"
        case .plate: "Plate"
        case .outline: "Outline"
        }
    }
    var symbol: String {
        switch self {
        case .plain: "textformat"
        case .label: "a.square.fill"
        case .plate: "a.square"
        case .outline: "character.textbox"
        }
    }
}

enum CaptionAlign: String, CaseIterable {
    case left, center, right

    var symbol: String {
        switch self {
        case .left: "text.alignleft"
        case .center: "text.aligncenter"
        case .right: "text.alignright"
        }
    }
    var next: CaptionAlign {
        switch self {
        case .left: .center
        case .center: .right
        case .right: .left
        }
    }
    var textAlignment: NSTextAlignment {
        switch self {
        case .left: .left
        case .center: .center
        case .right: .right
        }
    }
    var swiftUI: TextAlignment {
        switch self {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
    }
}

/// A line of text placed on top of the collage.
struct Caption: Identifiable, Equatable {
    var id: String = UUID().uuidString
    var text: String = ""
    var font: CaptionFont = .classic
    var color: String = "#ffffff"
    var look: CaptionLook = .plain
    var align: CaptionAlign = .center
    /// Letter size in pixels at 1080 wide.
    var size: Double = 76
    /// Centre of the caption. `x` is in slide widths (0...1 in a collage, 0...slides in a carousel), `y` is 0...1 down the design.
    var x: Double = 0.5
    var y: Double = 0.5
    /// Degrees, clockwise.
    var rotation: Double = 0
}

let captionSwatches = ["#ffffff", "#101016", "#ffd84d", "#ff5fa2", "#ff6b4a", "#8b6cff", "#4cc7ff", "#52d98c", "#f4e9d8"]

extension UIColor {
    /// True for colours that need dark letters on top of them (and a light edge around them).
    var isLight: Bool { brightness > 0.6 }

    /// 0 (black) ... 1 (white), as the eye sees it.
    var brightness: Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return Double(0.299 * r + 0.587 * g + 0.114 * b)
    }
}

// MARK: - Drawing

/// A caption measured for one canvas size: what to draw and how big it is.
struct CaptionLayout {
    var caption: Caption
    /// Letter size in canvas pixels.
    var fontPx: Double
    var text: NSAttributedString
    var textSize: CGSize
    /// The caption's box (letters plus padding), before rotation.
    var box: CGSize
    /// Centre on the canvas, in canvas pixels.
    var center: CGPoint
    var rotationRad: Double { caption.rotation * RAD }
    /// Room kept around the box when it is drawn on its own, so shadows and script swashes aren't cut off.
    var bleed: Double { fontPx * 0.45 }

    /// Is the canvas point inside the caption (with a little slack so small captions are easy to touch)?
    func contains(_ p: CGPoint, slack: Double) -> Bool {
        let dx = p.x - center.x, dy = p.y - center.y
        let c = cos(-rotationRad), s = sin(-rotationRad)
        let lx = dx * c - dy * s, ly = dx * s + dy * c
        return abs(lx) <= box.width / 2 + slack && abs(ly) <= box.height / 2 + slack
    }
}

/// Draws captions. The live preview and every export go through here, so what you see is what you get.
enum CaptionRenderer {
    private static let imageCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 48
        return c
    }()

    private static func letterColor(_ c: Caption) -> UIColor {
        let base = UIColor(hex: c.color)
        return c.look == .label ? (base.isLight ? UIColor(hex: "#101016") : .white) : base
    }

    /// Measures a caption for a canvas `W` pixels wide showing a design `canvasWidth` "1080 pixels" wide.
    /// The letters are made smaller than asked for when they wouldn't fit: no word is ever broken in two, and the
    /// caption is never taller than the design.
    static func layout(_ c: Caption, project: Project, W: Double, H: Double) -> CaptionLayout {
        let unit = W / project.canvasWidth
        let slideW = project.format.width * unit
        let boxed = c.look == .label || c.look == .plate
        let para = NSMutableParagraphStyle()
        para.alignment = c.align.textAlignment
        para.lineBreakMode = .byWordWrapping
        para.lineHeightMultiple = c.font == .script ? 0.92 : 1.02
        let string = c.text.isEmpty ? " " : c.text
        let words = string.split(whereSeparator: { $0 == " " || $0.isNewline }).map(String.init)

        var fontPx = clamp(c.size, captionSizeRange.lowerBound, captionSizeRange.upperBound) * unit
        var text = NSAttributedString()
        var ts = CGSize.zero
        var padX = 0.0, padY = 0.0
        for _ in 0..<6 {
            let font = c.font.uiFont(size: fontPx)
            padX = fontPx * (boxed ? 0.42 : c.font.overhang)
            padY = fontPx * (boxed ? 0.2 : 0.08)
            let maxW = max(fontPx, slideW * captionMaxWidth - padX * 2)
            let widest = words.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
            if widest > maxW {
                fontPx *= maxW / widest * 0.98
                continue
            }
            text = NSAttributedString(string: string, attributes: [
                .font: font,
                .foregroundColor: letterColor(c),
                .paragraphStyle: para,
            ])
            let b = text.boundingRect(
                with: CGSize(width: maxW, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil
            )
            ts = CGSize(width: ceil(b.width), height: ceil(b.height))
            let tall = (ts.height + padY * 2) / (H * 0.9)
            if tall <= 1 { break }
            fontPx *= max(0.5, 1 / tall.squareRoot()) * 0.98
        }
        let box = CGSize(width: ts.width + padX * 2, height: ts.height + padY * 2)
        // The whole caption stays inside the design, however it is turned or sized: nothing is ever cut off at an edge.
        let cosT = abs(cos(c.rotation * RAD)), sinT = abs(sin(c.rotation * RAD))
        let margin = slideW * 0.015
        let halfW = (box.width * cosT + box.height * sinT) / 2 + margin
        let halfH = (box.width * sinT + box.height * cosT) / 2 + margin
        func inside(_ v: Double, _ half: Double, _ full: Double) -> Double { half * 2 >= full ? full / 2 : clamp(v, half, full - half) }
        return CaptionLayout(
            caption: c, fontPx: fontPx, text: text, textSize: ts, box: box,
            center: CGPoint(x: inside(c.x * slideW, halfW, W), y: inside(c.y * H, halfH, H))
        )
    }

    /// Draws the caption centred on the origin. The context must be a bitmap context from `CollageRenderer.makeContext`
    /// (top-left origin), which is what both the preview images and the exports use, so shadows match exactly.
    static func draw(_ l: CaptionLayout, in ctx: CGContext) {
        let c = l.caption
        let base = UIColor(hex: c.color)
        let box = CGRect(x: -l.box.width / 2, y: -l.box.height / 2, width: l.box.width, height: l.box.height)
        // A hair wider and taller than measured, so rounding can never push a word onto a new line or drop the last line.
        let slackX = l.fontPx * 0.03
        let textRect = CGRect(
            x: -l.textSize.width / 2 - slackX, y: -l.textSize.height / 2,
            width: l.textSize.width + slackX * 2, height: l.textSize.height + l.fontPx
        )
        let opts: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

        UIGraphicsPushContext(ctx)
        defer { UIGraphicsPopContext() }
        ctx.saveGState()
        defer { ctx.restoreGState() }

        switch c.look {
        case .label, .plate:
            let r = min(l.fontPx * 0.36, box.height / 2)
            let path = CGPath(roundedRect: box, cornerWidth: r, cornerHeight: r, transform: nil)
            let fill: UIColor = c.look == .label ? base : (base.isLight ? UIColor.black.withAlphaComponent(0.5) : UIColor.white.withAlphaComponent(0.72))
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: l.fontPx * 0.22, color: UIColor.black.withAlphaComponent(c.look == .label ? 0.3 : 0.18).cgColor)
            ctx.addPath(path)
            ctx.setFillColor(fill.cgColor)
            ctx.fillPath()
            ctx.restoreGState()
            l.text.draw(with: textRect, options: opts, context: nil)
        case .outline:
            let edge = NSMutableAttributedString(attributedString: l.text)
            let all = NSRange(location: 0, length: edge.length)
            edge.addAttribute(.strokeColor, value: base.isLight ? UIColor(hex: "#101016") : UIColor.white, range: all)
            edge.addAttribute(.strokeWidth, value: 14, range: all) // % of the letter size; positive = edge only
            ctx.setLineJoin(.round)
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: l.fontPx * 0.12, color: UIColor.black.withAlphaComponent(0.3).cgColor)
            edge.draw(with: textRect, options: opts, context: nil)
            ctx.restoreGState()
            l.text.draw(with: textRect, options: opts, context: nil)
        case .plain:
            let shade = base.isLight ? UIColor.black.withAlphaComponent(0.6) : UIColor.white.withAlphaComponent(0.7)
            ctx.setShadow(offset: .zero, blur: l.fontPx * 0.16, color: shade.cgColor)
            l.text.draw(with: textRect, options: opts, context: nil)
        }
    }

    /// Every caption of the project, drawn onto a canvas `W` × `H` pixels.
    static func drawAll(ctx: CGContext, project: Project, W: Double, H: Double) {
        for c in project.captions where !c.text.isEmpty {
            let l = layout(c, project: project, W: W, H: H)
            ctx.saveGState()
            ctx.translateBy(x: l.center.x, y: l.center.y)
            ctx.rotate(by: l.rotationRad)
            draw(l, in: ctx)
            ctx.restoreGState()
        }
    }

    /// All captions on a clear layer the size of the canvas. A video export draws this once and stamps it on every frame.
    static func layer(project: Project, W: Int, H: Int) -> CGImage? {
        guard project.captions.contains(where: { !$0.text.isEmpty }),
              let ctx = CollageRenderer.makeContext(width: W, height: H) else { return nil }
        drawAll(ctx: ctx, project: project, W: Double(W), H: Double(H))
        return ctx.makeImage()
    }

    /// One caption as a picture for the live preview (upright; the view turns and places it). `scale` is the screen scale.
    static func image(_ l: CaptionLayout, scale: Double) -> UIImage? {
        let c = l.caption
        let key = "\(c.text)|\(c.font.rawValue)|\(c.color)|\(c.look.rawValue)|\(c.align.rawValue)|\(Int((l.fontPx * 100).rounded()))|\(Int(l.box.width.rounded()))|\(scale)" as NSString
        if let hit = imageCache.object(forKey: key) { return hit }
        let w = Int(((l.box.width + l.bleed * 2) * scale).rounded(.up))
        let h = Int(((l.box.height + l.bleed * 2) * scale).rounded(.up))
        guard w > 0, h > 0, w < 8192, h < 8192, let ctx = CollageRenderer.makeContext(width: w, height: h) else { return nil }
        // Measure and draw at pixel size, so the shadow is as wide here as it is in an export.
        var big = l
        big.fontPx *= scale
        big.textSize = CGSize(width: l.textSize.width * scale, height: l.textSize.height * scale)
        big.box = CGSize(width: l.box.width * scale, height: l.box.height * scale)
        let m = NSMutableAttributedString(attributedString: l.text)
        m.addAttribute(.font, value: c.font.uiFont(size: big.fontPx), range: NSRange(location: 0, length: m.length))
        big.text = m
        ctx.translateBy(x: Double(w) / 2, y: Double(h) / 2)
        draw(big, in: ctx)
        guard let cg = ctx.makeImage() else { return nil }
        let img = UIImage(cgImage: cg, scale: scale, orientation: .up)
        imageCache.setObject(img, forKey: key)
        return img
    }
}
