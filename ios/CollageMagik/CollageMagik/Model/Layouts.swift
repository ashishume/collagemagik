import Foundation

private func equalParts(_ n: Int) -> [Double] {
    Array(repeating: 1.0 / Double(n), count: n)
}

/// Rectangles of a two-level grid. `rows`: bands stacked top to bottom (`outer` heights), each split side by side
/// into cells (`inner[i]` widths). Otherwise columns side by side, each split top to bottom.
func gridRects(rows: Bool, outer: [Double], inner: [[Double]]) -> [LayoutRect] {
    var out: [LayoutRect] = []
    var a = 0.0
    for (i, size) in outer.enumerated() {
        var b = 0.0
        for part in inner[i] {
            out.append(rows ? LayoutRect(x: b, y: a, w: part, h: size) : LayoutRect(x: a, y: b, w: size, h: part))
            b += part
        }
        a += size
    }
    return out
}

private func gridLayout(_ id: String, _ name: String, rows: Bool, _ counts: [Int], _ sizes: [Double]?) -> CollageLayout {
    let grid = LayoutGrid(rows: rows, outer: sizes ?? equalParts(counts.count), inner: counts.map(equalParts))
    return CollageLayout(id: id, name: name, rects: grid.rects, grid: grid)
}

/// Rows stacked top to bottom; row i holds counts[i] equal-width cells.
private func rowsOf(_ id: String, _ name: String, _ counts: [Int], _ heights: [Double]? = nil) -> CollageLayout {
    gridLayout(id, name, rows: true, counts, heights)
}

/// Columns side by side; column i holds counts[i] equal-height cells.
private func colsOf(_ id: String, _ name: String, _ counts: [Int], _ widths: [Double]? = nil) -> CollageLayout {
    gridLayout(id, name, rows: false, counts, widths)
}

private func L(_ id: String, _ name: String, _ rects: [LayoutRect]) -> CollageLayout {
    CollageLayout(id: id, name: name, rects: rects)
}

