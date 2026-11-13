import CoreGraphics
import Foundation

/// The outline of a framed photo, in a box `size` big with its top-left corner at the origin.
/// A torn frame gets a ragged paper edge (the same rag every time for the same cell).
func frameOutline(_ style: PhotoFrame, size: CGSize, radius: Double, edge: Double, seed: Int) -> CGPath {
    let w = Double(size.width), h = Double(size.height)
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
