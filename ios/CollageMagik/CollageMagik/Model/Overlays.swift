import Foundation

/// A photo laid freely on top of the design, like a print dropped on the page. It sits above the layout's cells and
/// below the captions, works in collages and carousels (it can cross a slide seam), and keeps the photo's own shape.
struct PhotoOverlay: Identifiable, Equatable, Codable {
    var id: String = UUID().uuidString
    var mediaId: String
    /// Centre. `cx` is in slide widths (0...1 in a collage, 0...slides in a carousel), `cy` is 0...1 down the design.
    var cx: Double
    var cy: Double
    /// Width of the photo (without its frame), in slide widths.
    var w: Double = 0.42
    /// Degrees, clockwise.
    var tilt: Double = 0
    var frame: PhotoFrame = .border
    var frameColor: String = "#ffffff"
}

/// Most photos on top of one design.
let maxOverlays = 12
/// Smallest and largest a photo on top can be, in slide widths.
let overlayWidthRange: ClosedRange<Double> = 0.12...1.4

/// Where a photo on top is drawn on a canvas: the whole print (frame included) and the photo inside it.
struct OverlayGeometry {
    var outer: PxRect
    var picture: PxRect
    /// Frame thickness at the sides, in canvas pixels.
    var edge: Double
}

extension Project {
    /// Canvas pixels for a photo on top whose source is `aspect` (height / width) on a canvas `W` × `H`.
    func overlayGeometry(_ o: PhotoOverlay, aspect: Double, W: Double, H: Double) -> OverlayGeometry {
        let slideW = W / canvasWidth * format.width
        let pw = clamp(o.w, overlayWidthRange.lowerBound, overlayWidthRange.upperBound) * slideW
        let ph = pw * max(0.2, min(5, aspect))
        // printed borders scale with the photo, so a small print has a thin edge
        let side: Double, bottom: Double
        switch o.frame {
        case .border: side = pw * 0.045; bottom = side
        case .instant: side = pw * 0.05; bottom = side * 3.6
        case .torn: side = pw * 0.055; bottom = side
        case .none, .shadow: side = 0; bottom = 0
        }
        let ow = pw + side * 2, oh = ph + side + bottom
        let cx = clamp(o.cx, 0, Double(slides)) * slideW
        let cy = clamp(o.cy, 0, 1) * H
        let outer = PxRect(x: cx - ow / 2, y: cy - oh / 2, w: ow, h: oh, tilt: o.tilt)
        return OverlayGeometry(outer: outer, picture: outer.inset(left: side, top: side, right: side, bottom: bottom), edge: side)
    }
}
