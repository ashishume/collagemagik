import CoreGraphics
import Foundation
import UIKit

/// The outline of a framed photo, in a box `size` big with its top-left corner at the origin.
/// A torn frame gets a ragged paper edge (the same rag every time for the same cell).
func frameOutline(_ style: PhotoFrame, size: CGSize, radius: Double, edge: Double, seed: Int) -> CGPath {
    let w = Double(size.width), h = Double(size.height)
    if style == .stamp { return stampOutline(w: w, h: h, edge: edge) }
    guard style == .torn else {
        let r = max(0, min(radius, w / 2, h / 2))
        return CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: r, cornerHeight: r, transform: nil)
    }
    var rng = SeededRNG(seed: seed, salt: 977)
    let depth = max(1, edge * 0.42)
    let step = max(3, edge * 0.55)
    let path = CGMutablePath()
    // walk round the four sides; each point is pulled inwards by a random amount
    let sides: [(CGPoint, CGPoint, CGVector)] = [
        (CGPoint(x: 0, y: 0), CGPoint(x: w, y: 0), CGVector(dx: 0, dy: 1)),
        (CGPoint(x: w, y: 0), CGPoint(x: w, y: h), CGVector(dx: -1, dy: 0)),
        (CGPoint(x: w, y: h), CGPoint(x: 0, y: h), CGVector(dx: 0, dy: -1)),
        (CGPoint(x: 0, y: h), CGPoint(x: 0, y: 0), CGVector(dx: 1, dy: 0)),
    ]
    var first = true
    for (a, b, inward) in sides {
        let len = hypot(b.x - a.x, b.y - a.y)
        let n = max(2, Int(len / step))
        for k in 0..<n {
            let t = Double(k) / Double(n)
            let d = k == 0 ? depth * 0.5 : rng.value(0, depth)
            let p = CGPoint(x: a.x + (b.x - a.x) * t + inward.dx * d, y: a.y + (b.y - a.y) * t + inward.dy * d)
            if first { path.move(to: p); first = false } else { path.addLine(to: p) }
        }
    }
    path.closeSubpath()
    return path
}

/// A postage stamp: a rectangle whose edges are bitten by small half circles (the perforation).
private func stampOutline(w: Double, h: Double, edge: Double) -> CGPath {
    let r = max(1, edge * 0.32)
    let path = CGMutablePath()
    let corners = [CGPoint(x: 0, y: 0), CGPoint(x: w, y: 0), CGPoint(x: w, y: h), CGPoint(x: 0, y: h)]
    path.move(to: corners[0])
    for k in 0..<4 {
        let a = corners[k], b = corners[(k + 1) % 4]
        let len = hypot(b.x - a.x, b.y - a.y)
        let dir = CGVector(dx: (b.x - a.x) / len, dy: (b.y - a.y) / len)
        // inward normal for a clockwise walk in a y-down space
        let n = CGVector(dx: -dir.dy, dy: dir.dx)
        let count = max(2, Int(len / (r * 2.9)))
        let step = len / Double(count)
        for j in 0..<count {
            let c = CGPoint(x: a.x + dir.dx * step * (Double(j) + 0.5), y: a.y + dir.dy * step * (Double(j) + 0.5))
            for s in 0...8 {
                let t = Double(s) / 8 * .pi
                path.addLine(to: CGPoint(x: c.x - dir.dx * r * cos(t) + n.dx * r * sin(t),
                                         y: c.y - dir.dy * r * cos(t) + n.dy * r * sin(t)))
            }
        }
        path.addLine(to: b)
    }
    path.closeSubpath()
    return path
}

/// The outline the picture is cut to: a rounded rectangle, or a circle, heart or arch for the shape frames.
/// `rect` is in whatever space the caller draws in.
func pictureClipPath(_ frame: PhotoFrame, rect: CGRect, radius: Double) -> CGPath {
    switch frame {
    case .circle:
        let side = min(rect.width, rect.height)
        return CGPath(ellipseIn: CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side), transform: nil)
    case .heart:
        let s = min(rect.width, rect.height * 1.05)
        let w = s, h = s * 0.92
        let x = rect.midX - w / 2, y = rect.midY - h / 2
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x + w / 2, y: y + h))
        p.addCurve(to: CGPoint(x: x, y: y + h * 0.32), control1: CGPoint(x: x + w * 0.2, y: y + h * 0.78), control2: CGPoint(x: x, y: y + h * 0.58))
        p.addArc(center: CGPoint(x: x + w * 0.25, y: y + h * 0.27), radius: w * 0.25, startAngle: .pi * 1.08, endAngle: 0, clockwise: false)
        p.addArc(center: CGPoint(x: x + w * 0.75, y: y + h * 0.27), radius: w * 0.25, startAngle: .pi, endAngle: -.pi * 0.08, clockwise: false)
        p.addCurve(to: CGPoint(x: x + w / 2, y: y + h), control1: CGPoint(x: x + w, y: y + h * 0.58), control2: CGPoint(x: x + w * 0.8, y: y + h * 0.78))
        p.closeSubpath()
        return p
    case .arch:
        let r = min(rect.width / 2, rect.height / 2)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.midX, y: rect.minY + r), radius: r, startAngle: .pi, endAngle: 0, clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    default:
        let rr = max(0, min(radius, rect.width / 2, rect.height / 2))
        return CGPath(roundedRect: rect, cornerWidth: rr, cornerHeight: rr, transform: nil)
    }
}

