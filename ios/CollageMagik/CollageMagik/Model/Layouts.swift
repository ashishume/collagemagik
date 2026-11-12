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
]

let maxCells = 9
/// A new collage opens with every slot showing, so it is obvious that nine pictures fit. It shrinks to the number actually picked.
let initialCellCount = maxCells
/// Carousels: up to ten pictures over two to ten slides (the slide count follows the pictures and the style). A new one opens with five empty slots.
let maxCarouselPhotos = 10
let minSlides = 2
let maxSlides = 10
let initialCarouselCells = 5
let maxVideos = 2
/// The media tray (the strip at the bottom) holds more than a collage can show: pick from up to 15 and swap the best into the cells.
let maxTrayItems = 15

func layouts(for count: Int) -> [CollageLayout] { allLayouts.filter { $0.count == count } }
func layout(byId id: String) -> CollageLayout { allLayouts.first { $0.id == id } ?? allLayouts[0] }
func defaultLayout(for count: Int) -> CollageLayout { layouts(for: count).first ?? allLayouts[0] }
