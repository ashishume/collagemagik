import SwiftUI
import UIKit

// MARK: - Templates

/// What a template is for, shown as chips in the Templates browser.
enum TemplateCategory: String, CaseIterable, Identifiable {
    case photoDump, travel, birthday, love, friends, food, minimal, moodboard, beforeAfter, scrapbook

    var id: String { rawValue }
    var title: String {
        switch self {
        case .photoDump: "Photo dump"
        case .travel: "Travel"
        case .birthday: "Birthday"
        case .love: "Love"
        case .friends: "Friends"
        case .food: "Food"
        case .minimal: "Minimal"
        case .moodboard: "Moodboard"
        case .beforeAfter: "Before & after"
        case .scrapbook: "Scrapbook"
        }
    }
}

/// A ready-made design with empty picture slots: the layout, spacing, background, frame, and placeholder captions and
/// stickers. It never holds pictures; applying it puts the person's own pictures into its slots in order, and
/// everything stays editable afterwards.
struct DesignTemplate: Identifiable {
    let id: String
    let name: String
    let category: TemplateCategory
    let mode: EditMode
    var format: FormatId = .post
    /// Collage: a layout id from `allLayouts` (its cell count is the number of slots). Carousel: the strip style; the
    /// number of slots follows the pictures.
    var layoutId: String = ""
    var style: CarouselStyle = .flow
    var gap: Double = 0
    var radius: Double = 0
    var bg: String = "#101016"
    var backdrop = Backdrop()
    var frame: PhotoFrame = .none
    var frameColor: String = "#ffffff"
    var frameWidth: Double = 22
    var captions: [Caption] = []
    var stickers: [Sticker] = []

    /// Picture slots: fixed for a collage, the usual opening count for a carousel.
    var slots: Int { mode == .collage ? layout(byId: layoutId).count : initialCarouselCells }

    /// The design this template makes with these pictures (ids in order). A collage keeps its own slot count (spare
    /// pictures stay in the tray, missing ones leave empty slots); a carousel gets one slot per picture.
    func project(basedOn base: Project, pictures: [String]) -> Project {
        var p = base
        p.mode = mode
        p.format = format
        let count: Int
        if mode == .collage {
            count = layout(byId: layoutId).count
        } else {
            count = min(max(1, pictures.isEmpty ? initialCarouselCells : pictures.count), maxCarouselPhotos)
        }
        p.cellCount = count
        p.cells = (0..<count).map { CellState(mediaId: pictures.indices.contains($0) ? pictures[$0] : nil) }
        p.layoutId = mode == .collage ? layoutId : carouselLayoutId(carouselStyles(for: count).contains(style) ? style : defaultCarouselStyle(count: count))
        p.cellSizes = nil
        p.gap = gap
        p.radius = radius
        p.bg = bg
        p.backdrop = backdrop
        p.frame = frame
        p.frameColor = frameColor
        p.frameWidth = frameWidth
        // fresh ids, so applying the same template twice never shares a caption or sticker between designs
        p.captions = captions.map { var c = $0; c.id = UUID().uuidString; return c }
        p.stickers = stickers.map { var s = $0; s.id = UUID().uuidString; return s }
        if mode == .carousel { p.lanes = []; p.music = nil }
        return p
    }
}

// MARK: - The catalogue

private func caption(_ text: String, _ font: CaptionFont, x: Double = 0.5, y: Double, size: Double = 76,
                     color: String = "#ffffff", look: CaptionLook = .plain, rotation: Double = 0,
                     ornament: CaptionOrnament = .none, allCaps: Bool = false) -> Caption {
    var c = Caption()
    c.text = text
    c.font = font
    c.x = x
    c.y = y
    c.size = size
    c.color = color
    c.look = look
    c.rotation = rotation
    c.ornament = ornament
    c.allCaps = allCaps
    return c
}

private func emoji(_ e: String, x: Double, y: Double, w: Double = 0.14, tilt: Double = 0) -> Sticker {
    Sticker(kind: .emoji, content: e, cx: x, cy: y, w: w, tilt: tilt)
}

private func shape(_ symbol: String, color: String, x: Double, y: Double, w: Double = 0.1, tilt: Double = 0) -> Sticker {
    Sticker(kind: .shape, content: symbol, color: color, cx: x, cy: y, w: w, tilt: tilt)
}

private func gradient(_ index: Int) -> Backdrop { Backdrop(kind: .gradient, gradient: index) }
private func pattern(_ p: BackdropPattern) -> Backdrop { Backdrop(kind: .pattern, pattern: p.rawValue) }