/// The parts of a frame that are more than a coloured edge: film sprocket holes (under the picture), and washi tape,
/// a gallery mat's inner line, a camera date stamp or a neon glow (over it). One drawing for the live preview and every
/// export, in a top-left-origin context; `outer` and `picture` are in that context's space.
enum FrameDecor {
    static func drawUnder(_ ctx: CGContext, frame: PhotoFrame, outer: CGRect, picture: CGRect, color: String, unit: Double) {
        guard frame == .film else { return }
        let body = UIColor(hex: color)
        var bri: CGFloat = 0
        body.getHue(nil, saturation: nil, brightness: &bri, alpha: nil)
        let hole = bri < 0.5 ? UIColor(white: 0.93, alpha: 0.9) : UIColor(white: 0.08, alpha: 0.85)
        let band = picture.minY - outer.minY
        guard band > 2 else { return }
        let hh = band * 0.36, hw = hh * 0.78, gap = hw * 1.25
        let count = max(1, Int((outer.width - gap) / (hw + gap)))
        let start = outer.minX + (outer.width - (Double(count) * (hw + gap) - gap)) / 2
        ctx.saveGState()
        ctx.setFillColor(hole.cgColor)
        for y in [outer.minY + (band - hh) / 2, picture.maxY + (outer.maxY - picture.maxY - hh) / 2] {
            for k in 0..<count {
                let r = CGRect(x: start + Double(k) * (hw + gap), y: y, width: hw, height: hh)
                ctx.addPath(CGPath(roundedRect: r, cornerWidth: hw * 0.22, cornerHeight: hw * 0.22, transform: nil))
            }
        }
        ctx.fillPath()
        ctx.restoreGState()
    }

    static func drawOver(_ ctx: CGContext, frame: PhotoFrame, outer: CGRect, picture: CGRect, color: String, unit: Double, seed: Int) {
        switch frame {
        case .tape: tape(ctx, outer: outer, seed: seed)
        case .gallery:
            let gap = (picture.minX - outer.minX) * 0.16
            ctx.saveGState()
            ctx.setStrokeColor(UIColor.black.withAlphaComponent(0.22).cgColor)
            ctx.setLineWidth(max(0.6, 1.4 * unit))
            ctx.stroke(picture.insetBy(dx: -gap, dy: -gap))
            ctx.restoreGState()
        case .date: dateStamp(ctx, picture: picture)
        case .neon:
            let path = pictureClipPath(.neon, rect: picture, radius: 18 * unit)
            let glow = UIColor(hex: color)
            ctx.saveGState()
            for (width, blur, alpha) in [(7.0, 26.0, 0.9), (3.5, 10.0, 1.0)] {
                ctx.setShadow(offset: .zero, blur: blur * unit, color: glow.withAlphaComponent(alpha).cgColor)
                ctx.setStrokeColor(glow.cgColor)
                ctx.setLineWidth(width * unit)
                ctx.addPath(path)
                ctx.strokePath()
            }
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.85).cgColor)
            ctx.setLineWidth(1.4 * unit)
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()
        default: break
        }
    }

    /// Two strips of see-through washi tape across the top corners.
    private static func tape(_ ctx: CGContext, outer: CGRect, seed: Int) {
        let colors = ["#f7c8d8", "#c8e3f7", "#fbe7a1", "#cdeccd", "#e2d1f9"]
        let w = outer.width * 0.34, h = max(6, w * 0.27)
        for (k, corner) in [(0, CGPoint(x: outer.minX + w * 0.18, y: outer.minY + h * 0.2)),
                            (1, CGPoint(x: outer.maxX - w * 0.18, y: outer.minY + h * 0.2))] {
            let c = UIColor(hex: colors[(seed * 2 + k) % colors.count]).withAlphaComponent(0.82)
            ctx.saveGState()
            ctx.translateBy(x: corner.x, y: corner.y)
            ctx.rotate(by: (k == 0 ? -38 : 38) * .pi / 180)
            ctx.setShadow(offset: CGSize(width: 0, height: h * 0.06), blur: h * 0.18, color: UIColor.black.withAlphaComponent(0.18).cgColor)
            ctx.setFillColor(c.cgColor)
            ctx.fill(CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            // faint stripes, like printed washi tape
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.22).cgColor)
            var x = -w / 2
            while x < w / 2 {
                ctx.fill(CGRect(x: x, y: -h / 2, width: h * 0.18, height: h))
                x += h * 0.45
            }
            ctx.restoreGState()
        }
    }

    /// The orange date in the corner of a photo from a film camera: today's date, like the camera printing it.
    private static func dateStamp(_ ctx: CGContext, picture: CGRect) {
        let f = DateFormatter()
        f.dateFormat = "''yy  MM  dd"
        let text = f.string(from: Date())
        let size = max(6, min(picture.width, picture.height) * 0.07)
        let font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: .bold)
        let orange = UIColor(red: 1, green: 0.55, blue: 0.16, alpha: 1)
        let shadow = NSShadow()
        shadow.shadowColor = UIColor(red: 1, green: 0.35, blue: 0, alpha: 0.85)
        shadow.shadowBlurRadius = size * 0.35
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: orange, .shadow: shadow, .kern: size * 0.04]
        let s = NSAttributedString(string: text, attributes: attrs)
        let b = s.size()
        UIGraphicsPushContext(ctx)
        s.draw(at: CGPoint(x: picture.maxX - b.width - picture.width * 0.05, y: picture.maxY - b.height - picture.height * 0.04))
        UIGraphicsPopContext()
    }
}
