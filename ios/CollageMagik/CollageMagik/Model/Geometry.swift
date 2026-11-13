import Foundation

/// Instagram covers roughly the top 14% and bottom 18% of a Story with its own buttons.
let safeTop = 0.14
let safeBottom = 0.18

struct PxRect: Equatable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    /// Degrees the rect is turned about its centre (photos on top).
    var tilt: Double = 0

    var cgRect: CGRect { CGRect(x: x, y: y, width: w, height: h) }
    var center: CGPoint { CGPoint(x: x + w / 2, y: y + h / 2) }
    func contains(_ px: Double, _ py: Double) -> Bool {
        var px = px, py = py
        if tilt != 0 {
            let cx = x + w / 2, cy = y + h / 2
            let t = -tilt * RAD, dx = px - cx, dy = py - cy
            px = cx + dx * cos(t) - dy * sin(t)
            py = cy + dx * sin(t) + dy * cos(t)
        }
        return px >= x && px <= x + w && py >= y && py <= y + h
    }
    /// Smaller on every side by `d`.
    func inset(_ d: Double) -> PxRect { inset(left: d, top: d, right: d, bottom: d) }
    func inset(left: Double, top: Double, right: Double, bottom: Double) -> PxRect {
        PxRect(x: x + left, y: y + top, w: max(1, w - left - right), h: max(1, h - top - bottom), tilt: tilt)
    }
}

@inline(__always) func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, v)) }

/// Cell rectangles in pixels. `gap` (pixels at 1080 wide) is both the space between cells and the margin around the collage.
/// `unit` is how many canvas pixels one "1080 wide" pixel is worth (W / 1080 for a collage, per slide for a carousel).
func cellPixelRects(_ rects: [LayoutRect], W: Double, H: Double, gap: Double, unit: Double? = nil) -> [PxRect] {
    let g = gap * (unit ?? W / 1080)
    let half = g / 2
    let areaW = W - g
    let areaH = H - g
    return rects.map { r in
        PxRect(
            x: half + r.x * areaW + half,
            y: half + r.y * areaH + half,
            w: max(1, r.w * areaW - g),
            h: max(1, r.h * areaH - g)
        )
    }
}

/// New pan value after dragging the media by `deltaPx` along an axis.
func panAfterDrag(_ pan: Double, deltaPx: Double, overflowPx: Double) -> Double {
    if overflowPx < 0.5 { return 0 }
    return clamp(pan + deltaPx / (overflowPx / 2), -1, 1)
}

let RAD = Double.pi / 180

/// Width and height of a source after quarter turns.
func quarterDims(_ w: Double, _ h: Double, rotation: Double) -> (w: Double, h: Double) {
    let n = Int((rotation / 90).rounded())
    let odd = ((n % 2) + 2) % 2 == 1
    return odd ? (h, w) : (w, h)
}

struct MediaView: Equatable {
    var zoom: Double = 1
    var panX: Double = 0
    var panY: Double = 0
    var rotation: Double = 0
    var flip: Bool = false
    var angle: Double = 0
}

/// Scale at which a (rotated, straightened) source just covers the cell.
func coverScale(srcW: Double, srcH: Double, cellW: Double, cellH: Double, rotation: Double = 0, angle: Double = 0) -> Double {
    let q = quarterDims(srcW, srcH, rotation: rotation)
    let t = angle * RAD
    let c = abs(cos(t))
    let s = abs(sin(t))
    return max((cellW * c + cellH * s) / q.w, (cellW * s + cellH * c) / q.h)
}

/// How far (0...1) a requested shift (ox, oy) of a tilted picture can go before an empty corner would show.
private func maxShiftFraction(dw: Double, dh: Double, cellW: Double, cellH: Double, angle: Double, ox: Double, oy: Double) -> Double {
    let t = angle * RAD
    let c = cos(t)
    let s = sin(t)
    var hi = 1.0
    for (sx, sy) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
        let qx = sx * cellW / 2
        let qy = sy * cellH / 2
        let ax = c * qx + s * qy
        let ay = -s * qx + c * qy
        let bx = c * ox + s * oy
        let by = -s * ox + c * oy
        for (a, b, half) in [(ax, bx, dw / 2), (ay, by, dh / 2)] {
            if abs(b) < 1e-9 { continue }
            hi = min(hi, max((a - half) / b, (a + half) / b))
        }
    }
    return max(0, hi)
}

struct Placement {
    /// Centre of the picture in pixels.
    var cx: Double
    var cy: Double
    /// Source pixels to canvas pixels.
    var scale: Double
    var rotationRad: Double
    var angleRad: Double
    var flip: Bool
    /// Room to move the picture on each axis, as used for panning (px, >= 0).
    var overflowX: Double
    var overflowY: Double
    /// 1 unless a tilted picture had to be pulled back so no empty corner shows.
    var fit: Double
}

/// Where and how to draw a source in a cell: covers the cell, then zoom, rotation, flip, straighten and pan.
func placeMedia(srcW: Double, srcH: Double, cell: PxRect, view v: MediaView) -> Placement {
    let scale = coverScale(srcW: srcW, srcH: srcH, cellW: cell.w, cellH: cell.h, rotation: v.rotation, angle: v.angle) * max(1, v.zoom)
    let q = quarterDims(srcW, srcH, rotation: v.rotation)
    let dw = q.w * scale
    let dh = q.h * scale
    let t = v.angle * RAD
    let c = abs(cos(t))
    let s = abs(sin(t))
    let bw = dw * c + dh * s
    let bh = dw * s + dh * c
    let overflowX = max(0, bw - cell.w)
    let overflowY = max(0, bh - cell.h)
    var ox = clamp(v.panX, -1, 1) * overflowX / 2
    var oy = clamp(v.panY, -1, 1) * overflowY / 2
    var fit = 1.0
    if v.angle != 0 && (ox != 0 || oy != 0) {
        fit = min(1, maxShiftFraction(dw: dw, dh: dh, cellW: cell.w, cellH: cell.h, angle: v.angle, ox: ox, oy: oy))
        ox *= fit
        oy *= fit
    }
    return Placement(
        cx: cell.x + cell.w / 2 + ox,
        cy: cell.y + cell.h / 2 + oy,
        scale: scale,
        rotationRad: v.rotation * RAD,
        angleRad: v.angle * RAD,
        flip: v.flip,
        overflowX: overflowX,
        overflowY: overflowY,
        fit: fit
    )
}

/// Size to decode a photo at so a cell shows it at full sharpness without ever upscaling.
func neededPhotoSize(srcW: Double, srcH: Double, cell: PxRect, view v: MediaView) -> (w: Int, h: Int) {
    let scale = min(1, coverScale(srcW: srcW, srcH: srcH, cellW: cell.w, cellH: cell.h, rotation: v.rotation, angle: v.angle) * max(1, v.zoom))
    return (max(1, Int((srcW * scale).rounded())), max(1, Int((srcH * scale).rounded())))
}

func hitCell(_ rects: [PxRect], x: Double, y: Double) -> Int {
    for i in stride(from: rects.count - 1, through: 0, by: -1) where rects[i].contains(x, y) { return i }
    return -1
}