/// Every template that ships with the app. Add one by adding an entry: the browser, previews and filters pick it up.
let allTemplates: [DesignTemplate] = [
    // MARK: Collages
    DesignTemplate(
        id: "c-photo-dump", name: "Photo dump", category: .photoDump, mode: .collage, format: .post,
        layoutId: "9-grid", gap: 8, bg: "#f4efe6",
        captions: [caption("photo dump", .typewriter, y: 0.5, size: 64, color: "#1b1b1f", look: .label)]
    ),
    DesignTemplate(
        id: "c-dump-story", name: "Story dump", category: .photoDump, mode: .collage, format: .story,
        layoutId: "7-hero", gap: 6, radius: 10, bg: "#111114",
        captions: [caption("this week ✦", .marker, y: 0.37, size: 70, look: .plate)]
    ),
    DesignTemplate(
        id: "c-travel-diary", name: "Travel diary", category: .travel, mode: .collage, format: .post,
        layoutId: "5-hero", gap: 14, radius: 18, backdrop: gradient(3),
        captions: [caption("Travel diary", .script, y: 0.07, size: 92, ornament: .swash)],
        stickers: [emoji("✈️", x: 0.9, y: 0.07, w: 0.1, tilt: -12)]
    ),
    DesignTemplate(
        id: "c-postcard", name: "Postcard", category: .travel, mode: .collage, format: .square,
        layoutId: "3-big-left", gap: 18, radius: 4, bg: "#efe6d8", frame: .border, frameColor: "#ffffff", frameWidth: 14,
        captions: [caption("greetings from", .typewriter, x: 0.3, y: 0.92, size: 46, color: "#3b2f2a")]
    ),
    DesignTemplate(
        id: "c-polaroid-wall", name: "Instant prints", category: .scrapbook, mode: .collage, format: .post,
        layoutId: "4-grid", gap: 44, bg: "#e9dfcf", backdrop: pattern(.dots), frame: .instant, frameColor: "#fbfaf6",
        captions: [caption("memories", .hand, y: 0.5, size: 84, color: "#3b2f2a", rotation: -4)],
        stickers: [shape("heart.fill", color: "#e2557a", x: 0.12, y: 0.06, w: 0.07, tilt: -14)]
    ),
    DesignTemplate(
        id: "c-torn-notes", name: "Torn notes", category: .scrapbook, mode: .collage, format: .post,
        layoutId: "3-big-top", gap: 26, bg: "#f2ead9", frame: .torn, frameColor: "#ffffff",
        captions: [caption("little things", .diary, x: 0.5, y: 0.53, size: 64, color: "#2e2a26", rotation: -3)],
        stickers: [emoji("🌼", x: 0.92, y: 0.08, w: 0.11, tilt: 10)]
    ),
    DesignTemplate(
        id: "c-birthday", name: "Birthday", category: .birthday, mode: .collage, format: .post,
        layoutId: "4-big-top", gap: 18, radius: 14, backdrop: gradient(1), frame: .border, frameWidth: 10,
        captions: [caption("Happy Birthday", .script, y: 0.47, size: 104, look: .plain, ornament: .sparkles)],
        stickers: [emoji("🎉", x: 0.1, y: 0.08, w: 0.13, tilt: -10), emoji("🎂", x: 0.9, y: 0.92, w: 0.13, tilt: 8)]
    ),
    DesignTemplate(
        id: "c-party", name: "Party night", category: .birthday, mode: .collage, format: .story,
        layoutId: "6-grid", gap: 10, radius: 20, backdrop: gradient(5),
        captions: [caption("PARTY", .poster, y: 0.5, size: 140, look: .outline, allCaps: true)],
        stickers: [emoji("🎈", x: 0.88, y: 0.06, w: 0.14, tilt: 12)]
    ),
    DesignTemplate(
        id: "c-you-and-me", name: "You & me", category: .love, mode: .collage, format: .post,
        layoutId: "2-side", gap: 22, radius: 22, backdrop: gradient(7),
        captions: [caption("you & me", .vows, y: 0.9, size: 96, ornament: .heart)],
        stickers: [emoji("❤️", x: 0.5, y: 0.08, w: 0.1)]
    ),
    DesignTemplate(
        id: "c-anniversary", name: "Anniversary", category: .love, mode: .collage, format: .story,
        layoutId: "3-rows", gap: 12, radius: 6, bg: "#fbf3ef", frame: .shadow,
        captions: [caption("forever", .signature, y: 0.5, size: 110, color: "#b23a5b")]
    ),
    DesignTemplate(
        id: "c-squad", name: "The squad", category: .friends, mode: .collage, format: .post,
        layoutId: "6-mix", gap: 6, bg: "#18181c",
        captions: [caption("the squad", .marker, y: 0.5, size: 90, look: .label)],
        stickers: [emoji("🔥", x: 0.9, y: 0.1, w: 0.12, tilt: 10)]
    ),
    DesignTemplate(
        id: "c-food", name: "Good food", category: .food, mode: .collage, format: .post,
        layoutId: "5-sandwich", gap: 12, radius: 26, backdrop: gradient(2),
        captions: [caption("good food, good mood", .hand, y: 0.5, size: 62, color: "#4a2a22", look: .label)]
    ),
    DesignTemplate(
        id: "c-minimal", name: "Clean white", category: .minimal, mode: .collage, format: .post,
        layoutId: "3-big-left", gap: 30, bg: "#ffffff",
        captions: [caption("2026", .typewriter, x: 0.5, y: 0.965, size: 34, color: "#1b1b1f")]
    ),
    DesignTemplate(
        id: "c-black-gallery", name: "Black gallery", category: .minimal, mode: .collage, format: .square,
        layoutId: "4-grid", gap: 36, bg: "#0b0b0d", frame: .border, frameColor: "#f4f1ea", frameWidth: 12
    ),
    DesignTemplate(
        id: "c-moodboard", name: "Moodboard", category: .moodboard, mode: .collage, format: .story,
        layoutId: "7-mix", gap: 10, radius: 8, bg: "#e9e2d6",
        captions: [caption("mood", .serif, x: 0.5, y: 0.5, size: 120, color: "#ffffff", look: .plain)],
        stickers: [emoji("✨", x: 0.9, y: 0.05, w: 0.1)]
    ),
    DesignTemplate(
        id: "c-before-after", name: "Before & after", category: .beforeAfter, mode: .collage, format: .post,
        layoutId: "2-side", gap: 6, bg: "#ffffff",
        captions: [
            caption("BEFORE", .poster, x: 0.25, y: 0.93, size: 58, look: .plate, allCaps: true),
            caption("AFTER", .poster, x: 0.75, y: 0.93, size: 58, look: .plate, allCaps: true),
        ]
    ),
    DesignTemplate(
        id: "c-glow-up", name: "Glow up", category: .beforeAfter, mode: .collage, format: .story,
        layoutId: "2-stack", gap: 8, backdrop: gradient(0),
        captions: [
            caption("then", .script, x: 0.18, y: 0.06, size: 80),
            caption("now", .script, x: 0.18, y: 0.56, size: 80),
        ]
    ),

    // MARK: Carousels
    DesignTemplate(
        id: "k-swipe-story", name: "Swipe story", category: .photoDump, mode: .carousel,
        style: .flow, backdrop: Backdrop(kind: .blur),
        captions: [caption("swipe →", .rounded, x: 0.82, y: 0.93, size: 46, look: .label)]
    ),
    DesignTemplate(
        id: "k-travel", name: "Where we went", category: .travel, mode: .carousel,
        style: .duo, gap: 10, radius: 14, backdrop: gradient(3),
        captions: [caption("where we went", .script, x: 0.5, y: 0.5, size: 96, look: .plain, ornament: .swash)]
    ),
    DesignTemplate(
        id: "k-scrapbook", name: "Scrapbook", category: .scrapbook, mode: .carousel,
        style: .scatter, bg: "#efe6d8", backdrop: pattern(.grid), frame: .instant, frameColor: "#fbfaf6",
        stickers: [emoji("✨", x: 0.12, y: 0.08, w: 0.1), emoji("📸", x: 1.88, y: 0.9, w: 0.12, tilt: 10)]
    ),
    DesignTemplate(
        id: "k-gallery", name: "Gallery wall", category: .minimal, mode: .carousel,
        style: .wall, gap: 18, bg: "#f4f1ec", frame: .border, frameColor: "#1b1b1f", frameWidth: 8
    ),
    DesignTemplate(
        id: "k-mosaic", name: "Mosaic dump", category: .photoDump, mode: .carousel,
        style: .mosaic, gap: 6, bg: "#0b0b0d",
        captions: [caption("recap", .marker, x: 0.5, y: 0.5, size: 110, look: .label)]
    ),
    DesignTemplate(
        id: "k-wave", name: "Summer wave", category: .friends, mode: .carousel,
        style: .wave, radius: 18, backdrop: gradient(6),
        captions: [caption("summer", .dreamy, x: 0.5, y: 0.1, size: 96, color: "#5a3a00")],
        stickers: [emoji("☀️", x: 0.9, y: 0.12, w: 0.12)]
    ),
]

