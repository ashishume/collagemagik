import Foundation

// MARK: - Carousel geometry

extension Project {
    /// The style in use (always one that suits the current number of pictures).
    var carouselStyleInUse: CarouselStyle { resolvedCarouselStyle(layoutId: layoutId, count: cellCount) }

    /// How many slides the carousel spans. Nobody picks this: it follows the pictures and the style, so the more pictures
    /// (or the roomier the style), the more slides.
    var slides: Int { mode == .carousel ? autoSlides(count: cellCount, style: carouselStyleInUse, format: format) : 1 }

    /// The whole design, in "1080 wide" pixels: one slide for a collage, `slides` side by side for a carousel.
    var canvasWidth: Double { mode == .carousel ? format.width * Double(slides) : format.width }
    var canvasHeight: Double { format.height }
    var canvasAspect: Double { canvasWidth / canvasHeight }

    /// The picture areas for a canvas drawn `W` × `H` pixels wide: inside the frame, when the cell has one.
    func cellRects(W: Double, H: Double) -> [PxRect] {
        let outer = frameRects(W: W, H: H)
        return outer.indices.map { i in
            let e = frameEdges(i, outer[i], W: W)
            return outer[i].inset(left: e.side, top: e.side, right: e.side, bottom: e.bottom)
        }
    }

    /// The whole of each cell, frame included.
    func frameRects(W: Double, H: Double) -> [PxRect] {
        cellPixelRects(layout(for: self).rects, W: W, H: H, gap: gap, unit: W / canvasWidth)
    }

    /// Corner radius for a canvas drawn `W` pixels wide.
    func cornerRadius(W: Double) -> Double { radius * W / canvasWidth }

    /// Does cell `i` get the Style tab's frame?
    func isFramed(_ i: Int) -> Bool { frame != .none && i < cellCount }

    /// Frame thickness around cell `i` (sides, and the bottom, which is deeper on an instant photo), in canvas pixels.
    func frameEdges(_ i: Int, _ r: PxRect, W: Double) -> (side: Double, bottom: Double) {
        guard isFramed(i), frame.hasEdge else { return (0, 0) }
        let side = min(frameWidth * W / canvasWidth, min(r.w, r.h) * 0.12)
        switch frame {
        case .instant: return (side, min(side * 3.4, r.h * 0.3))
        case .torn: return (side * 1.2, side * 1.2)
        default: return (side, side)
        }
    }

    /// Corner radius of the picture in cell `i`: printed photos have small corners.
    func pictureRadius(_ i: Int, W: Double) -> Double {
        let r = cornerRadius(W: W)
        guard isFramed(i) else { return r }
        switch frame {
        case .torn: return 0
        case .shadow: return r
        default: return min(r, 3 * W / canvasWidth)
        }
    }
}

// MARK: - Carousel layouts

/// How the pictures are arranged across the slides. Every style is built so slide seams run through pictures:
/// half of a picture is on one slide, half on the next, which is what makes people swipe.
/// Flow and Square flow are one strip of joined pictures that are all the same shape (portrait 4:5, or square).
/// Scatter, Wave and Wall are random galleries: pictures of different sizes placed here and there. "Shuffle" deals a new arrangement.
enum CarouselStyle: String, CaseIterable, Identifiable {
    case panorama, flow, squareFlow, duo, stagger, mosaic, scatter, wave, wall
    var id: String { rawValue }
    var title: String {
        switch self {
        case .panorama: "Panorama"
        case .flow: "Flow"
        case .squareFlow: "Square flow"
        case .duo: "Two rows"
        case .stagger: "Stagger"
        case .mosaic: "Mosaic"
        case .scatter: "Scatter"
        case .wave: "Wave"
        case .wall: "Wall"
        }
    }
    /// Styles whose arrangement is dealt at random (and can be re-dealt).
    var isRandom: Bool { self == .scatter || self == .wave || self == .wall }