let allLayouts: [CollageLayout] = [
    rowsOf("1-full", "Full", [1]),
    L("1-centre", "Centred", [LayoutRect(x: 0.08, y: 0.2, w: 0.84, h: 0.6)]),

    rowsOf("2-stack", "Stacked", [1, 1]),
    colsOf("2-side", "Side by side", [1, 1]),
    rowsOf("2-top-small", "Small on top", [1, 1], [1.0 / 3, 2.0 / 3]),
    rowsOf("2-top-big", "Big on top", [1, 1], [2.0 / 3, 1.0 / 3]),
    colsOf("2-left-small", "Small on left", [1, 1], [1.0 / 3, 2.0 / 3]),

    rowsOf("3-rows", "Three rows", [1, 1, 1]),
    colsOf("3-cols", "Three columns", [1, 1, 1]),
    rowsOf("3-big-top", "Big on top", [1, 2], [0.6, 0.4]),
    rowsOf("3-big-bottom", "Big at bottom", [2, 1], [0.4, 0.6]),
    colsOf("3-big-left", "Big on left", [1, 2], [0.6, 0.4]),
    colsOf("3-big-right", "Big on right", [2, 1], [0.4, 0.6]),

    rowsOf("4-grid", "Grid", [2, 2]),
    rowsOf("4-big-top", "Big on top", [1, 3], [0.55, 0.45]),
    rowsOf("4-big-bottom", "Big at bottom", [3, 1], [0.45, 0.55]),
    rowsOf("4-band", "Middle pair", [1, 2, 1], [0.35, 0.3, 0.35]),
    colsOf("4-side", "Big and stack", [1, 3], [0.5, 0.5]),

    rowsOf("5-hero", "Hero and four", [1, 2, 2], [0.4, 0.3, 0.3]),
    rowsOf("5-two-three", "Two and three", [2, 3]),
    rowsOf("5-three-two", "Three and two", [3, 2]),
    rowsOf("5-sandwich", "Sandwich", [2, 1, 2], [0.3, 0.4, 0.3]),

    rowsOf("6-grid", "Grid 2×3", [2, 2, 2]),
    rowsOf("6-wide", "Grid 3×2", [3, 3]),
    rowsOf("6-stairs", "Stairs", [1, 2, 3], [0.4, 0.3, 0.3]),
    rowsOf("6-mix", "Wide and pairs", [1, 1, 2, 2], [0.28, 0.28, 0.22, 0.22]),

    rowsOf("7-hero", "Hero and six", [1, 3, 3], [0.4, 0.3, 0.3]),
    rowsOf("7-three-four", "Three and four", [3, 4]),
    rowsOf("7-mix", "Mixed rows", [2, 2, 3]),

    rowsOf("8-grid", "Grid 2×4", [2, 2, 2, 2]),
    rowsOf("8-wide", "Grid 4×2", [4, 4]),
    rowsOf("8-mix", "Mixed rows", [2, 3, 3]),

    rowsOf("9-grid", "Grid 3×3", [3, 3, 3]),
    rowsOf("9-hero", "Hero and eight", [1, 4, 4], [0.36, 0.32, 0.32]),
    rowsOf("9-pyramid", "Pyramid", [2, 3, 4]),

    rowsOf("10-mix", "Mixed rows", [3, 4, 3]),
    rowsOf("10-hero", "Hero and nine", [1, 3, 3, 3], [0.34, 0.22, 0.22, 0.22]),
    rowsOf("10-grid", "Grid 2×5", [2, 2, 2, 2, 2]),

    rowsOf("11-mix", "Mixed rows", [3, 4, 4]),
    rowsOf("11-hero", "Hero and ten", [1, 3, 3, 4], [0.34, 0.22, 0.22, 0.22]),
    rowsOf("11-pairs", "Pairs and threes", [2, 3, 3, 3]),

    rowsOf("12-grid", "Grid 3×4", [3, 3, 3, 3]),
    rowsOf("12-wide", "Grid 4×3", [4, 4, 4]),
    rowsOf("12-hero", "Hero and eleven", [1, 3, 4, 4], [0.34, 0.22, 0.22, 0.22]),
    rowsOf("12-tall", "Grid 2×6", [2, 2, 2, 2, 2, 2]),

    // Free-form layouts: pictures laid like prints on a table, some overlapping or turned. Later ones sit on top.
    L("1-tilt", "Tilted print", [R(0.12, 0.12, 0.76, 0.66, -4)]),
    L("2-overlap", "Picture in picture", [R(0.04, 0.04, 0.72, 0.62), R(0.4, 0.48, 0.56, 0.48, 4)]),
    L("3-tossed", "Tossed prints", [R(0.05, 0.06, 0.54, 0.42, -6), R(0.42, 0.29, 0.53, 0.41, 5), R(0.08, 0.54, 0.54, 0.41, -3)]),
    L("3-stairs", "Staircase", [R(0.04, 0.04, 0.52, 0.32), R(0.24, 0.34, 0.52, 0.32), R(0.44, 0.64, 0.52, 0.32)]),
    L("3-filmstrip", "Film strip", [R(0.07, 0.12, 0.86, 0.25), R(0.07, 0.38, 0.86, 0.25), R(0.07, 0.64, 0.86, 0.25)]),
    L("4-tossed", "Tossed four", [R(0.04, 0.05, 0.5, 0.4, -5), R(0.47, 0.09, 0.49, 0.38, 6), R(0.06, 0.5, 0.47, 0.41, 4), R(0.46, 0.54, 0.5, 0.4, -4)]),
    L("4-magazine", "Magazine", [R(0.04, 0.17, 0.6, 0.79), R(0.67, 0.17, 0.29, 0.255), R(0.67, 0.44, 0.29, 0.255), R(0.67, 0.71, 0.29, 0.25)]),
    L("4-offset", "Offset", [R(0.04, 0.03, 0.45, 0.44), R(0.04, 0.5, 0.45, 0.44), R(0.51, 0.09, 0.45, 0.44), R(0.51, 0.56, 0.45, 0.41)]),
    L("4-cluster", "Bubbles", [R(0.06, 0.08, 0.5, 0.4), R(0.44, 0.19, 0.5, 0.4), R(0.08, 0.46, 0.5, 0.4), R(0.45, 0.56, 0.5, 0.4)]),
    L("5-scrapbook", "Scrapbook", [R(0.05, 0.04, 0.5, 0.36, -4), R(0.52, 0.06, 0.43, 0.3, 5), R(0.5, 0.36, 0.44, 0.25, -2),
                                    R(0.04, 0.6, 0.44, 0.34, 3), R(0.52, 0.62, 0.44, 0.33, -5)]),
    L("6-wall", "Print wall", [R(0.04, 0.05, 0.3, 0.27, -3), R(0.35, 0.03, 0.3, 0.27, 2), R(0.66, 0.06, 0.3, 0.27, -2),
                               R(0.05, 0.38, 0.3, 0.27, 2), R(0.36, 0.4, 0.3, 0.27, -3), R(0.66, 0.37, 0.3, 0.27, 3)]),
    L("2-pile", "Two on a pile", [R(0.05, 0.07, 0.62, 0.52, -7), R(0.33, 0.39, 0.62, 0.52, 6)]),
    L("3-fan", "Fan", [R(0.06, 0.22, 0.5, 0.52, -13), R(0.25, 0.17, 0.5, 0.52, 0), R(0.44, 0.22, 0.5, 0.52, 13)]),
    L("3-cascade", "Cascade", [R(0.04, 0.04, 0.56, 0.4, -3), R(0.22, 0.3, 0.56, 0.4, 2), R(0.4, 0.56, 0.56, 0.4, -2)]),
    L("4-hero-prints", "Hero and prints", [R(0.07, 0.1, 0.86, 0.6), R(0.02, 0.63, 0.34, 0.33, -7), R(0.33, 0.67, 0.34, 0.3, 3),
                                            R(0.64, 0.63, 0.34, 0.33, 8)]),
    L("4-zigzag", "Zigzag", [R(0.04, 0.03, 0.5, 0.3, -4), R(0.46, 0.25, 0.5, 0.3, 4), R(0.04, 0.47, 0.5, 0.3, -4), R(0.46, 0.67, 0.5, 0.3, 4)]),
    L("5-pile", "Photo pile", [R(0.04, 0.05, 0.5, 0.38, -9), R(0.44, 0.06, 0.52, 0.38, 7), R(0.2, 0.32, 0.6, 0.4, -2),
                               R(0.03, 0.58, 0.5, 0.38, 5), R(0.46, 0.57, 0.5, 0.38, -6)]),
    L("5-cross", "Plus", [R(0.35, 0.03, 0.3, 0.3), R(0.03, 0.35, 0.3, 0.3), R(0.35, 0.35, 0.3, 0.3), R(0.67, 0.35, 0.3, 0.3), R(0.35, 0.67, 0.3, 0.3)]),
    // eight circles filling a heart: two lobes, a wide middle, then down to the point
    L("8-heart", "Heart", [R(0.160, 0.088, 0.28, 0.224), R(0.560, 0.088, 0.28, 0.224), R(0.020, 0.288, 0.28, 0.224), R(0.360, 0.268, 0.28, 0.224), R(0.700, 0.288, 0.28, 0.224), R(0.180, 0.488, 0.28, 0.224), R(0.540, 0.488, 0.28, 0.224), R(0.360, 0.678, 0.28, 0.224)]),
    L("7-board", "Pinboard", [R(0.04, 0.04, 0.4, 0.3, -4), R(0.47, 0.03, 0.27, 0.23, 5), R(0.75, 0.07, 0.22, 0.27, -3),
                              R(0.06, 0.37, 0.3, 0.27, 3), R(0.38, 0.3, 0.42, 0.33, -2), R(0.08, 0.68, 0.42, 0.28, -5),
                              R(0.54, 0.65, 0.42, 0.31, 4)]),
]

private func R(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ tilt: Double = 0) -> LayoutRect {
    LayoutRect(x: x, y: y, w: w, h: h, tilt: tilt)
}

let maxCells = 12
/// A new collage opens with four slots showing (a 2x2-style layout). It resizes to the number actually picked.
let initialCellCount = 4
/// Carousels: up to twenty pictures over two to twenty slides (Instagram allows 20) (the slide count follows the pictures and the style). A new one opens with five empty slots.
let maxCarouselPhotos = 20
let minSlides = 2
let maxSlides = 20
let initialCarouselCells = 5
let maxVideos = 3
/// The media tray (the strip at the bottom) holds more than a design can show: pick from up to 25 (a full 20-photo
/// carousel plus a few spares) and swap the best into the cells.
let maxTrayItems = 25

func layouts(for count: Int) -> [CollageLayout] { allLayouts.filter { $0.count == count } }
func layout(byId id: String) -> CollageLayout { allLayouts.first { $0.id == id } ?? allLayouts[0] }
func defaultLayout(for count: Int) -> CollageLayout { layouts(for: count).first ?? allLayouts[0] }