func templates(for mode: EditMode?, category: TemplateCategory? = nil) -> [DesignTemplate] {
    allTemplates.filter { (mode == nil || $0.mode == mode) && (category == nil || $0.category == category) }
}

// MARK: - Previews

/// Pictures of templates for the browser: filled with the person's own pictures when there are some, otherwise with
/// soft sample scenes. Drawn by the same renderer as the editor and exports, so a template looks exactly as it will.
@MainActor
enum TemplatePreview {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(_ t: DesignTemplate, pictures: [MediaItem] = []) -> UIImage? {
        let photos = pictures.filter { $0.kind == .photo }
        let key = "\(t.id)|\(photos.map(\.id).joined(separator: ","))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let items = photos.isEmpty ? samples : photos
        let wanted = t.mode == .collage ? t.slots : max(min(items.count, maxCarouselPhotos), 3)
        let ids = (0..<wanted).map { items[$0 % items.count].id }
        let unique = t.mode == .collage ? ids : Array(ids.prefix(items.count))
        let project = t.project(basedOn: Project(), pictures: unique)
        let byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let maxSide = 520.0
        let k = maxSide / max(project.canvasWidth, project.canvasHeight)
        let w = max(1, Int((project.canvasWidth * k).rounded())), h = max(1, Int((project.canvasHeight * k).rounded()))
        guard let ctx = CollageRenderer.makeContext(width: w, height: h) else { return nil }
        CollageRenderer.draw(ctx: ctx, W: Double(w), H: Double(h), snapshot: ExportSnapshot(project: project, items: byId)) { id in
            guard let item = byId[id] else { return nil }
            return (item.preview ?? item.thumbnail).cgImage
        }
        guard let cg = ctx.makeImage() else { return nil }
        let img = UIImage(cgImage: cg)
        cache.setObject(img, forKey: key)
        return img
    }