    /// The width ÷ height every picture keeps, for the styles whose pictures all share one shape.
    var stripAspect: Double? {
        switch self {
        case .flow: 4.0 / 5.0
        case .squareFlow: 1
        default: nil
        }
    }

    /// How many pictures share one slide on average. Roomy styles give each picture more width, so they need more slides.
    var photosPerSlide: Double {
        switch self {
        case .panorama: 0.5
        case .flow: 1.3
        case .squareFlow: 1.0
        case .duo: 2.6
        case .stagger: 2.6
        case .mosaic: 2.2
        case .scatter: 1.7
        case .wave: 1.4
        case .wall: 4.0
        }
    }
}

let carouselLayoutPrefix = "car:"

func carouselStyle(of layoutId: String) -> CarouselStyle? {
    guard layoutId.hasPrefix(carouselLayoutPrefix) else { return nil }
    let rest = layoutId.dropFirst(carouselLayoutPrefix.count)
    return CarouselStyle(rawValue: String(rest.split(separator: "#").first ?? ""))
}

/// Random styles carry their arrangement number in the id ("car:scatter#42").
func carouselSeed(of layoutId: String) -> Int {
    guard let tail = layoutId.split(separator: "#").dropFirst().first else { return 0 }
    return Int(tail) ?? 0
}

func carouselLayoutId(_ style: CarouselStyle, seed: Int = 0) -> String {
    carouselLayoutPrefix + style.rawValue + (style.isRandom && seed != 0 ? "#\(seed)" : "")
}

/// One picture can only be a panorama; two or more can't. A wall needs a few pictures to fill its three rows.
func carouselStyles(for count: Int) -> [CarouselStyle] {
    if count <= 1 { return [.panorama] }
    var styles: [CarouselStyle] = [.flow, .squareFlow, .duo, .stagger, .mosaic, .scatter, .wave]
    if count >= 4 { styles.append(.wall) }
    return styles
}

/// Slides for a number of pictures in a style: nobody chooses this.
func autoSlides(count n: Int, style: CarouselStyle, format: FormatId) -> Int {
    if let aspect = style.stripAspect { return stripPlan(count: n, aspect: aspect, format: format).slides }
    let raw = Int((Double(max(n, 1)) / style.photosPerSlide - 0.001).rounded(.up))
    return min(maxSlides, max(minSlides, raw))
}

/// One strip of joined pictures that all keep the same shape: how tall they are (a share of the slide height), how wide
/// each one is and where the strip starts (both in slides), and how many slides it spans.
struct StripPlan: Equatable {
    var slides: Int
    var height: Double
    var width: Double
    var start: Double
}

/// Plans a strip of `n` pictures, each `aspect` wide for 1 tall. Pictures are as tall as the slide when they can be; they
/// shrink a little, never below 85% (and the strip slides along) when that would put a slide seam on the join between two pictures,
/// because a seam that cuts through a picture is what makes people swipe.
func stripPlan(count n: Int, aspect: Double, format: FormatId) -> StripPlan {
    let n = max(1, n)
    let ratio = format.height / format.width
    let clearance = 0.15
    var best: (plan: StripPlan, score: Double)?
    var h = 1.0
    // pictures stay at least this tall (unless there are so many that the slide limit makes them smaller)
    while h >= 0.85 - 0.0001 {
        var height = h
        var w = aspect * height * ratio
        // never more slides than allowed: shrink the pictures to fit
        if Double(n) * w > Double(maxSlides) {
            w = Double(maxSlides) / Double(n)
            height = w / (aspect * ratio)
        }
        let total = Double(n) * w
        let slides = min(maxSlides, max(minSlides, Int((total - 0.0001).rounded(.up))))
        let slack = Double(slides) - total
        // try the strip centred first, then shifted towards either end
        for shift in [0.5, 0.35, 0.65, 0.2, 0.8, 0.05, 0.95] {
            let start = slack * shift
            var score = Double.infinity
            for i in 1..<max(n, 2) where i < n {
                let edge = start + Double(i) * w
                let seam = edge.rounded()
                if seam >= 1, seam <= Double(slides - 1) { score = min(score, abs(edge - seam)) }
            }
            let plan = StripPlan(slides: slides, height: height, width: w, start: start)
            if score >= clearance { return plan }
            // a taller picture wins a near tie: a seam a little close to a join beats a lot of empty space
            if best == nil || score > best!.score + 0.03 { best = (plan, score) }
        }
        if height < h { break }
        h -= 0.01
    }
    return best!.plan
}

