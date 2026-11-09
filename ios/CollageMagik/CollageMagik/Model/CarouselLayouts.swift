import Foundation

// MARK: - Carousel geometry

extension Project {
    /// The whole design, in "1080 wide" pixels: one slide for a collage, `slides` side by side for a carousel.
    var canvasWidth: Double { mode == .carousel ? format.width * Double(slides) : format.width }
    var canvasHeight: Double { format.height }
    var canvasAspect: Double { canvasWidth / canvasHeight }

    /// Cell rectangles for a canvas drawn `W` × `H` pixels wide.
    func cellRects(W: Double, H: Double) -> [PxRect] {
        cellPixelRects(layout(for: self).rects, W: W, H: H, gap: gap, unit: W / canvasWidth)
    }

    /// Corner radius for a canvas drawn `W` pixels wide.
    func cornerRadius(W: Double) -> Double { radius * W / canvasWidth }
}

// MARK: - Carousel layouts

/// How the pictures are arranged across the slides. Every style is built so slide seams run through pictures:
/// half of a picture is on one slide, half on the next, which is what makes people swipe.
enum CarouselStyle: String, CaseIterable, Identifiable {
    case panorama, flow, duo, stagger, mosaic
    var id: String { rawValue }
    var title: String {
        switch self {
        case .panorama: "Panorama"
        case .flow: "Flow"
        case .duo: "Two rows"
        case .stagger: "Stagger"
        case .mosaic: "Mosaic"
        }
    }
}

let carouselLayoutPrefix = "car:"

func carouselStyle(of layoutId: String) -> CarouselStyle? {
    layoutId.hasPrefix(carouselLayoutPrefix) ? CarouselStyle(rawValue: String(layoutId.dropFirst(carouselLayoutPrefix.count))) : nil
}

/// One picture can only be a panorama; two or more can't.
func carouselStyles(for count: Int) -> [CarouselStyle] {
    count <= 1 ? [.panorama] : [.flow, .duo, .stagger, .mosaic]
}

/// Slides for a number of pictures: about two pictures per slide.
func defaultSlides(forPhotos n: Int) -> Int { min(maxSlides, max(minSlides, (n + 1) / 2)) }

/// Rows of narrow pictures read badly, so crowded carousels start as two rows.
func defaultCarouselStyle(count: Int, slides: Int) -> CarouselStyle {
    if count <= 1 { return .panorama }
    return Double(slides) / Double(count) >= 0.6 ? .flow : .duo
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

func carouselLayout(_ style: CarouselStyle, count n: Int, slides S: Int) -> CollageLayout {
    let n = max(1, n)
    let id = carouselLayoutPrefix + style.rawValue
    var rects: [LayoutRect]
    switch style {
    case .panorama:
        rects = [LayoutRect(x: 0, y: 0, w: 1, h: 1)]
    case .flow:
        rects = row(seamSafeEdges(columns: n, slides: S, shift: 0), slides: S, y: 0, h: 1)
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
    }
    return CollageLayout(id: id, name: style.title, rects: rects)
}

// MARK: - Resolving the layout of a project

/// The layout in use: one of the fixed collage layouts, or a carousel layout built for the current picture and slide counts.
func layout(for project: Project) -> CollageLayout {
    if project.mode == .carousel {
        let style = carouselStyle(of: project.layoutId) ?? defaultCarouselStyle(count: project.cellCount, slides: project.slides)
        let valid = carouselStyles(for: project.cellCount).contains(style) ? style : defaultCarouselStyle(count: project.cellCount, slides: project.slides)
        return carouselLayout(valid, count: project.cellCount, slides: project.slides)
    }
    return layout(byId: project.layoutId)
}

/// Layouts to choose from for the project's current picture count.
func layoutOptions(for project: Project) -> [CollageLayout] {
    if project.mode == .carousel {
        return carouselStyles(for: project.cellCount).map { carouselLayout($0, count: project.cellCount, slides: project.slides) }
    }
    return layouts(for: project.cellCount)
}

/// The layout id a project should use when its counts change.
func defaultLayoutId(for project: Project) -> String {
    project.mode == .carousel
        ? carouselLayoutPrefix + defaultCarouselStyle(count: project.cellCount, slides: project.slides).rawValue
        : defaultLayout(for: project.cellCount).id
}