    /// Stand-in pictures: a few calm colour scenes (sky, sun and hills), different enough to tell the slots apart.
    static let samples: [MediaItem] = {
        let palettes: [(String, String, String)] = [
            ("#ffb38a", "#ff6f91", "#5b2a86"), ("#9be7ff", "#3a86ff", "#1d3557"), ("#c3f0ca", "#57cc99", "#22577a"),
            ("#ffe29a", "#ffb347", "#8c3b2e"), ("#e0c3fc", "#8ec5fc", "#3d2c8d"), ("#fbc2eb", "#a18cd1", "#2d1e4f"),
            ("#f6d365", "#fda085", "#6a3d3d"), ("#a8edea", "#7fd1c2", "#2a6f6b"), ("#fddb92", "#d1fdff", "#4f6d7a"),
        ]
        return palettes.enumerated().map { i, p in
            let size = CGSize(width: 480, height: 600)
            let img = UIGraphicsImageRenderer(size: size).image { r in
                let c = r.cgContext
                let colors = [UIColor(hex: p.0).cgColor, UIColor(hex: p.1).cgColor] as CFArray
                if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: nil) {
                    c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
                }
                c.setFillColor(UIColor.white.withAlphaComponent(0.75).cgColor)
                let sun = 70.0 + Double(i % 3) * 14
                c.fillEllipse(in: CGRect(x: 90 + Double(i * 37 % 260), y: 120, width: sun, height: sun))
                c.setFillColor(UIColor(hex: p.2).withAlphaComponent(0.85).cgColor)
                let hill = UIBezierPath()
                hill.move(to: CGPoint(x: 0, y: size.height))
                hill.addLine(to: CGPoint(x: 0, y: size.height * 0.68))
                hill.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.62),
                                  controlPoint: CGPoint(x: size.width * (0.3 + Double(i % 4) * 0.12), y: size.height * 0.42))
                hill.addLine(to: CGPoint(x: size.width, y: size.height))
                hill.close()
                c.addPath(hill.cgPath)
                c.fillPath()
            }
            return MediaItem(id: "sample-\(i)", kind: .photo, url: URL(fileURLWithPath: "/dev/null"), name: "Sample",
                             width: Double(size.width), height: Double(size.height), duration: 0, hasAudio: false,
                             thumbnail: img, preview: img)
        }
    }()
}