/// The pictures of a strip, in reading order, in layout units (0...1 across all the slides).
func stripRects(_ plan: StripPlan, count n: Int) -> [LayoutRect] {
    let total = Double(plan.slides)
    let y = (1 - plan.height) / 2
    return (0..<max(1, n)).map { i in
        LayoutRect(x: (plan.start + Double(i) * plan.width) / total, y: y, w: plan.width / total, h: plan.height)
    }
}

/// The style a project starts in for its number of pictures.
func defaultCarouselStyle(count: Int) -> CarouselStyle {
    count <= 1 ? .panorama : .flow
}

func resolvedCarouselStyle(layoutId: String, count: Int) -> CarouselStyle {
    if let style = carouselStyle(of: layoutId), carouselStyles(for: count).contains(style) { return style }
    return defaultCarouselStyle(count: count)
}

// MARK: - Random numbers that repeat

/// A small seeded generator, so a "random" arrangement comes out the same every time it is drawn (preview, export, thumbnails).
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: Int, salt: Int) { state = UInt64(truncatingIfNeeded: seed &* 7919 &+ salt &* 104729) &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func value(_ lo: Double, _ hi: Double) -> Double { Double.random(in: lo...hi, using: &self) }
}

/// Column edges, in slides, for `m` columns across `slides` slides. They are spread evenly, shifted and varied a little so
/// widths differ, then nudged off the slide seams (whole numbers) so every seam cuts through a picture.
func seamSafeEdges(columns m: Int, slides: Int, shift: Double) -> [Double] {
    let total = Double(slides)
    guard m > 1 else { return [0, total] }
    let w = total / Double(m)
    var e: [Double] = [0]
    for i in 1..<m {
        e.append((Double(i) + shift) * w + (i % 2 == 0 ? -1 : 1) * 0.12 * w)
    }
    e.append(total)
    return nudgedOffSeams(e, total: total)
}

/// Column edges with random widths (some pictures wide, some narrow), also kept off the slide seams.
func randomEdges(columns m: Int, slides: Int, rng: inout SeededRNG) -> [Double] {
    let total = Double(slides)
    guard m > 1 else { return [0, total] }
    let weights = (0..<m).map { _ in rng.value(0.55, 1.5) }
    let sum = weights.reduce(0, +)
    var e: [Double] = [0]
    var acc = 0.0
    for w in weights.dropLast() {
        acc += w
        e.append(acc / sum * total)
    }
    e.append(total)
    return nudgedOffSeams(e, total: total)
}

/// Moves any inner edge that sits on (or right next to) a slide seam a little to the side, so the seam falls inside a picture.
private func nudgedOffSeams(_ edges: [Double], total: Double) -> [Double] {
    var e = edges
    let m = e.count - 1
    guard m > 1 else { return e }
    let w = total / Double(m)
    let clearance = 0.14
    let minWidth = min(0.12, w * 0.4)
    for i in 1..<m {
        let seam = e[i].rounded()
        guard seam >= 1, seam <= total - 1, abs(e[i] - seam) < clearance else { continue }
        let moved = seam + (e[i] >= seam ? clearance : -clearance)
        if moved - e[i - 1] >= minWidth, e[i + 1] - moved >= minWidth { e[i] = moved }
    }
    return e
}

