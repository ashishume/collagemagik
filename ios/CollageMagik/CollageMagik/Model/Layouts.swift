import Foundation

private func equalParts(_ n: Int) -> [Double] {
    Array(repeating: 1.0 / Double(n), count: n)
}

/// Rows stacked top to bottom; row i holds counts[i] equal-width cells.
private func rowsOf(_ counts: [Int], _ heights: [Double]? = nil) -> [LayoutRect] {
    let hs = heights ?? equalParts(counts.count)
    var out: [LayoutRect] = []
    var y = 0.0
    for (i, n) in counts.enumerated() {
        for c in 0..<n {
            out.append(LayoutRect(x: Double(c) / Double(n), y: y, w: 1 / Double(n), h: hs[i]))
        }
        y += hs[i]
    }
    return out
}

/// Columns side by side; column i holds counts[i] equal-height cells.
private func colsOf(_ counts: [Int], _ widths: [Double]? = nil) -> [LayoutRect] {
    let ws = widths ?? equalParts(counts.count)
    var out: [LayoutRect] = []
    var x = 0.0
    for (i, n) in counts.enumerated() {
        for r in 0..<n {
            out.append(LayoutRect(x: x, y: Double(r) / Double(n), w: ws[i], h: 1 / Double(n)))
        }
        x += ws[i]
    }
    return out
}

private func L(_ id: String, _ name: String, _ rects: [LayoutRect]) -> CollageLayout {
    CollageLayout(id: id, name: name, rects: rects)
}

let allLayouts: [CollageLayout] = [
    L("1-full", "Full", rowsOf([1])),
    L("1-centre", "Centred", [LayoutRect(x: 0.08, y: 0.2, w: 0.84, h: 0.6)]),

    L("2-stack", "Stacked", rowsOf([1, 1])),
    L("2-side", "Side by side", colsOf([1, 1])),
    L("2-top-small", "Small on top", rowsOf([1, 1], [1.0 / 3, 2.0 / 3])),
    L("2-top-big", "Big on top", rowsOf([1, 1], [2.0 / 3, 1.0 / 3])),
    L("2-left-small", "Small on left", colsOf([1, 1], [1.0 / 3, 2.0 / 3])),

    L("3-rows", "Three rows", rowsOf([1, 1, 1])),
    L("3-cols", "Three columns", colsOf([1, 1, 1])),
    L("3-big-top", "Big on top", rowsOf([1, 2], [0.6, 0.4])),
    L("3-big-bottom", "Big at bottom", rowsOf([2, 1], [0.4, 0.6])),
    L("3-big-left", "Big on left", colsOf([1, 2], [0.6, 0.4])),
    L("3-big-right", "Big on right", colsOf([2, 1], [0.4, 0.6])),

    L("4-grid", "Grid", rowsOf([2, 2])),
    L("4-big-top", "Big on top", rowsOf([1, 3], [0.55, 0.45])),
    L("4-big-bottom", "Big at bottom", rowsOf([3, 1], [0.45, 0.55])),
    L("4-band", "Middle pair", rowsOf([1, 2, 1], [0.35, 0.3, 0.35])),
    L("4-side", "Big and stack", colsOf([1, 3], [0.5, 0.5])),

    L("5-hero", "Hero and four", rowsOf([1, 2, 2], [0.4, 0.3, 0.3])),
    L("5-two-three", "Two and three", rowsOf([2, 3])),
    L("5-three-two", "Three and two", rowsOf([3, 2])),
    L("5-sandwich", "Sandwich", rowsOf([2, 1, 2], [0.3, 0.4, 0.3])),

    L("6-grid", "Grid 2×3", rowsOf([2, 2, 2])),
    L("6-wide", "Grid 3×2", rowsOf([3, 3])),
    L("6-stairs", "Stairs", rowsOf([1, 2, 3], [0.4, 0.3, 0.3])),
    L("6-mix", "Wide and pairs", rowsOf([1, 1, 2, 2], [0.28, 0.28, 0.22, 0.22])),

    L("7-hero", "Hero and six", rowsOf([1, 3, 3], [0.4, 0.3, 0.3])),
    L("7-three-four", "Three and four", rowsOf([3, 4])),
    L("7-mix", "Mixed rows", rowsOf([2, 2, 3])),

    L("8-grid", "Grid 2×4", rowsOf([2, 2, 2, 2])),
    L("8-wide", "Grid 4×2", rowsOf([4, 4])),
    L("8-mix", "Mixed rows", rowsOf([2, 3, 3])),

    L("9-grid", "Grid 3×3", rowsOf([3, 3, 3])),
    L("9-hero", "Hero and eight", rowsOf([1, 4, 4], [0.36, 0.32, 0.32])),
    L("9-pyramid", "Pyramid", rowsOf([2, 3, 4])),
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
