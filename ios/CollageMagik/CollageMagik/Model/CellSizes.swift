import Foundation

/// A border between two neighbouring cells of a grid layout that can be dragged to resize them.
struct LayoutDivider: Equatable {
    /// nil: between bands `index` and `index + 1`. Otherwise inside that band, between cells `index` and `index + 1`.
    var band: Int?
    var index: Int
}

/// A divider as a line in layout fractions (0...1). `vertical` lines move sideways, the others up and down.
struct DividerLine {
    var vertical: Bool
    /// Where the line sits across its axis.
    var at: Double
    /// Where it starts and ends along its length.
    var from: Double
    var to: Double
}

/// The smallest share of a band (or of the collage) a dragged cell can shrink to.
let minCellFraction = 0.1

extension LayoutGrid {
    var dividers: [LayoutDivider] {
        var out = (0..<max(0, outer.count - 1)).map { LayoutDivider(band: nil, index: $0) }
        for (b, parts) in inner.enumerated() where parts.count > 1 {
            out += (0..<parts.count - 1).map { LayoutDivider(band: b, index: $0) }
        }
        return out
    }

    func line(_ d: LayoutDivider) -> DividerLine {
        if let b = d.band {
            let start = outer[..<b].reduce(0, +)
            let at = inner[b][...d.index].reduce(0, +)
            // rows: cells sit side by side in a band, so the border between them runs up and down
            return DividerLine(vertical: rows, at: at, from: start, to: start + outer[b])
        }
        return DividerLine(vertical: !rows, at: outer[...d.index].reduce(0, +), from: 0, to: 1)
    }

    /// The two sizes either side of a divider.
    func sizes(at d: LayoutDivider) -> (Double, Double) {
        let parts = d.band.map { inner[$0] } ?? outer
        return (parts[d.index], parts[d.index + 1])
    }

    /// The grid with a divider moved to give the cell before it `first` (the cell after it takes the rest), kept
    /// clear of the minimum size. `limited` is true when the minimum stopped it.
    func moving(_ d: LayoutDivider, first: Double) -> (grid: LayoutGrid, limited: Bool) {
        let (a, b) = sizes(at: d)
        let total = a + b
        let lo = min(minCellFraction, total / 2)
        let v = clamp(first, lo, total - lo)
        var g = self
        if let band = d.band {
            g.inner[band][d.index] = v
            g.inner[band][d.index + 1] = total - v
        } else {
            g.outer[d.index] = v
            g.outer[d.index + 1] = total - v
        }
        return (g, v != first)
    }
}

extension Project {
    /// The collage grid on show (with any dragged sizes), or nil when the layout can't be resized (or in a carousel).
    var resizableGrid: LayoutGrid? { mode == .collage ? layout(for: self).grid : nil }

    /// True when the cells have been dragged away from the layout's own sizes.
    var hasCustomSizes: Bool {
        guard mode == .collage, let sizes = cellSizes, let base = layout(byId: layoutId).grid, base.sameShape(sizes) else { return false }
        let a = sizes.outer + sizes.inner.flatMap { $0 }
        let b = base.outer + base.inner.flatMap { $0 }
        return zip(a, b).contains { abs($0 - $1) > 0.0005 }
    }
}

/// A divider's line in canvas pixels, matching `cellPixelRects`: the middle of the gap between the two cells.
func dividerPixelLine(_ l: DividerLine, W: Double, H: Double, gapPx g: Double) -> (a: CGPoint, b: CGPoint) {
    let half = g / 2
    func x(_ u: Double) -> Double { half + u * (W - g) }
    func y(_ u: Double) -> Double { half + u * (H - g) }
    return l.vertical
        ? (CGPoint(x: x(l.at), y: y(l.from)), CGPoint(x: x(l.at), y: y(l.to)))
        : (CGPoint(x: x(l.from), y: y(l.at)), CGPoint(x: x(l.to), y: y(l.at)))
}