/// How many slide seams (1 ... slides-1) end up exactly on the edge between two pictures in the same row. Zero is the goal.
func seamsOnEdges(_ layout: CollageLayout, slides: Int) -> Int {
    var hits = 0
    for seam in 1..<max(slides, 1) {
        let x = Double(seam) / Double(slides)
        let touching = layout.rects.contains { abs($0.x + $0.w - x) < 0.0005 || abs($0.x - x) < 0.0005 }
        let crossing = layout.rects.contains { $0.x < x - 0.0005 && $0.x + $0.w > x + 0.0005 }
        if touching && !crossing { hits += 1 }
    }
    return hits
}

private func row(_ edges: [Double], slides: Int, y: Double, h: Double) -> [LayoutRect] {
    let total = Double(slides)
    return (0..<edges.count - 1).map { i in
        LayoutRect(x: edges[i] / total, y: y, w: (edges[i + 1] - edges[i]) / total, h: h)
    }
}

/// Reading order: left to right across the slides, top to bottom, so the first photos land on the first slide.
private func readingOrder(_ rects: [LayoutRect]) -> [LayoutRect] {
    rects.sorted { a, b in
        let ax = a.x + a.w / 2, bx = b.x + b.w / 2
        return abs(ax - bx) > 0.0001 ? ax < bx : a.y < b.y
    }
}

func carouselLayout(_ style: CarouselStyle, count n: Int, slides S: Int, format: FormatId, seed: Int = 0) -> CollageLayout {
    let n = max(1, n)
    let id = carouselLayoutId(style, seed: seed)
    var rects: [LayoutRect]
    switch style {
    case .panorama:
        rects = [LayoutRect(x: 0, y: 0, w: 1, h: 1)]
    case .flow, .squareFlow:
        // one strip of joined pictures, all the same size and shape
        rects = stripRects(stripPlan(count: n, aspect: style.stripAspect ?? 1, format: format), count: n)
    case .duo:
        let top = (n + 1) / 2, bottom = n - top
        rects = row(seamSafeEdges(columns: top, slides: S, shift: 0), slides: S, y: 0, h: 0.5)
        if bottom > 0 { rects += row(seamSafeEdges(columns: bottom, slides: S, shift: 0.5), slides: S, y: 0.5, h: 0.5) }
        rects = readingOrder(rects)
    case .stagger:
        let top = max(1, n / 2), bottom = n - top
        rects = row(seamSafeEdges(columns: top, slides: S, shift: 0.25), slides: S, y: 0, h: 0.6)
        if bottom > 0 { rects += row(seamSafeEdges(columns: bottom, slides: S, shift: -0.25), slides: S, y: 0.6, h: 0.4) }
        rects = readingOrder(rects)
    case .mosaic:
        let columns = min(n, max((n + 1) / 2, Int((0.6 * Double(n)).rounded())))
        let splits = n - columns
        let edges = seamSafeEdges(columns: columns, slides: S, shift: 0)
        var split = Set<Int>()
        if splits > 0 {
            for j in 0..<splits { split.insert(min(columns - 1, Int((Double(j) + 0.5) * Double(columns) / Double(splits)))) }
        }
        rects = []
        var flip = false
        for c in 0..<columns {
            let x = edges[c] / Double(S), w = (edges[c + 1] - edges[c]) / Double(S)
            if split.contains(c) {
                let top = flip ? 0.45 : 0.55
                flip.toggle()
                rects.append(LayoutRect(x: x, y: 0, w: w, h: top))
                rects.append(LayoutRect(x: x, y: top, w: w, h: 1 - top))
            } else {
                rects.append(LayoutRect(x: x, y: 0, w: w, h: 1))
            }
        }
        rects = readingOrder(rects)
    case .scatter:
        // two loose rows: pictures of different widths and heights, with gaps above and below them
        var rng = SeededRNG(seed: seed, salt: n * 31 + S)
        let top = (n + 1) / 2, bottom = n - top
        let T = Double(S)
        let te = randomEdges(columns: top, slides: S, rng: &rng)
        let upper: [LayoutRect] = (0..<top).map { i in
            LayoutRect(x: te[i] / T, y: rng.value(0, 0.07), w: (te[i + 1] - te[i]) / T, h: rng.value(0.4, 0.55))
        }
        rects = upper
        if bottom > 0 {
            let be = randomEdges(columns: bottom, slides: S, rng: &rng)
            for j in 0..<bottom {
                let x0 = be[j] / T, x1 = be[j + 1] / T
                // sit below whichever pictures of the top row are above this one
                let limit = upper.filter { $0.x < x1 - 0.0001 && $0.x + $0.w > x0 + 0.0001 }.map { $0.y + $0.h }.max() ?? 0.5
                let y = limit + rng.value(0.01, 0.05)
                rects.append(LayoutRect(x: x0, y: y, w: x1 - x0, h: min(1 - y, rng.value(0.38, 0.55))))
            }
        }
        rects = readingOrder(rects)
    case .wave:
        // one row that rises and falls like a wave
        var rng = SeededRNG(seed: seed, salt: n * 37 + S)
        let T = Double(S)
        let e = randomEdges(columns: n, slides: S, rng: &rng)
        let phase = rng.value(0, 6.28)
        rects = (0..<n).map { i in
            let h = rng.value(0.55, 0.82)
            let y = (1 - h) * (0.5 + 0.5 * sin(Double(i) * 1.25 + phase))
            return LayoutRect(x: e[i] / T, y: y, w: (e[i + 1] - e[i]) / T, h: h)
        }
    case .wall:
        // three rows of pictures with different widths, like a gallery wall
        var rng = SeededRNG(seed: seed, salt: n * 41 + S)
        let T = Double(S)
        var counts = [n / 3, n / 3, n / 3]
        let extra = Int(rng.next() % 3)
        for k in 0..<(n % 3) { counts[(extra + k) % 3] += 1 }
        let rawHeights = (0..<3).map { _ in rng.value(0.28, 0.4) }
        let hSum = rawHeights.reduce(0, +)
        var y = 0.0
        rects = []
        for r in 0..<3 where counts[r] > 0 {
            let h = rawHeights[r] / hSum
            let e = randomEdges(columns: counts[r], slides: S, rng: &rng)
            rects += (0..<counts[r]).map { LayoutRect(x: e[$0] / T, y: y, w: (e[$0 + 1] - e[$0]) / T, h: h) }
            y += h
        }
        rects = readingOrder(rects)
    }
    return CollageLayout(id: id, name: style.title, rects: rects)
}

// MARK: - Resolving the layout of a project

/// The layout in use: one of the fixed collage layouts, or a carousel layout built for the current picture count.
func layout(for project: Project) -> CollageLayout {
    if project.mode == .carousel {
        let style = project.carouselStyleInUse
        return carouselLayout(style, count: project.cellCount, slides: project.slides, format: project.format, seed: carouselSeed(of: project.layoutId))
    }
    let base = layout(byId: project.layoutId)
    if let sizes = project.cellSizes, let grid = base.grid, grid.sameShape(sizes) {
        return CollageLayout(id: base.id, name: base.name, rects: sizes.rects, grid: sizes)
    }
    return base
}

/// Layouts to choose from for the project's current picture count. Each carousel style is shown with its own slide count.
func layoutOptions(for project: Project) -> [CollageLayout] {
    if project.mode == .carousel {
        return carouselStyles(for: project.cellCount).map {
            carouselLayout($0, count: project.cellCount, slides: autoSlides(count: project.cellCount, style: $0, format: project.format), format: project.format, seed: carouselSeed(of: project.layoutId))
        }
    }
    return layouts(for: project.cellCount)
}

/// The layout id a project should use when its counts change.
func defaultLayoutId(for project: Project) -> String {
    project.mode == .carousel
        ? carouselLayoutId(defaultCarouselStyle(count: project.cellCount))
        : defaultLayout(for: project.cellCount).id
}
