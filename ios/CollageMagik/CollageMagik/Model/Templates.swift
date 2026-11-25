import SwiftUI
import UIKit

// MARK: - Templates

/// What a template is for, shown as chips in the Templates browser.
enum TemplateCategory: String, CaseIterable, Identifiable {
    case motion, video, photoDump, party, beach, travel, birthday, love, dateNight, wedding, baby, friends, pets, food, fitness,
         graduation, holidays, business, quote, minimal, moodboard, beforeAfter, scrapbook

    var id: String { rawValue }
    var title: String {
        switch self {
        case .motion: String(localized: "Motion")
        case .video: String(localized: "With video")
        case .photoDump: String(localized: "Photo dump")
        case .party: String(localized: "Party")
        case .beach: String(localized: "Beach")
        case .dateNight: String(localized: "Date night")
        case .travel: String(localized: "Travel")
        case .birthday: String(localized: "Birthday")
        case .love: String(localized: "Love")
        case .wedding: String(localized: "Wedding")
        case .baby: String(localized: "Baby")
        case .pets: String(localized: "Pets")
        case .fitness: String(localized: "Fitness")
        case .graduation: String(localized: "Graduation")
        case .holidays: String(localized: "Holidays")
        case .business: String(localized: "Shop")
        case .quote: String(localized: "Quote")
        case .friends: String(localized: "Friends")
        case .food: String(localized: "Food")
        case .minimal: String(localized: "Minimal")
        case .moodboard: String(localized: "Moodboard")
        case .beforeAfter: String(localized: "Before & after")
        case .scrapbook: String(localized: "Scrapbook")
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
    /// More categories it shows under (a motion template stays in Motion and also shows under its theme).
    var tags: [TemplateCategory] = []
    let mode: EditMode
    var format: FormatId = .post
    /// Collage: a layout id from `allLayouts` (its cell count is the number of slots). Carousel: the strip style; the
    /// number of slots follows the pictures.
    var layoutId: String = ""
    var style: CarouselStyle = .flow
    var isLiving = false
    var gap: Double = 0
    var radius: Double = 0
    var bg: String = "#101016"
    var backdrop = Backdrop()
    var frame: PhotoFrame = .none
    var frameColor: String = "#ffffff"
    var frameWidth: Double = 22
    /// Frames for the pictures in turn (the first picture gets the first, and so on, repeating); empty = `frame` for all.
    var cellFrames: [PhotoFrame] = []
    /// A filter on every picture (a "look" for the whole design).
    var filter: PhotoFilter = .none
    var captions: [Caption] = []
    var stickers: [Sticker] = []
    /// A motion template: its pictures move through these scenes (collage only). Its layout is the last scene's.
    var motion: Motion? = nil

    /// Gives slot `index` the template's own frame and filter.
    func dress(_ cell: inout CellState, index: Int) {
        if !cellFrames.isEmpty { cell.frame = cellFrames[index % cellFrames.count] }
        if filter != .none { cell.look.filter = filter }
    }

    /// Picture slots: fixed for a collage, the usual opening count for a carousel.
    var slots: Int {
        if mode == .collage, let motion { return motion.slotCount }
        return mode == .collage ? layout(byId: layoutId).count : initialCarouselCells
    }

    /// The design this template makes with these pictures (ids in order). A collage keeps its own slot count (spare
    /// pictures stay in the tray, missing ones leave empty slots); a carousel gets one slot per picture.
    func project(basedOn base: Project, pictures: [String]) -> Project {
        var p = base
        p.mode = mode
        p.format = format
        let count: Int
        if mode == .collage {
            count = slots
        } else {
            count = min(max(1, pictures.isEmpty ? initialCarouselCells : pictures.count), maxCarouselPhotos)
        }
        p.cellCount = count
        p.cells = (0..<count).map { i in
            var c = CellState(mediaId: pictures.indices.contains(i) ? pictures[i] : nil)
            dress(&c, index: i)
            return c
        }
        p.layoutId = mode == .collage ? (layout(byId: layoutId).count == count ? layoutId : defaultLayout(for: count).id) : carouselLayoutId(carouselStyles(for: count).contains(style) ? style : defaultCarouselStyle(count: count))
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
        p.motion = mode == .collage ? motion : nil
        // a motion design sets its own length: its videos repeat to fill it
        if p.motion != nil { for i in p.lanes.indices { p.lanes[i].loop = true } }
        return p
    }
}

// MARK: - The catalogue

private func caption(_ text: String, _ font: CaptionFont, x: Double = 0.5, y: Double, size: Double = 76,
                     color: String = "#ffffff", look: CaptionLook = .plain, rotation: Double = 0,
                     ornament: CaptionOrnament = .none, allCaps: Bool = false, vertical: Bool = false,
                     mix: CaptionMix = .none, accent: CaptionFont = .diary) -> Caption {
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
    c.vertical = vertical
    c.mix = mix
    c.accentFont = accent
    return c
}

private func emoji(_ e: String, x: Double, y: Double, w: Double = 0.14, tilt: Double = 0) -> Sticker {
    Sticker(kind: .emoji, content: e, cx: x, cy: y, w: w, tilt: tilt)
}

private func shape(_ symbol: String, color: String, x: Double, y: Double, w: Double = 0.1, tilt: Double = 0) -> Sticker {
    Sticker(kind: .shape, content: symbol, color: color, cx: x, cy: y, w: w, tilt: tilt)
}

/// A caption shown only during scene `k` of a motion template.
private func sceneCaption(_ c: Caption, _ k: Int) -> Caption {
    var c = c
    c.scene = k
    return c
}

private func gradient(_ index: Int) -> Backdrop { Backdrop(kind: .gradient, gradient: index) }
private func pattern(_ p: BackdropPattern) -> Backdrop { Backdrop(kind: .pattern, pattern: p.rawValue) }

/// Every template that ships with the app. Add one by adding an entry: the browser, previews and filters pick it up.
let allTemplates: [DesignTemplate] = [
    // Motion templates: the pictures move through scenes. Clips go into the first slots; a picture in two scenes in a
    // row glides between its places. The last scene shows every picture (it is the design's still look).
    DesignTemplate(
        id: "living-weekend", name: String(localized: "weekend"), category: .motion, tags: [.photoDump], mode: .collage,
        format: .story, layoutId: "4-hero-prints", isLiving: true, bg: "#f0ddbe",
        frameColor: "#fff6e5", frameWidth: 18, cellFrames: [.shadow, .instant, .instant, .instant],
        captions: [caption(String(localized: "WEEKEND EDITION · NO. 12"), .typewriter, y: 0.05, size: 48, color: "#442b24")],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.4, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "4-hero-prints", slots: [0, 1, 2, 3], length: 4, transition: .fade, move: .zoomOut, entrance: .drop),
        ])
    ),
    DesignTemplate(
        id: "living-night", name: String(localized: "Neon nights"), category: .motion, tags: [.party, .friends], mode: .collage,
        format: .story, layoutId: "3-big-top", isLiving: true, gap: 14, radius: 18, bg: "#120d29",
        backdrop: gradient(5), frame: .neon, frameColor: "#a85eff", frameWidth: 16,
        captions: [caption(String(localized: "NEON NIGHTS"), .poster, y: 0.55, size: 80, color: "#e5b6ff", look: .neon)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.2, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [1], length: 1.8, transition: .slideUp, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [2], length: 1.8, transition: .zoom, move: .zoomIn),
            MotionScene(layoutId: "3-big-top", slots: [0, 1, 2], length: 3.6, transition: .fade, entrance: .pop),
        ])
    ),
    DesignTemplate(
        id: "living-before-after", name: String(localized: "Before & after"), category: .motion, tags: [.beforeAfter], mode: .collage,
        format: .post, layoutId: "2-side", isLiving: true, gap: 24, radius: 14, bg: "#102327",
        captions: [
            sceneCaption(caption(String(localized: "Before"), .rounded, y: 0.88, size: 62, look: .plate), 0),
            sceneCaption(caption(String(localized: "After"), .rounded, y: 0.88, size: 62, look: .plate), 1),
            sceneCaption(caption(String(localized: "Before & after"), .rounded, y: 0.88, size: 62, look: .plate), 2),
        ],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.4, move: .drift),
            MotionScene(layoutId: "1-full", slots: [1], length: 2.4, transition: .slideLeft, move: .drift),
            MotionScene(layoutId: "2-side", slots: [0, 1], length: 3.4, transition: .fade, entrance: .rise),
        ])
    ),
    DesignTemplate(
        id: "living-postcard", name: String(localized: "Postcards"), category: .motion, tags: [.travel], mode: .collage,
        format: .post, layoutId: "4-magazine", isLiving: true, bg: "#d5e7de", backdrop: pattern(.dots),
        frameColor: "#fff9ea", frameWidth: 14, cellFrames: [.border, .stamp, .stamp, .stamp],
        captions: [caption(String(localized: "greetings from"), .script, y: 0.08, size: 95, color: "#224d46", ornament: .swash)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.4, move: .zoomOut),
            MotionScene(layoutId: "4-magazine", slots: [0, 1, 2, 3], length: 3.8, transition: .fade, move: .zoomIn, entrance: .pop),
        ])
    ),
    DesignTemplate(
        id: "motion-spotlight", name: String(localized: "Spotlight"), category: .motion, mode: .collage,
        format: .story, layoutId: "3-big-top", isLiving: true, gap: 14, radius: 22, bg: "#0f0f14",
        captions: [
            sceneCaption(caption(String(localized: "the weekend"), .script, y: 0.82, size: 120), 0),
            sceneCaption(caption(String(localized: "BEST BITS"), .poster, y: 0.92, size: 64, look: .plate), 2),
        ],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.6, move: .zoomIn),
            MotionScene(layoutId: "2-stack", slots: [0, 1], length: 2.6, transition: .slideUp, move: .zoomIn),
            MotionScene(layoutId: "3-big-top", slots: [0, 1, 2], length: 3.6, transition: .fade, move: .zoomOut, entrance: .pop),
        ])
    ),
    DesignTemplate(
        id: "motion-trio", name: String(localized: "Trio"), category: .motion, mode: .collage,
        format: .story, layoutId: "3-rows", isLiving: true, gap: 10, radius: 16, bg: "#f4ecdc",
        captions: [caption(String(localized: "three of a kind"), .typewriter, y: 0.05, size: 44, color: "#2b2118")],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.2, move: .drift),
            MotionScene(layoutId: "1-full", slots: [1], length: 2.2, transition: .slideLeft, move: .drift),
            MotionScene(layoutId: "1-full", slots: [2], length: 2.2, transition: .zoom, move: .zoomIn),
            MotionScene(layoutId: "3-rows", slots: [0, 1, 2], length: 3.4, transition: .fade, entrance: .rise),
        ])
    ),
    DesignTemplate(
        id: "motion-split", name: String(localized: "Split open"), category: .motion, mode: .collage,
        format: .story, layoutId: "4-grid", isLiving: true, gap: 12, radius: 20, bg: "#16161c",
        captions: [sceneCaption(caption(String(localized: "it all adds up"), .rounded, y: 0.5, size: 70, look: .plate), 2)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.2, move: .zoomIn),
            MotionScene(layoutId: "2-stack", slots: [0, 1], length: 2.2, transition: .fade, move: .zoomIn),
            MotionScene(layoutId: "4-grid", slots: [0, 1, 2, 3], length: 3.4, transition: .fade, move: .zoomOut),
        ])
    ),
    DesignTemplate(
        id: "motion-dump", name: String(localized: "Photo dump"), category: .motion, tags: [.photoDump], mode: .collage,
        format: .story, layoutId: "6-grid", isLiving: true, gap: 8, radius: 10, bg: "#ffffff",
        captions: [sceneCaption(caption(String(localized: "photo dump"), .marker, y: 0.5, size: 110, color: "#ffffff", rotation: -4), 6)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 0.8, transition: .cut, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [1], length: 0.8, transition: .cut, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [2], length: 0.8, transition: .cut, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [3], length: 0.8, transition: .cut, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [4], length: 0.8, transition: .cut, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [5], length: 0.8, transition: .cut, move: .zoomIn),
            MotionScene(layoutId: "6-grid", slots: [0, 1, 2, 3, 4, 5], length: 3.4, transition: .fade, entrance: .pop),
        ])
    ),
    DesignTemplate(
        id: "motion-prints", name: String(localized: "Print drop"), category: .motion, tags: [.scrapbook], mode: .collage,
        format: .post, layoutId: "4-tossed", isLiving: true, bg: "#e8dccb", backdrop: pattern(.grid),
        frame: .instant, frameColor: "#fbfaf6", frameWidth: 16,
        captions: [caption(String(localized: "developed today"), .note, y: 0.94, size: 54, color: "#4a3527")],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-tilt", slots: [0], length: 2.4, move: .zoomIn, entrance: .drop),
            MotionScene(layoutId: "4-tossed", slots: [0, 1, 2, 3], length: 4, transition: .fade, entrance: .drop),
        ])
    ),
    DesignTemplate(
        id: "motion-film", name: String(localized: "Film reel"), category: .motion, tags: [.photoDump], mode: .collage,
        format: .story, layoutId: "3-filmstrip", isLiving: true, bg: "#141416", frame: .film, frameColor: "#101016", frameWidth: 22,
        filter: .film,
        captions: [caption(String(localized: "roll 01"), .typewriter, y: 0.05, size: 40, color: "#ff9a3c")],
        motion: Motion(scenes: [
            MotionScene(layoutId: "3-filmstrip", slots: [0, 1, 2], length: 2.8, move: .drift, entrance: .rise),
            MotionScene(layoutId: "1-centre", slots: [1], length: 2.4, transition: .zoom, move: .zoomIn),
            MotionScene(layoutId: "3-filmstrip", slots: [2, 0, 1], length: 3.2, transition: .fade, move: .drift),
        ])
    ),
    DesignTemplate(
        id: "motion-recap", name: String(localized: "Weekend recap"), category: .motion, tags: [.photoDump], mode: .collage,
        format: .story, layoutId: "5-hero", isLiving: true, gap: 10, radius: 14, bg: "#fdf1e4", backdrop: gradient(2),
        captions: [
            sceneCaption(caption(String(localized: "weekend\nrecap"), .poster, y: 0.18, size: 120, color: "#2b1a12"), 0),
            sceneCaption(caption(String(localized: "see you next time"), .script, y: 0.5, size: 80), 1),
        ],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.6, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "5-hero", slots: [0, 1, 2, 3, 4], length: 4.2, transition: .fade, move: .zoomOut, entrance: .rise),
        ])
    ),
    DesignTemplate(
        id: "motion-shuffle", name: String(localized: "Shuffle"), category: .motion, mode: .collage,
        format: .square, layoutId: "4-big-top", isLiving: true, gap: 10, radius: 16, bg: "#1b1030", backdrop: gradient(4),
        motion: Motion(scenes: [
            MotionScene(layoutId: "4-grid", slots: [0, 1, 2, 3], length: 2.2, entrance: .pop),
            MotionScene(layoutId: "4-grid", slots: [3, 0, 1, 2], length: 1.8, transition: .fade),
            MotionScene(layoutId: "4-grid", slots: [2, 3, 0, 1], length: 1.8, transition: .fade),
            MotionScene(layoutId: "4-big-top", slots: [0, 1, 2, 3], length: 3.2, transition: .fade, move: .zoomIn),
        ])
    ),

    DesignTemplate(
        id: "motion-side-by-side", name: String(localized: "Side by side"), category: .motion, mode: .collage,
        format: .square, layoutId: "2-side", isLiving: true, gap: 20, radius: 14, bg: "#151a20",
        motion: Motion(scenes: [
            MotionScene(layoutId: "2-stack", slots: [0, 1], length: 2.2, move: .drift),
            MotionScene(layoutId: "2-side", slots: [0, 1], length: 3.2),
        ], transitionLength: 0.8)
    ),
    DesignTemplate(
        id: "motion-staircase", name: String(localized: "Staircase"), category: .motion, mode: .collage,
        format: .story, layoutId: "3-stairs", isLiving: true, gap: 8, radius: 18, bg: "#172723",
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 1.5, move: .zoomIn),
            MotionScene(layoutId: "2-overlap", slots: [0, 1], length: 1.6, transition: .slideUp),
            MotionScene(layoutId: "3-stairs", slots: [0, 1, 2], length: 3.0, move: .drift, entrance: .rise),
        ], transitionLength: 0.55)
    ),
    DesignTemplate(
        id: "motion-lookbook", name: String(localized: "Lookbook"), category: .motion, tags: [.moodboard], mode: .collage,
        format: .post, layoutId: "4-magazine", isLiving: true, gap: 10, bg: "#f1ece3",
        frame: .border, frameColor: "#fffdf8", frameWidth: 10,
        captions: [sceneCaption(caption(String(localized: "LOOKBOOK"), .magazine, y: 0.085, size: 66, color: "#211b18"), 3)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "2-side", slots: [0, 1], length: 1.4),
            MotionScene(layoutId: "2-side", slots: [2, 3], length: 1.4, transition: .cut),
            MotionScene(layoutId: "1-centre", slots: [1], length: 1.8, transition: .cut, move: .zoomOut),
            MotionScene(layoutId: "4-magazine", slots: [1, 0, 2, 3], length: 3.4, entrance: .rise),
        ], transitionLength: 0.45)
    ),
    DesignTemplate(
        id: "motion-gallery-wall", name: String(localized: "Gallery wall"), category: .motion, tags: [.minimal], mode: .collage,
        format: .post, layoutId: "6-wall", isLiving: true, bg: "#ebe2d6",
        frame: .gallery, frameColor: "#faf6ed", frameWidth: 14,
        captions: [sceneCaption(caption(String(localized: "the good days"), .magazine, y: 0.82, size: 84, color: "#403329"), 2)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "3-rows", slots: [0, 1, 2], length: 1.8, move: .drift),
            MotionScene(layoutId: "3-rows", slots: [3, 4, 5], length: 1.8, transition: .slideLeft, move: .drift),
            MotionScene(layoutId: "6-wall", slots: [0, 1, 2, 3, 4, 5], length: 3.4, entrance: .drop),
        ], transitionLength: 0.6)
    ),
    DesignTemplate(
        id: "motion-pinboard", name: String(localized: "Pinboard"), category: .motion, tags: [.moodboard], mode: .collage,
        format: .story, layoutId: "7-board", isLiving: true, bg: "#f4e2c3", backdrop: pattern(.grid),
        frameColor: "#fff8e9", frameWidth: 12, cellFrames: [.tape, .instant, .border],
        motion: Motion(scenes: [
            MotionScene(layoutId: "2-pile", slots: [0, 1], length: 1.6, entrance: .drop),
            MotionScene(layoutId: "4-zigzag", slots: [0, 1, 2, 3], length: 2.0, entrance: .drop),
            MotionScene(layoutId: "7-board", slots: [0, 1, 2, 3, 4, 5, 6], length: 3.5, entrance: .drop),
        ], transitionLength: 0.65)
    ),
    DesignTemplate(
        id: "motion-heart-of-photos", name: String(localized: "Heart of photos"), category: .motion, tags: [.love], mode: .collage,
        format: .post, layoutId: "8-heart", isLiving: true, bg: "#f9e5e9",
        frame: .circle,
        motion: Motion(scenes: [
            MotionScene(layoutId: "2-side", slots: [0, 1], length: 1.6, move: .zoomOut),
            MotionScene(layoutId: "4-cluster", slots: [0, 1, 2, 3], length: 1.8, entrance: .pop),
            MotionScene(layoutId: "8-heart", slots: [2, 3, 4, 0, 5, 1, 6, 7], length: 3.6, entrance: .rise),
        ], transitionLength: 0.65)
    ),

    // MARK: Themed motion templates (also listed under their theme through `tags`)

    // Party
    DesignTemplate(
        id: "motion-party-starter", name: String(localized: "Party starter"), category: .motion, tags: [.party], mode: .collage,
        format: .story, layoutId: "4-grid", isLiving: true, gap: 12, radius: 18, backdrop: gradient(5),
        frame: .neon, frameColor: "#ff4fd8", frameWidth: 14, filter: .vivid,
        captions: [
            sceneCaption(caption(String(localized: "night out"), .retro, y: 0.86, size: 100, color: "#ff4fd8", look: .neon), 0),
            sceneCaption(caption(String(localized: "PARTY"), .poster, y: 0.5, size: 150, look: .outline, allCaps: true), 4),
        ],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 1.2, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "1-full", slots: [1], length: 0.9, transition: .cut, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "1-full", slots: [2], length: 0.9, transition: .cut, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "1-full", slots: [3], length: 0.9, transition: .cut, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "4-grid", slots: [0, 1, 2, 3], length: 3.4, entrance: .spin),
        ])
    ),
    DesignTemplate(
        id: "motion-confetti-pop", name: String(localized: "Confetti pop"), category: .motion, tags: [.party, .birthday], mode: .collage,
        format: .post, layoutId: "5-pile", isLiving: true, bg: "#1b1030", backdrop: pattern(.confetti),
        frame: .instant, frameColor: "#ffffff", frameWidth: 16, filter: .vivid,
        captions: [sceneCaption(caption(String(localized: "best night\nEVER"), .retro, y: 0.5, size: 110, color: "#ff4fd8", look: .neon,
                                        mix: .tail, accent: .poster), 2)],
        stickers: [emoji("🎉", x: 0.9, y: 0.06, w: 0.11, tilt: 12)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-tilt", slots: [0], length: 2.0, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "2-pile", slots: [0, 1], length: 1.8, entrance: .spin),
            MotionScene(layoutId: "5-pile", slots: [0, 1, 2, 3, 4], length: 3.8, entrance: .spin),
        ])
    ),
    DesignTemplate(
        id: "motion-dance-floor", name: String(localized: "Dance floor"), category: .motion, tags: [.party], mode: .collage,
        format: .story, layoutId: "6-grid", isLiving: true, gap: 8, radius: 10, bg: "#07070b",
        frame: .neon, frameColor: "#3de0ff", frameWidth: 12, filter: .chrome,
        captions: [sceneCaption(caption(String(localized: "DANCE ALL NIGHT"), .poster, y: 0.5, size: 96, color: "#3de0ff", look: .neon,
                                        allCaps: true), 6)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 0.8, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "1-full", slots: [1], length: 0.7, transition: .cut, move: .zoomIn, entrance: .spin),
            MotionScene(layoutId: "1-full", slots: [2], length: 0.7, transition: .cut, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "1-full", slots: [3], length: 0.7, transition: .cut, move: .zoomIn, entrance: .spin),
            MotionScene(layoutId: "1-full", slots: [4], length: 0.7, transition: .cut, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "1-full", slots: [5], length: 0.7, transition: .cut, move: .zoomIn, entrance: .spin),
            MotionScene(layoutId: "6-grid", slots: [0, 1, 2, 3, 4, 5], length: 3.4, entrance: .pop),
        ])
    ),
    DesignTemplate(
        id: "motion-disco", name: String(localized: "Disco fever"), category: .motion, tags: [.party], mode: .collage,
        format: .square, layoutId: "4-cluster", isLiving: true, backdrop: gradient(0), frame: .circle, filter: .vivid,
        captions: [sceneCaption(caption(String(localized: "Disco fever"), .retro, y: 0.5, size: 100, color: "#ffd6f5", look: .neon), 4)],
        stickers: [emoji("🪩", x: 0.88, y: 0.1, w: 0.13, tilt: 10)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "4-cluster", slots: [0, 1, 2, 3], length: 2.0, entrance: .spin),
            MotionScene(layoutId: "4-cluster", slots: [3, 0, 1, 2], length: 1.3),
            MotionScene(layoutId: "4-cluster", slots: [2, 3, 0, 1], length: 1.3),
            MotionScene(layoutId: "4-cluster", slots: [1, 2, 3, 0], length: 1.3),
            MotionScene(layoutId: "4-cluster", slots: [0, 1, 2, 3], length: 3.0, move: .zoomIn),
        ], transitionLength: 0.9)
    ),
    DesignTemplate(
        id: "motion-house-party", name: String(localized: "House party"), category: .motion, tags: [.party, .friends], mode: .collage,
        format: .story, layoutId: "6-mix", isLiving: true, gap: 10, bg: "#ffd23f",
        frame: .border, frameColor: "#101016", frameWidth: 10, filter: .vivid,
        captions: [sceneCaption(caption(String(localized: "House party"), .poster, y: 0.56, size: 110, color: "#101016", look: .sticker,
                                        rotation: -4, allCaps: true), 2)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "2-stack", slots: [0, 1], length: 1.8, entrance: .slide),
            MotionScene(layoutId: "3-rows", slots: [0, 1, 2], length: 1.8, entrance: .slide),
            MotionScene(layoutId: "6-mix", slots: [0, 1, 2, 3, 4, 5], length: 3.4, entrance: .slam),
        ])
    ),
    DesignTemplate(
        id: "motion-cheers", name: String(localized: "Cheers"), category: .motion, tags: [.party], mode: .collage,
        format: .post, layoutId: "3-big-top", isLiving: true, gap: 16, radius: 12, backdrop: gradient(6),
        frame: .shadow, filter: .warm,
        captions: [
            sceneCaption(caption(String(localized: "Cheers"), .script, y: 0.5, size: 130, ornament: .sparkles), 0),
            sceneCaption(caption(String(localized: "good vibes"), .vows, y: 0.6, size: 90), 2),
        ],
        stickers: [emoji("🥂", x: 0.9, y: 0.08, w: 0.11, tilt: 12)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "2-side", slots: [0, 1], length: 2.2, entrance: .slide),
            MotionScene(layoutId: "1-centre", slots: [2], length: 2.0, transition: .zoom, move: .zoomIn),
            MotionScene(layoutId: "3-big-top", slots: [2, 0, 1], length: 3.6, move: .zoomOut, entrance: .rise),
        ])
    ),

    // Beach
    DesignTemplate(
        id: "motion-beach-day", name: String(localized: "Beach day"), category: .motion, tags: [.beach], mode: .collage,
        format: .story, layoutId: "4-tossed", isLiving: true, backdrop: gradient(3),
        frame: .instant, frameColor: "#fff9ee", frameWidth: 16, filter: .warm,
        captions: [
            sceneCaption(caption(String(localized: "Beach day"), .hand, y: 0.9, size: 110, rotation: -4), 0),
            sceneCaption(caption(String(localized: "summer memories"), .hand, y: 0.5, size: 76, color: "#ff7a59", look: .label, rotation: -4), 2),
        ],
        stickers: [emoji("☀️", x: 0.88, y: 0.035, w: 0.1), emoji("🐚", x: 0.12, y: 0.965, w: 0.09, tilt: -10)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-tilt", slots: [0], length: 2.2, move: .sway, entrance: .drop),
            MotionScene(layoutId: "3-tossed", slots: [0, 1, 2], length: 2.4, move: .sway, entrance: .slide),
            MotionScene(layoutId: "4-tossed", slots: [0, 1, 2, 3], length: 3.6, move: .sway, entrance: .drop),
        ])
    ),
    DesignTemplate(
        id: "motion-salt-water", name: String(localized: "Salt water"), category: .motion, tags: [.beach], mode: .collage,
        format: .post, layoutId: "4-band", isLiving: true, gap: 14, radius: 20, backdrop: gradient(4), filter: .cool,
        captions: [
            sceneCaption(caption(String(localized: "Salt water"), .script, y: 0.84, size: 130), 0),
            sceneCaption(caption(String(localized: "summer"), .dreamy, y: 0.5, size: 110, color: "#0b6e7a", look: .sticker), 2),
        ],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.4, move: .drift),
            MotionScene(layoutId: "2-side", slots: [0, 1], length: 2.2, transition: .slideLeft, move: .drift),
            MotionScene(layoutId: "4-band", slots: [0, 1, 2, 3], length: 3.4, entrance: .rise),
        ])
    ),
    DesignTemplate(
        id: "motion-sunset-waves", name: String(localized: "Sunset waves"), category: .motion, tags: [.beach, .travel], mode: .collage,
        format: .story, layoutId: "3-rows", isLiving: true, gap: 12, radius: 24, backdrop: gradient(1), filter: .warm,
        captions: [
            sceneCaption(caption(String(localized: "golden hour"), .romance, y: 0.86, size: 120, color: "#fff3e0"), 0),
            sceneCaption(caption(String(localized: "Sunset waves"), .script, y: 0.333, size: 96, color: "#fff3e0", look: .plate), 2),
        ],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.6, move: .zoomOut),
            MotionScene(layoutId: "1-full", slots: [1], length: 2.2, transition: .slideUp, move: .zoomOut),
            MotionScene(layoutId: "3-rows", slots: [0, 1, 2], length: 3.6, entrance: .slide),
        ])
    ),
    DesignTemplate(
        id: "motion-beach-club", name: String(localized: "Beach club"), category: .motion, tags: [.beach], mode: .collage,
        format: .square, layoutId: "3-cols", isLiving: true, gap: 18, radius: 80, bg: "#f7efe0", backdrop: pattern(.stripes),
        filter: .vivid,
        captions: [sceneCaption(caption(String(localized: "Beach club"), .retro, y: 0.5, size: 96, color: "#e2552b", look: .sticker,
                                        rotation: -6), 1)],
        stickers: [emoji("🌴", x: 0.12, y: 0.1, w: 0.13, tilt: -8), emoji("☀️", x: 0.88, y: 0.1, w: 0.13)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.2, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "3-cols", slots: [1, 0, 2], length: 3.6, entrance: .slide),
        ])
    ),
    DesignTemplate(
        id: "motion-island-time", name: String(localized: "Island time"), category: .motion, tags: [.beach, .travel], mode: .collage,
        format: .post, layoutId: "6-wall", isLiving: true, bg: "#0f6e6e",
        frame: .stamp, frameColor: "#fff8ea", frameWidth: 16, filter: .vintage,
        captions: [
            sceneCaption(caption(String(localized: "Island time"), .note, y: 0.87, size: 80, color: "#fff8ea", rotation: -3), 1),
            sceneCaption(caption(String(localized: "wish you were here"), .script, y: 0.83, size: 90, color: "#fff8ea"), 2),
        ],
        stickers: [emoji("🌴", x: 0.9, y: 0.92, w: 0.12, tilt: 8)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-tilt", slots: [0], length: 2.2, move: .drift, entrance: .drop),
            MotionScene(layoutId: "3-fan", slots: [1, 0, 2], length: 2.6, move: .sway, entrance: .rise),
            MotionScene(layoutId: "6-wall", slots: [0, 1, 2, 3, 4, 5], length: 3.6, entrance: .drop),
        ])
    ),
    DesignTemplate(
        id: "motion-surf-club", name: String(localized: "Surf club"), category: .motion, tags: [.beach], mode: .collage,
        format: .story, layoutId: "4-big-top", isLiving: true, gap: 8, bg: "#f4e9d8", filter: .film,
        captions: [sceneCaption(caption(String(localized: "Surf club"), .poster, y: 0.55, size: 120, color: "#e2552b", look: .sticker,
                                        allCaps: true), 2)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 1.8, move: .drift),
            MotionScene(layoutId: "2-stack", slots: [0, 1], length: 1.8, transition: .slideUp, move: .drift),
            MotionScene(layoutId: "4-big-top", slots: [0, 1, 2, 3], length: 3.6, entrance: .slide),
        ])
    ),
    DesignTemplate(
        id: "motion-poolside", name: String(localized: "Poolside"), category: .motion, tags: [.beach, .friends], mode: .collage,
        format: .square, layoutId: "4-offset", isLiving: true, bg: "#3ec6e0",
        frame: .tape, frameColor: "#ffffff", frameWidth: 12, filter: .vivid,
        captions: [sceneCaption(caption(String(localized: "Poolside"), .retro, x: 0.2, y: 0.84, size: 72, color: "#ff5fa2", look: .sticker,
                                        rotation: -6), 0)],
        stickers: [emoji("🍹", x: 0.91, y: 0.05, w: 0.08, tilt: 10)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "2-overlap", slots: [0, 1], length: 2.4, move: .sway, entrance: .slide),
            MotionScene(layoutId: "4-offset", slots: [0, 1, 2, 3], length: 3.6, entrance: .rise),
        ])
    ),

    // Love
    DesignTemplate(
        id: "motion-love-letter", name: String(localized: "Love letter"), category: .motion, tags: [.love, .dateNight], mode: .collage,
        format: .post, layoutId: "3-tossed", isLiving: true, bg: "#f7e6e3", backdrop: pattern(.hearts),
        frameColor: "#ffffff", frameWidth: 16, cellFrames: [.instant, .instant, .tape], filter: .warm,
        captions: [
            sceneCaption(caption(String(localized: "with love"), .signature, y: 0.9, size: 100, color: "#b23a5b"), 0),
            sceneCaption(caption(String(localized: "you & me"), .signature, x: 0.8, y: 0.14, size: 80, color: "#b23a5b", rotation: 8), 2),
        ],
        stickers: [shape("heart.fill", color: "#e2557a", x: 0.86, y: 0.88, w: 0.08, tilt: 12)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-tilt", slots: [0], length: 2.4, move: .zoomIn, entrance: .drop),
            MotionScene(layoutId: "2-pile", slots: [0, 1], length: 2.2, move: .sway, entrance: .drop),
            MotionScene(layoutId: "3-tossed", slots: [0, 1, 2], length: 3.8, move: .sway, entrance: .drop),
        ])
    ),
    DesignTemplate(
        id: "motion-heartbeat", name: String(localized: "Heartbeat"), category: .motion, tags: [.love], mode: .collage,
        format: .post, layoutId: "4-cluster", isLiving: true, backdrop: gradient(7), frame: .heart, filter: .vivid,
        captions: [sceneCaption(caption(String(localized: "be mine"), .script, y: 0.042, size: 76), 3)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 1.0, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "1-centre", slots: [1], length: 1.0, transition: .cut, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "1-centre", slots: [2], length: 1.0, transition: .cut, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "4-cluster", slots: [0, 1, 2, 3], length: 3.8, move: .sway, entrance: .pop),
        ])
    ),
    DesignTemplate(
        id: "motion-only-you", name: String(localized: "Only you"), category: .motion, tags: [.love, .dateNight], mode: .collage,
        format: .square, layoutId: "2-overlap", isLiving: true, bg: "#1a1418",
        frame: .border, frameColor: "#ffffff", frameWidth: 12, filter: .fade,
        captions: [
            sceneCaption(caption(String(localized: "you, always"), .signature, y: 0.86, size: 100, color: "#ffd6e7"), 0),
            sceneCaption(caption(String(localized: "you + me"), .signature, x: 0.2, y: 0.84, size: 84, color: "#ffd6e7", rotation: -6), 2),
        ],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.4, move: .drift),
            MotionScene(layoutId: "1-full", slots: [1], length: 2.2, transition: .slideLeft, move: .drift),
            MotionScene(layoutId: "2-overlap", slots: [0, 1], length: 3.6, entrance: .pop),
        ])
    ),
    DesignTemplate(
        id: "motion-forever-us", name: String(localized: "Forever us"), category: .motion, tags: [.love, .wedding], mode: .collage,
        format: .story, layoutId: "3-cols", isLiving: true, gap: 18, bg: "#fbf3ef", frame: .arch, filter: .warm,
        captions: [sceneCaption(caption(String(localized: "forever"), .signature, y: 0.9, size: 130, color: "#b23a5b"), 0)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.4, move: .zoomOut, entrance: .rise),
            MotionScene(layoutId: "2-side", slots: [0, 1], length: 2.2, entrance: .rise),
            MotionScene(layoutId: "3-cols", slots: [0, 1, 2], length: 3.6, entrance: .rise),
        ])
    ),
    DesignTemplate(
        id: "motion-rose-petals", name: String(localized: "Rose petals"), category: .motion, tags: [.love], mode: .collage,
        format: .post, layoutId: "4-zigzag", isLiving: true, backdrop: gradient(2), frame: .heart, filter: .warm,
        captions: [sceneCaption(caption(String(localized: "love"), .romance, x: 0.24, y: 0.88, size: 90, color: "#b23a5b"), 1)],
        stickers: [emoji("🌹", x: 0.8, y: 0.12, w: 0.1, tilt: 12)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.2, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "4-zigzag", slots: [0, 1, 2, 3], length: 3.8, move: .sway, entrance: .drop),
        ])
    ),
    DesignTemplate(
        id: "motion-then-now", name: String(localized: "Then & now"), category: .motion, tags: [.love, .beforeAfter], mode: .collage,
        format: .story, layoutId: "2-stack", isLiving: true, gap: 10, bg: "#120d0f", filter: .film,
        captions: [
            sceneCaption(caption(String(localized: "then"), .script, y: 0.86, size: 140), 0),
            sceneCaption(caption(String(localized: "now"), .script, y: 0.86, size: 140), 1),
            sceneCaption(caption(String(localized: "forever"), .signature, y: 0.5, size: 110, color: "#ffd6e7", look: .plate), 2),
        ],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.4, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [1], length: 2.4, transition: .slideUp, move: .zoomIn),
            MotionScene(layoutId: "2-stack", slots: [0, 1], length: 3.4, entrance: .rise),
        ])
    ),

    // Date night
    DesignTemplate(
        id: "motion-date-night", name: String(localized: "Date night"), category: .motion, tags: [.dateNight, .love], mode: .collage,
        format: .story, layoutId: "3-big-top", isLiving: true, gap: 10, radius: 14, bg: "#140d12", filter: .film,
        captions: [
            sceneCaption(caption(String(localized: "Date night"), .vows, y: 0.85, size: 120, ornament: .heart), 0),
            sceneCaption(caption(String(localized: "just us"), .signature, y: 0.6, size: 100, color: "#ff6fa8", look: .neon), 2),
        ],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.2, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [1], length: 2.0, transition: .zoom, move: .zoomIn),
            MotionScene(layoutId: "3-big-top", slots: [1, 0, 2], length: 3.6, move: .zoomOut, entrance: .rise),
        ])
    ),
    DesignTemplate(
        id: "motion-dinner-for-two", name: String(localized: "Dinner for two"), category: .motion, tags: [.dateNight, .food], mode: .collage,
        format: .post, layoutId: "3-big-left", isLiving: true, gap: 14, bg: "#2a1a14",
        frame: .gallery, frameColor: "#f6ead7", frameWidth: 14, filter: .warm,
        captions: [sceneCaption(caption(String(localized: "Dinner for two"), .serif, y: 0.1, size: 70, color: "#f6ead7"), 1)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "2-side", slots: [0, 1], length: 2.4, entrance: .slide),
            MotionScene(layoutId: "1-centre", slots: [2], length: 2.0, transition: .zoom, move: .zoomIn),
            MotionScene(layoutId: "3-big-left", slots: [2, 0, 1], length: 3.6, entrance: .rise),
        ])
    ),
    DesignTemplate(
        id: "motion-movie-night", name: String(localized: "Movie night"), category: .motion, tags: [.dateNight, .friends], mode: .collage,
        format: .post, layoutId: "4-big-top", isLiving: true, gap: 12, bg: "#7a0d12",
        frame: .border, frameColor: "#f6e7c1", frameWidth: 10, filter: .film,
        captions: [
            sceneCaption(caption(String(localized: "NOW SHOWING"), .poster, y: 0.1, size: 66, color: "#ffd84d", allCaps: true), 0),
            sceneCaption(caption(String(localized: "Movie night"), .retro, y: 0.55, size: 100, color: "#ffd84d", look: .neon), 2),
        ],
        stickers: [emoji("🍿", x: 0.9, y: 0.93, w: 0.11, tilt: 10)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.2, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "2-stack", slots: [0, 1], length: 1.8, transition: .slideUp),
            MotionScene(layoutId: "4-big-top", slots: [0, 1, 2, 3], length: 3.6, entrance: .slam),
        ])
    ),
    DesignTemplate(
        id: "motion-coffee-date", name: String(localized: "Coffee date"), category: .motion, tags: [.dateNight, .food], mode: .collage,
        format: .post, layoutId: "3-cascade", isLiving: true, bg: "#e9dccb", backdrop: pattern(.dots),
        frameColor: "#fbfaf6", frameWidth: 14, cellFrames: [.instant, .tape, .instant], filter: .warm,
        captions: [
            sceneCaption(caption(String(localized: "Coffee date"), .hand, y: 0.9, size: 90, color: "#5a3a28", rotation: -3), 0),
            sceneCaption(caption(String(localized: "little things"), .diary, x: 0.2, y: 0.85, size: 64, color: "#5a3a28", rotation: -4), 2),
        ],
        stickers: [emoji("☕️", x: 0.86, y: 0.12, w: 0.12, tilt: 10)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-tilt", slots: [0], length: 2.2, entrance: .drop),
            MotionScene(layoutId: "2-pile", slots: [0, 1], length: 2.2, move: .sway, entrance: .drop),
            MotionScene(layoutId: "3-cascade", slots: [0, 1, 2], length: 3.6, entrance: .rise),
        ])
    ),
    DesignTemplate(
        id: "motion-under-the-stars", name: String(localized: "Under the stars"), category: .motion, tags: [.dateNight, .travel], mode: .collage,
        format: .story, layoutId: "3-stairs", isLiving: true, backdrop: gradient(5), frame: .circle, filter: .cool,
        captions: [
            sceneCaption(caption(String(localized: "Under the stars"), .dreamy, y: 0.9, size: 96, color: "#e5d6ff"), 0),
            sceneCaption(caption(String(localized: "Under the stars"), .dreamy, x: 0.22, y: 0.84, size: 50, color: "#e5d6ff"), 1),
        ],
        stickers: [emoji("🌙", x: 0.82, y: 0.1, w: 0.12, tilt: -12)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.4, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "3-stairs", slots: [0, 1, 2], length: 3.8, move: .sway, entrance: .pop),
        ])
    ),
    DesignTemplate(
        id: "motion-picnic-date", name: String(localized: "Picnic date"), category: .motion, tags: [.dateNight, .food], mode: .collage,
        format: .post, layoutId: "5-scrapbook", isLiving: true, bg: "#f6efe2", backdrop: pattern(.checks),
        frameColor: "#ffffff", frameWidth: 16, cellFrames: [.instant, .tape], filter: .warm,
        captions: [sceneCaption(caption(String(localized: "Picnic date"), .hand, x: 0.82, y: 0.2, size: 64, color: "#c0392b", rotation: 6), 0)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "2-pile", slots: [0, 1], length: 2.4, move: .sway, entrance: .drop),
            MotionScene(layoutId: "5-scrapbook", slots: [0, 1, 2, 3, 4], length: 3.8, entrance: .drop),
        ])
    ),

    // Birthday
    DesignTemplate(
        id: "motion-birthday-bash", name: String(localized: "Birthday bash"), category: .motion, tags: [.birthday, .party], mode: .collage,
        format: .post, layoutId: "5-hero", isLiving: true, gap: 14, radius: 12, bg: "#ffe3ec", backdrop: pattern(.confetti),
        frame: .border, frameColor: "#ffffff", frameWidth: 12, filter: .vivid,
        captions: [
            sceneCaption(caption(String(localized: "Happy Birthday"), .script, y: 0.1, size: 78, color: "#d6336c", ornament: .sparkles), 0),
            sceneCaption(caption(String(localized: "bring cake"), .marker, y: 0.4, size: 70, color: "#d6336c", look: .sticker, rotation: -4), 2),
        ],
        stickers: [emoji("🎂", x: 0.9, y: 0.92, w: 0.12, tilt: 8)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.2, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "3-fan", slots: [1, 0, 2], length: 2.2, entrance: .spin),
            MotionScene(layoutId: "5-hero", slots: [0, 1, 2, 3, 4], length: 3.6, entrance: .pop),
        ])
    ),
    DesignTemplate(
        id: "motion-make-a-wish", name: String(localized: "Make a wish"), category: .motion, tags: [.birthday], mode: .collage,
        format: .story, layoutId: "4-band", isLiving: true, backdrop: gradient(8), frame: .circle, filter: .warm,
        captions: [
            sceneCaption(caption(String(localized: "Make a wish"), .dreamy, y: 0.88, size: 110, color: "#6c4dff"), 0),
            sceneCaption(caption(String(localized: "Happy Birthday"), .script, y: 0.5, size: 100, ornament: .sparkles), 1),
        ],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.6, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "4-band", slots: [0, 1, 2, 3], length: 3.8, entrance: .pop),
        ])
    ),
    DesignTemplate(
        id: "motion-birthday-wall", name: String(localized: "Birthday wall"), category: .motion, tags: [.birthday, .party], mode: .collage,
        format: .square, layoutId: "6-wall", isLiving: true, backdrop: gradient(1),
        frame: .instant, frameColor: "#ffffff", frameWidth: 14, filter: .vivid,
        captions: [sceneCaption(caption(String(localized: "it's my\nBIRTHDAY"), .poster, y: 0.84, size: 100, look: .neon, mix: .lead,
                                        accent: .retro), 2)],
        stickers: [emoji("🎈", x: 0.1, y: 0.86, w: 0.12, tilt: -10), emoji("🎉", x: 0.9, y: 0.86, w: 0.12, tilt: 12)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "2-side", slots: [0, 1], length: 1.8, entrance: .spin),
            MotionScene(layoutId: "4-tossed", slots: [0, 1, 2, 3], length: 1.8, entrance: .spin),
            MotionScene(layoutId: "6-wall", slots: [0, 1, 2, 3, 4, 5], length: 3.6, entrance: .drop),
        ])
    ),

    // Friends
    DesignTemplate(
        id: "motion-squad-goals", name: String(localized: "Squad goals"), category: .motion, tags: [.friends], mode: .collage,
        format: .square, layoutId: "6-wide", isLiving: true, gap: 6, bg: "#18181c", filter: .vivid,
        captions: [sceneCaption(caption(String(localized: "the squad"), .marker, y: 0.5, size: 90, look: .label), 6)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 1.0, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [1], length: 0.8, transition: .zoom, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [2], length: 0.8, transition: .zoom, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [3], length: 0.8, transition: .zoom, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [4], length: 0.8, transition: .zoom, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [5], length: 0.8, transition: .zoom, move: .zoomIn),
            MotionScene(layoutId: "6-wide", slots: [0, 1, 2, 3, 4, 5], length: 3.2, entrance: .pop),
        ], transitionLength: 0.3)
    ),
    DesignTemplate(
        id: "motion-besties", name: String(localized: "Besties"), category: .motion, tags: [.friends], mode: .collage,
        format: .post, layoutId: "2-pile", isLiving: true, backdrop: gradient(8),
        frameColor: "#ffffff", frameWidth: 16, cellFrames: [.instant, .tape], filter: .warm,
        captions: [
            sceneCaption(caption(String(localized: "Besties"), .marker, y: 0.5, size: 120, color: "#ff5fa2", look: .label, rotation: -4), 0),
            sceneCaption(caption(String(localized: "us, lately"), .vows, x: 0.82, y: 0.18, size: 76, color: "#3d2c8d", rotation: 8), 1),
        ],
        stickers: [emoji("💫", x: 0.14, y: 0.92, w: 0.1)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "2-side", slots: [0, 1], length: 2.4, entrance: .slide),
            MotionScene(layoutId: "2-pile", slots: [0, 1], length: 3.6, move: .sway),
        ])
    ),
    DesignTemplate(
        id: "motion-road-trip", name: String(localized: "Road trip"), category: .motion, tags: [.friends, .travel], mode: .collage,
        format: .story, layoutId: "4-zigzag", isLiving: true, bg: "#f2e3c6", backdrop: pattern(.dots),
        frameColor: "#fbfaf6", frameWidth: 14, cellFrames: [.stamp, .instant, .stamp, .instant], filter: .vintage,
        captions: [
            sceneCaption(caption(String(localized: "Road trip"), .poster, y: 0.88, size: 110, color: "#e2552b", look: .label, allCaps: true), 0),
            sceneCaption(caption(String(localized: "day 1"), .hand, x: 0.78, y: 0.12, size: 64, color: "#2b4a8b", rotation: 6), 3),
            sceneCaption(caption(String(localized: "day 2"), .hand, x: 0.22, y: 0.4, size: 64, color: "#2b4a8b", rotation: -6), 3),
            sceneCaption(caption(String(localized: "day 3"), .hand, x: 0.78, y: 0.61, size: 64, color: "#2b4a8b", rotation: 6), 3),
            sceneCaption(caption(String(localized: "day 4"), .hand, x: 0.22, y: 0.86, size: 64, color: "#2b4a8b", rotation: -6), 3),
        ],
        stickers: [emoji("🚗", x: 0.1, y: 0.965, w: 0.08, tilt: -8)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 1.8, move: .drift),
            MotionScene(layoutId: "1-full", slots: [1], length: 1.8, transition: .slideLeft, move: .drift),
            MotionScene(layoutId: "1-full", slots: [2], length: 1.8, transition: .slideLeft, move: .drift),
            MotionScene(layoutId: "4-zigzag", slots: [0, 1, 2, 3], length: 3.8, entrance: .slide),
        ])
    ),
    DesignTemplate(
        id: "motion-festival", name: String(localized: "Festival"), category: .motion, tags: [.friends, .party], mode: .collage,
        format: .story, layoutId: "6-stairs", isLiving: true, gap: 10, radius: 14, backdrop: gradient(1),
        frame: .neon, frameColor: "#ffd23f", frameWidth: 12, filter: .vivid,
        captions: [
            sceneCaption(caption(String(localized: "LIVE"), .poster, y: 0.86, size: 160, color: "#ffd23f", look: .neon, allCaps: true), 1),
            sceneCaption(caption(String(localized: "Festival"), .retro, y: 0.4, size: 130, color: "#ff4fd8", look: .neon), 2),
        ],
        motion: Motion(scenes: [
            MotionScene(layoutId: "3-cols", slots: [0, 1, 2], length: 2.0, entrance: .slam),
            MotionScene(layoutId: "1-full", slots: [1], length: 1.8, transition: .zoom, move: .zoomIn),
            MotionScene(layoutId: "6-stairs", slots: [1, 0, 2, 3, 4, 5], length: 3.6, entrance: .drop),
        ])
    ),

    // Travel and outdoors
    DesignTemplate(
        id: "motion-wanderlust", name: String(localized: "Wanderlust"), category: .motion, tags: [.travel], mode: .collage,
        format: .story, layoutId: "5-hero", isLiving: true, gap: 10, radius: 16, backdrop: gradient(10), filter: .film,
        captions: [
            sceneCaption(caption(String(localized: "Wanderlust"), .script, y: 0.85, size: 140, ornament: .swash), 0),
            sceneCaption(caption(String(localized: "where we went"), .magazine, y: 0.4, size: 70, look: .plate), 2),
        ],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.6, move: .drift),
            MotionScene(layoutId: "2-stack", slots: [0, 1], length: 2.2, transition: .slideUp, move: .drift),
            MotionScene(layoutId: "5-hero", slots: [0, 1, 2, 3, 4], length: 3.6, entrance: .rise),
        ])
    ),
    DesignTemplate(
        id: "motion-passport", name: String(localized: "Passport stamps"), category: .motion, tags: [.travel], mode: .collage,
        format: .post, layoutId: "4-tossed", isLiving: true, bg: "#e9dfcf", backdrop: pattern(.grid),
        frame: .stamp, frameColor: "#fbfaf6", frameWidth: 16, filter: .vintage,
        captions: [sceneCaption(caption(String(localized: "par avion"), .typewriter, y: 0.5, size: 48, color: "#2b4a8b", look: .label,
                                        rotation: -6), 2)],
        stickers: [shape("seal.fill", color: "#c0392b", x: 0.88, y: 0.93, w: 0.1, tilt: 12)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-tilt", slots: [0], length: 1.8, entrance: .slam),
            MotionScene(layoutId: "2-pile", slots: [0, 1], length: 1.8, entrance: .slam),
            MotionScene(layoutId: "4-tossed", slots: [0, 1, 2, 3], length: 3.6, entrance: .slam),
        ], transitionLength: 0.5)
    ),
    DesignTemplate(
        id: "motion-into-the-wild", name: String(localized: "Into the wild"), category: .motion, tags: [.travel], mode: .collage,
        format: .post, layoutId: "3-big-left", isLiving: true, gap: 12, bg: "#1f2a1f",
        frame: .border, frameColor: "#efe6d2", frameWidth: 10, filter: .cool,
        captions: [sceneCaption(caption(String(localized: "Into the wild"), .engraved, y: 0.86, size: 80, color: "#efe6d2", allCaps: true), 0)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.6, move: .zoomOut),
            MotionScene(layoutId: "1-full", slots: [1], length: 2.2, move: .zoomOut),
            MotionScene(layoutId: "3-big-left", slots: [0, 1, 2], length: 3.6, entrance: .slide),
        ])
    ),
    DesignTemplate(
        id: "motion-city-lights", name: String(localized: "City lights"), category: .motion, tags: [.travel, .party], mode: .collage,
        format: .story, layoutId: "3-cols", isLiving: true, gap: 12, backdrop: gradient(5),
        frame: .neon, frameColor: "#3de0ff", frameWidth: 10, filter: .chrome,
        captions: [sceneCaption(caption(String(localized: "City lights"), .poster, y: 0.88, size: 110, color: "#ffd84d", look: .neon,
                                        allCaps: true), 0)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.0, move: .zoomIn),
            MotionScene(layoutId: "2-side", slots: [0, 1], length: 2.0, transition: .slideUp),
            MotionScene(layoutId: "3-cols", slots: [0, 1, 2], length: 3.6, entrance: .rise),
        ])
    ),
    DesignTemplate(
        id: "motion-snow-days", name: String(localized: "Snow days"), category: .motion, tags: [.holidays, .travel], mode: .collage,
        format: .square, layoutId: "5-scrapbook", isLiving: true, bg: "#e9f1f8", backdrop: pattern(.dots),
        frame: .instant, frameColor: "#ffffff", frameWidth: 14, filter: .cool,
        captions: [sceneCaption(caption(String(localized: "Snow days"), .hand, x: 0.26, y: 0.49, size: 64, color: "#2b4a8b", rotation: -4), 1)],
        stickers: [emoji("❄️", x: 0.5, y: 0.975, w: 0.06)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-tilt", slots: [0], length: 2.2, move: .zoomIn, entrance: .drop),
            MotionScene(layoutId: "5-scrapbook", slots: [0, 1, 2, 3, 4], length: 3.8, move: .sway, entrance: .drop),
        ])
    ),

    // Wedding
    DesignTemplate(
        id: "motion-just-married", name: String(localized: "Just married"), category: .motion, tags: [.wedding, .love], mode: .collage,
        format: .post, layoutId: "3-big-top", isLiving: true, gap: 16, radius: 6, bg: "#fbf7f2", frame: .shadow, filter: .fade,
        captions: [
            sceneCaption(caption(String(localized: "Just married"), .vows, y: 0.1, size: 92, color: "#8a6d3b", ornament: .heart), 0),
            sceneCaption(caption(String(localized: "forever"), .signature, y: 0.6, size: 110), 2),
        ],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.6, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "2-side", slots: [1, 2], length: 2.2, entrance: .rise),
            MotionScene(layoutId: "3-big-top", slots: [0, 1, 2], length: 3.6, move: .zoomOut, entrance: .rise),
        ])
    ),
    DesignTemplate(
        id: "motion-first-dance", name: String(localized: "First dance"), category: .motion, tags: [.wedding, .love], mode: .collage,
        format: .story, layoutId: "3-big-bottom", isLiving: true, gap: 10, bg: "#0e0d0c", filter: .mono,
        captions: [sceneCaption(caption(String(localized: "First dance"), .vows, y: 0.86, size: 120), 0)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.8, move: .zoomIn),
            MotionScene(layoutId: "1-full", slots: [1], length: 2.4, move: .zoomOut),
            MotionScene(layoutId: "3-big-bottom", slots: [0, 2, 1], length: 3.6, entrance: .rise),
        ], transitionLength: 1.0)
    ),
    DesignTemplate(
        id: "motion-ever-after", name: String(localized: "Ever after"), category: .motion, tags: [.wedding], mode: .collage,
        format: .post, layoutId: "4-magazine", isLiving: true, gap: 10, bg: "#f6efe7", filter: .fade,
        captions: [sceneCaption(caption(String(localized: "happily ever after"), .signature, y: 0.09, size: 76, color: "#8a6d3b"), 1)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.6, move: .drift),
            MotionScene(layoutId: "4-magazine", slots: [0, 1, 2, 3], length: 3.8, entrance: .rise),
        ])
    ),

    // Baby, pets, food, fitness, graduation
    DesignTemplate(
        id: "motion-little-one", name: String(localized: "Little one"), category: .motion, tags: [.baby], mode: .collage,
        format: .post, layoutId: "4-offset", isLiving: true, bg: "#eef6ff", backdrop: pattern(.dots), frame: .circle,
        captions: [sceneCaption(caption(String(localized: "hello, little one"), .dreamy, y: 0.9, size: 84, color: "#b05c7a"), 0)],
        stickers: [emoji("⭐️", x: 0.92, y: 0.04, w: 0.07, tilt: 12), emoji("⭐️", x: 0.08, y: 0.97, w: 0.06, tilt: -10)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.4, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "4-offset", slots: [0, 1, 2, 3], length: 3.8, move: .sway, entrance: .pop),
        ])
    ),
    DesignTemplate(
        id: "motion-paw-prints", name: String(localized: "Paw prints"), category: .motion, tags: [.pets], mode: .collage,
        format: .square, layoutId: "3-tossed", isLiving: true, bg: "#fff4e0", backdrop: pattern(.dots),
        frameColor: "#fbfaf6", frameWidth: 14, cellFrames: [.instant, .tape, .stamp], filter: .warm,
        captions: [sceneCaption(caption(String(localized: "my best friend"), .hand, x: 0.78, y: 0.14, size: 52, color: "#6b3e1f", rotation: 6), 1)],
        stickers: [emoji("🐾", x: 0.86, y: 0.88, w: 0.1, tilt: 12)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-tilt", slots: [0], length: 2.0, move: .zoomIn, entrance: .drop),
            MotionScene(layoutId: "3-tossed", slots: [0, 1, 2], length: 3.8, move: .sway, entrance: .drop),
        ])
    ),
    DesignTemplate(
        id: "motion-zoomies", name: String(localized: "Zoomies"), category: .motion, tags: [.pets], mode: .collage,
        format: .story, layoutId: "4-big-top", isLiving: true, gap: 10, radius: 20, backdrop: gradient(6), filter: .vivid,
        captions: [sceneCaption(caption(String(localized: "Zoomies"), .marker, y: 0.55, size: 120, color: "#101016", look: .sticker,
                                        rotation: -6), 4)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 0.9, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "1-full", slots: [1], length: 0.9, transition: .cut, move: .zoomIn, entrance: .slide),
            MotionScene(layoutId: "1-full", slots: [2], length: 0.9, transition: .cut, move: .zoomIn, entrance: .slide),
            MotionScene(layoutId: "1-full", slots: [3], length: 0.9, transition: .cut, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "4-big-top", slots: [0, 1, 2, 3], length: 3.4, entrance: .slide),
        ])
    ),
    DesignTemplate(
        id: "motion-brunch-club", name: String(localized: "Brunch club"), category: .motion, tags: [.food, .friends], mode: .collage,
        format: .square, layoutId: "5-cross", isLiving: true, bg: "#f4ead8", backdrop: pattern(.checks), frame: .circle, filter: .warm,
        captions: [sceneCaption(caption(String(localized: "Brunch club"), .note, x: 0.17, y: 0.17, size: 50, color: "#a3392b", rotation: -8), 1)],
        stickers: [emoji("🍳", x: 0.83, y: 0.17, w: 0.14, tilt: 10), emoji("🥐", x: 0.17, y: 0.83, w: 0.14, tilt: -10),
                   emoji("☕️", x: 0.83, y: 0.83, w: 0.14, tilt: 8)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.2, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "5-cross", slots: [1, 2, 0, 3, 4], length: 3.8, entrance: .spin),
        ])
    ),
    DesignTemplate(
        id: "motion-beast-mode", name: String(localized: "Beast mode"), category: .motion, tags: [.fitness], mode: .collage,
        format: .story, layoutId: "3-rows", isLiving: true, gap: 8, bg: "#0d0d0f", filter: .chrome,
        captions: [sceneCaption(caption(String(localized: "Beast mode"), .poster, y: 0.333, size: 110, color: "#d7ff3b", look: .outline,
                                        allCaps: true), 3)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 0.8, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "1-full", slots: [1], length: 0.8, transition: .cut, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "1-full", slots: [2], length: 0.8, transition: .cut, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "3-rows", slots: [0, 1, 2], length: 3.2, entrance: .slide),
        ])
    ),
    DesignTemplate(
        id: "motion-grad-day", name: String(localized: "Grad day"), category: .motion, tags: [.graduation], mode: .collage,
        format: .post, layoutId: "3-big-top", isLiving: true, gap: 14, radius: 10, bg: "#13233f",
        frame: .border, frameColor: "#e8c36a", frameWidth: 10,
        captions: [
            sceneCaption(caption(String(localized: "Class of 2026"), .poster, y: 0.1, size: 70, color: "#e8c36a", allCaps: true), 0),
            sceneCaption(caption(String(localized: "we did it!"), .script, y: 0.6, size: 110, ornament: .sparkles), 1),
        ],
        stickers: [emoji("🎓", x: 0.9, y: 0.08, w: 0.12, tilt: 12)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.2, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "3-big-top", slots: [0, 1, 2], length: 3.8, entrance: .spin),
        ])
    ),

    // Holidays
    DesignTemplate(
        id: "motion-countdown", name: String(localized: "Countdown"), category: .motion, tags: [.holidays, .party], mode: .collage,
        format: .story, layoutId: "4-grid", isLiving: true, gap: 10, radius: 16, backdrop: gradient(5), filter: .vivid,
        captions: [
            sceneCaption(caption("3", .poster, y: 0.5, size: 240, look: .outline), 0),
            sceneCaption(caption("2", .poster, y: 0.5, size: 240, look: .outline), 1),
            sceneCaption(caption("1", .poster, y: 0.5, size: 240, look: .outline), 2),
            sceneCaption(caption(String(localized: "Happy New Year"), .script, y: 0.5, size: 88, ornament: .sparkles), 3),
        ],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 1.0, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "1-full", slots: [1], length: 1.0, transition: .cut, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "1-full", slots: [2], length: 1.0, transition: .cut, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "4-grid", slots: [0, 1, 2, 3], length: 3.8, entrance: .spin),
        ])
    ),
    DesignTemplate(
        id: "motion-christmas-magic", name: String(localized: "Christmas magic"), category: .motion, tags: [.holidays], mode: .collage,
        format: .post, layoutId: "6-wall", isLiving: true, backdrop: gradient(10),
        frame: .instant, frameColor: "#fffaf0", frameWidth: 14, filter: .warm,
        captions: [
            sceneCaption(caption(String(localized: "Merry Christmas"), .script, y: 0.1, size: 84, ornament: .sparkles), 0),
            sceneCaption(caption(String(localized: "Merry Christmas"), .script, y: 0.83, size: 84, ornament: .sparkles), 1),
        ],
        stickers: [emoji("🎄", x: 0.88, y: 0.92, w: 0.12), emoji("🎁", x: 0.12, y: 0.92, w: 0.11, tilt: -8)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.2, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "6-wall", slots: [0, 1, 2, 3, 4, 5], length: 3.8, move: .sway, entrance: .drop),
        ])
    ),
    DesignTemplate(
        id: "motion-spooky-season", name: String(localized: "Spooky season"), category: .motion, tags: [.holidays, .party], mode: .collage,
        format: .story, layoutId: "3-cascade", isLiving: true, bg: "#120a05",
        frame: .torn, frameColor: "#f2e6d0", frameWidth: 14, filter: .noir,
        captions: [
            sceneCaption(caption(String(localized: "Spooky season"), .chalk, y: 0.86, size: 110, color: "#ff7a1a"), 0),
            sceneCaption(caption(String(localized: "Spooky season"), .chalk, x: 0.2, y: 0.84, size: 58, color: "#ff7a1a"), 2),
        ],
        stickers: [emoji("🎃", x: 0.84, y: 0.12, w: 0.14, tilt: 10)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 1.6, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "1-full", slots: [1], length: 1.4, transition: .cut, move: .zoomIn, entrance: .slam),
            MotionScene(layoutId: "3-cascade", slots: [0, 1, 2], length: 3.6, entrance: .drop),
        ])
    ),
    DesignTemplate(
        id: "motion-festival-of-lights", name: String(localized: "Festival of lights"), category: .motion, tags: [.holidays], mode: .collage,
        format: .post, layoutId: "5-sandwich", isLiving: true, gap: 14, radius: 16, bg: "#2a0f2e",
        frame: .neon, frameColor: "#ffd23f", frameWidth: 12, filter: .warm,
        captions: [sceneCaption(caption(String(localized: "Happy Diwali"), .vows, y: 0.1, size: 90, color: "#fff3c4", ornament: .sparkles), 0)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-centre", slots: [0], length: 2.2, move: .zoomIn, entrance: .pop),
            MotionScene(layoutId: "5-sandwich", slots: [1, 2, 0, 3, 4], length: 3.8, entrance: .pop),
        ])
    ),

    // Everyday
    DesignTemplate(
        id: "motion-ootd", name: String(localized: "Outfit of the day"), category: .motion, tags: [.moodboard], mode: .collage,
        format: .story, layoutId: "3-cols", isLiving: true, gap: 10, bg: "#f1ece3", filter: .chrome,
        captions: [sceneCaption(caption("OOTD", .magazine, y: 0.07, size: 120), 3)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 1.4, move: .zoomOut),
            MotionScene(layoutId: "1-full", slots: [1], length: 1.2, transition: .slideLeft, move: .zoomOut),
            MotionScene(layoutId: "1-full", slots: [2], length: 1.2, transition: .slideLeft, move: .zoomOut),
            MotionScene(layoutId: "3-cols", slots: [0, 1, 2], length: 3.4, entrance: .slam),
        ])
    ),
    DesignTemplate(
        id: "motion-summer-dump", name: String(localized: "Summer dump"), category: .motion, tags: [.photoDump, .beach], mode: .collage,
        format: .post, layoutId: "9-grid", isLiving: true, gap: 8, radius: 10, bg: "#ffffff", filter: .warm,
        captions: [sceneCaption(caption(String(localized: "summer"), .dreamy, y: 0.5, size: 140), 9)],
        motion: Motion(scenes: (0..<9).map { i -> MotionScene in
            MotionScene(layoutId: "1-full", slots: [i], length: 0.55, transition: .cut, move: .zoomIn)
        } + [MotionScene(layoutId: "9-grid", slots: Array(0..<9), length: 3.4, entrance: .pop)])
    ),
    DesignTemplate(
        id: "motion-day-in-my-life", name: String(localized: "Day in my life"), category: .motion, tags: [.video, .photoDump], mode: .collage,
        format: .story, layoutId: "4-grid", isLiving: true, gap: 8, radius: 14, bg: "#111114",
        captions: [sceneCaption(caption(String(localized: "day in my life"), .marker, y: 0.88, size: 80, look: .label), 0)],
        stickers: [shape("play.circle.fill", color: "#ffffff", x: 0.92, y: 0.04, w: 0.08)],
        motion: Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.0),
            MotionScene(layoutId: "2-stack", slots: [0, 1], length: 1.8, transition: .slideUp),
            MotionScene(layoutId: "4-grid", slots: [0, 1, 2, 3], length: 3.6, entrance: .slide),
        ])
    ),

    // MARK: With video (first: playing videos inside a collage is what the app is for)
    DesignTemplate(
        id: "v-hero-clip", name: String(localized: "Hero clip"), category: .video, mode: .collage, format: .story,
        layoutId: "3-big-top", gap: 8, radius: 16, bg: "#0e0e12",
        captions: [caption(String(localized: "▶ press play"), .rounded, x: 0.5, y: 0.04, size: 40, color: "#ffffff", look: .plate)]
    ),
    DesignTemplate(
        id: "v-reel-mix", name: String(localized: "Reel mix"), category: .video, mode: .collage, format: .story,
        layoutId: "3-rows", gap: 6, bg: "#07070b", frame: .neon, frameColor: "#ff4fd8",
        captions: [caption(String(localized: "REEL MIX"), .poster, x: 0.5, y: 0.5, size: 90, color: "#3de0ff", look: .neon, allCaps: true)]
    ),
    DesignTemplate(
        id: "v-vlog", name: String(localized: "Vlog grid"), category: .video, mode: .collage, format: .post,
        layoutId: "4-grid", gap: 10, radius: 14, bg: "#111114",
        captions: [caption(String(localized: "day in my life"), .marker, x: 0.5, y: 0.5, size: 60, look: .label)],
        stickers: [shape("play.circle.fill", color: "#ffffff", x: 0.92, y: 0.07, w: 0.09)]
    ),
    DesignTemplate(
        id: "v-film-clips", name: String(localized: "Film clips"), category: .video, mode: .collage, format: .story,
        layoutId: "3-filmstrip", bg: "#0b0b0d", frame: .film, frameColor: "#141416", frameWidth: 24,
        captions: [caption(String(localized: "REC ●"), .typewriter, x: 0.86, y: 0.05, size: 36, color: "#ff3b30")]
    ),
    DesignTemplate(
        id: "v-moments", name: String(localized: "Moving moments"), category: .video, mode: .collage, format: .post,
        layoutId: "4-hero-prints", bg: "#efe6d8", frameColor: "#fbfaf6", frameWidth: 12,
        cellFrames: [.shadow, .instant, .instant, .instant],
        captions: [caption(String(localized: "moments that move"), .vows, x: 0.5, y: 0.05, size: 72, color: "#3b2f2a")]
    ),

    // MARK: Collages
    DesignTemplate(
        id: "c-photo-dump", name: String(localized: "Photo dump"), category: .photoDump, mode: .collage, format: .post,
        layoutId: "9-grid", gap: 8, bg: "#f4efe6",
        captions: [caption(String(localized: "photo dump"), .typewriter, y: 0.5, size: 64, color: "#1b1b1f", look: .label)]
    ),
    DesignTemplate(
        id: "c-dump-story", name: String(localized: "Story dump"), category: .photoDump, mode: .collage, format: .story,
        layoutId: "7-hero", gap: 6, radius: 10, bg: "#111114",
        captions: [caption(String(localized: "this week ✦"), .marker, y: 0.37, size: 70, look: .plate)]
    ),
    DesignTemplate(
        id: "c-travel-diary", name: String(localized: "Travel diary"), category: .travel, mode: .collage, format: .post,
        layoutId: "5-hero", gap: 14, radius: 18, backdrop: gradient(3),
        captions: [caption(String(localized: "Travel diary"), .script, y: 0.07, size: 92, ornament: .swash)],
        stickers: [emoji("✈️", x: 0.9, y: 0.07, w: 0.1, tilt: -12)]
    ),
    DesignTemplate(
        id: "c-postcard", name: String(localized: "Postcard"), category: .travel, mode: .collage, format: .square,
        layoutId: "3-big-left", gap: 18, radius: 4, bg: "#efe6d8", frame: .border, frameColor: "#ffffff", frameWidth: 14,
        captions: [caption(String(localized: "greetings from"), .typewriter, x: 0.3, y: 0.92, size: 46, color: "#3b2f2a")]
    ),
    DesignTemplate(
        id: "c-polaroid-wall", name: String(localized: "Instant prints"), category: .scrapbook, mode: .collage, format: .post,
        layoutId: "4-grid", gap: 44, bg: "#e9dfcf", backdrop: pattern(.dots), frame: .instant, frameColor: "#fbfaf6",
        captions: [caption(String(localized: "memories"), .hand, y: 0.5, size: 84, color: "#3b2f2a", rotation: -4)],
        stickers: [shape("heart.fill", color: "#e2557a", x: 0.12, y: 0.06, w: 0.07, tilt: -14)]
    ),
    DesignTemplate(
        id: "c-torn-notes", name: String(localized: "Torn notes"), category: .scrapbook, mode: .collage, format: .post,
        layoutId: "3-big-top", gap: 26, bg: "#f2ead9", frame: .torn, frameColor: "#ffffff",
        captions: [caption(String(localized: "little things"), .diary, x: 0.5, y: 0.53, size: 64, color: "#2e2a26", rotation: -3)],
        stickers: [emoji("🌼", x: 0.92, y: 0.08, w: 0.11, tilt: 10)]
    ),
    DesignTemplate(
        id: "c-birthday", name: String(localized: "Birthday"), category: .birthday, mode: .collage, format: .post,
        layoutId: "4-big-top", gap: 18, radius: 14, backdrop: gradient(1), frame: .border, frameWidth: 10,
        captions: [caption(String(localized: "Happy Birthday"), .script, y: 0.47, size: 104, look: .plain, ornament: .sparkles)],
        stickers: [emoji("🎉", x: 0.1, y: 0.08, w: 0.13, tilt: -10), emoji("🎂", x: 0.9, y: 0.92, w: 0.13, tilt: 8)]
    ),
    DesignTemplate(
        id: "c-party", name: String(localized: "Party night"), category: .birthday, tags: [.party], mode: .collage, format: .story,
        layoutId: "6-grid", gap: 10, radius: 20, backdrop: gradient(5),
        captions: [caption(String(localized: "PARTY"), .poster, y: 0.5, size: 140, look: .outline, allCaps: true)],
        stickers: [emoji("🎈", x: 0.88, y: 0.06, w: 0.14, tilt: 12)]
    ),
    DesignTemplate(
        id: "c-you-and-me", name: String(localized: "You & me"), category: .love, tags: [.dateNight], mode: .collage, format: .post,
        layoutId: "2-side", gap: 22, radius: 22, backdrop: gradient(7),
        captions: [caption(String(localized: "you & me"), .vows, y: 0.9, size: 96, ornament: .heart)],
        stickers: [emoji("❤️", x: 0.5, y: 0.08, w: 0.1)]
    ),
    DesignTemplate(
        id: "c-anniversary", name: String(localized: "Anniversary"), category: .love, mode: .collage, format: .story,
        layoutId: "3-rows", gap: 12, radius: 6, bg: "#fbf3ef", frame: .shadow,
        captions: [caption(String(localized: "forever"), .signature, y: 0.5, size: 110, color: "#b23a5b")]
    ),
    DesignTemplate(
        id: "c-squad", name: String(localized: "The squad"), category: .friends, mode: .collage, format: .post,
        layoutId: "6-mix", gap: 6, bg: "#18181c",
        captions: [caption(String(localized: "the squad"), .marker, y: 0.5, size: 90, look: .label)],
        stickers: [emoji("🔥", x: 0.9, y: 0.1, w: 0.12, tilt: 10)]
    ),
    DesignTemplate(
        id: "c-food", name: String(localized: "Good food"), category: .food, mode: .collage, format: .post,
        layoutId: "5-sandwich", gap: 12, radius: 26, backdrop: gradient(2),
        captions: [caption(String(localized: "good food, good mood"), .hand, y: 0.5, size: 62, color: "#4a2a22", look: .label)]
    ),
    DesignTemplate(
        id: "c-minimal", name: String(localized: "Clean white"), category: .minimal, mode: .collage, format: .post,
        layoutId: "3-big-left", gap: 30, bg: "#ffffff",
        captions: [caption(String(localized: "2026"), .typewriter, x: 0.5, y: 0.965, size: 34, color: "#1b1b1f")]
    ),
    DesignTemplate(
        id: "c-black-gallery", name: String(localized: "Black gallery"), category: .minimal, mode: .collage, format: .square,
        layoutId: "4-grid", gap: 36, bg: "#0b0b0d", frame: .border, frameColor: "#f4f1ea", frameWidth: 12
    ),
    DesignTemplate(
        id: "c-moodboard", name: String(localized: "Moodboard"), category: .moodboard, mode: .collage, format: .story,
        layoutId: "7-mix", gap: 10, radius: 8, bg: "#e9e2d6",
        captions: [caption(String(localized: "mood"), .serif, x: 0.5, y: 0.5, size: 120, color: "#ffffff", look: .plain)],
        stickers: [emoji("✨", x: 0.9, y: 0.05, w: 0.1)]
    ),
    DesignTemplate(
        id: "c-before-after", name: String(localized: "Before & after"), category: .beforeAfter, mode: .collage, format: .post,
        layoutId: "2-side", gap: 6, bg: "#ffffff",
        captions: [
            caption(String(localized: "BEFORE"), .poster, x: 0.25, y: 0.93, size: 58, look: .plate, allCaps: true),
            caption(String(localized: "AFTER"), .poster, x: 0.75, y: 0.93, size: 58, look: .plate, allCaps: true),
        ]
    ),
    DesignTemplate(
        id: "c-glow-up", name: String(localized: "Glow up"), category: .beforeAfter, mode: .collage, format: .story,
        layoutId: "2-stack", gap: 8, backdrop: gradient(0),
        captions: [
            caption(String(localized: "then"), .script, x: 0.18, y: 0.06, size: 80),
            caption(String(localized: "now"), .script, x: 0.18, y: 0.56, size: 80),
        ]
    ),

    DesignTemplate(
        id: "c-film-roll", name: String(localized: "Film roll"), category: .photoDump, mode: .collage, format: .story,
        layoutId: "3-rows", gap: 6, bg: "#161618", frame: .film, frameColor: "#101016", frameWidth: 30,
        captions: [caption(String(localized: "roll 01"), .typewriter, x: 0.86, y: 0.985, size: 30, color: "#ff9a3c")]
    ),
    DesignTemplate(
        id: "c-disposable", name: String(localized: "Disposable"), category: .photoDump, mode: .collage, format: .post,
        layoutId: "4-grid", gap: 10, bg: "#0f0f12", frame: .date
    ),
    DesignTemplate(
        id: "c-washi", name: String(localized: "Washi notes"), category: .scrapbook, mode: .collage, format: .post,
        layoutId: "4-grid", gap: 46, bg: "#efe6d8", backdrop: pattern(.grid), frame: .tape, frameColor: "#fbfaf6", frameWidth: 14,
        captions: [caption(String(localized: "summer notes"), .hand, y: 0.5, size: 70, color: "#3b2f2a", rotation: -3)]
    ),
    DesignTemplate(
        id: "c-stamps", name: String(localized: "Stamp collection"), category: .travel, mode: .collage, format: .square,
        layoutId: "6-grid", gap: 26, bg: "#e9dfcf", frame: .stamp, frameColor: "#fbfaf6", frameWidth: 16,
        captions: [caption(String(localized: "par avion"), .typewriter, x: 0.5, y: 0.5, size: 44, color: "#2b4a8b", look: .label, rotation: -6)]
    ),
    DesignTemplate(
        id: "c-gallery", name: String(localized: "Gallery"), category: .minimal, mode: .collage, format: .post,
        layoutId: "2-side", gap: 30, bg: "#f4f1ec", frame: .gallery, frameColor: "#ffffff", frameWidth: 16
    ),
    DesignTemplate(
        id: "c-wedding", name: String(localized: "Wedding day"), category: .wedding, mode: .collage, format: .post,
        layoutId: "3-big-top", gap: 16, radius: 6, bg: "#fbf7f2", frame: .shadow,
        captions: [caption(String(localized: "Mr & Mrs"), .vows, y: 0.6, size: 92, color: "#ffffff", ornament: .heart)]
    ),
    DesignTemplate(
        id: "c-save-date", name: String(localized: "Save the date"), category: .wedding, mode: .collage, format: .post,
        layoutId: "1-centre", bg: "#f6efe7", frame: .arch,
        captions: [
            caption(String(localized: "save the date"), .signature, y: 0.09, size: 92, color: "#8a6d3b"),
            caption(String(localized: "06 · 06 · 2027"), .typewriter, y: 0.91, size: 44, color: "#8a6d3b"),
        ]
    ),
    DesignTemplate(
        id: "c-baby", name: String(localized: "Hello baby"), category: .baby, mode: .collage, format: .post,
        layoutId: "4-grid", gap: 30, bg: "#fdf0f3", frame: .circle,
        captions: [caption(String(localized: "hello, little one"), .dreamy, y: 0.5, size: 76, color: "#b05c7a")],
        stickers: [emoji("🍼", x: 0.9, y: 0.06, w: 0.1, tilt: 10)]
    ),
    DesignTemplate(
        id: "c-baby-months", name: String(localized: "Month by month"), category: .baby, mode: .collage, format: .square,
        layoutId: "6-grid", gap: 30, bg: "#eef6ff", frame: .instant, frameColor: "#ffffff",
        stickers: [emoji("⭐️", x: 0.5, y: 0.5, w: 0.09)]
    ),
    DesignTemplate(
        id: "c-graduation", name: String(localized: "Graduation"), category: .graduation, mode: .collage, format: .post,
        layoutId: "4-big-top", gap: 16, radius: 10, backdrop: gradient(5), frame: .border, frameWidth: 10,
        captions: [caption(String(localized: "Class of 2026"), .poster, y: 0.5, size: 84, look: .plate, allCaps: true)],
        stickers: [emoji("🎓", x: 0.9, y: 0.08, w: 0.13, tilt: 12)]
    ),
    DesignTemplate(
        id: "c-progress", name: String(localized: "Progress"), category: .fitness, mode: .collage, format: .story,
        layoutId: "2-side", gap: 8, bg: "#0d0d0f",
        captions: [
            caption(String(localized: "DAY 1"), .poster, x: 0.25, y: 0.92, size: 70, look: .plate, allCaps: true),
            caption(String(localized: "DAY 100"), .poster, x: 0.75, y: 0.92, size: 70, look: .plate, allCaps: true),
        ]
    ),
    DesignTemplate(
        id: "c-pets", name: String(localized: "Best friend"), category: .pets, mode: .collage, format: .post,
        layoutId: "4-grid", gap: 28, bg: "#fff4e0", frame: .heart,
        captions: [caption(String(localized: "my best friend"), .hand, y: 0.5, size: 76, color: "#6b3e1f")],
        stickers: [emoji("🐾", x: 0.1, y: 0.06, w: 0.1, tilt: -12)]
    ),
    DesignTemplate(
        id: "c-new-in", name: String(localized: "New in"), category: .business, mode: .collage, format: .square,
        layoutId: "4-big-top", gap: 12, bg: "#ffffff",
        captions: [
            caption(String(localized: "NEW IN"), .poster, x: 0.2, y: 0.08, size: 70, color: "#ffffff", look: .plate, allCaps: true),
            caption(String(localized: "shop now →"), .rounded, x: 0.8, y: 0.5, size: 38, look: .label),
        ]
    ),
    DesignTemplate(
        id: "c-quote", name: String(localized: "Quote card"), category: .quote, mode: .collage, format: .post,
        layoutId: "1-centre", radius: 18, backdrop: gradient(2), frame: .shadow,
        captions: [caption(String(localized: "“collect moments, not things”"), .serif, y: 0.9, size: 52, color: "#4a2a22")]
    ),
    DesignTemplate(
        id: "c-christmas", name: String(localized: "Merry Christmas"), category: .holidays, mode: .collage, format: .post,
        layoutId: "5-hero", gap: 14, radius: 10, backdrop: gradient(10), frame: .border, frameWidth: 10,
        captions: [caption(String(localized: "Merry Christmas"), .script, y: 0.07, size: 92, ornament: .sparkles)],
        stickers: [emoji("🎄", x: 0.92, y: 0.94, w: 0.12)]
    ),
    DesignTemplate(
        id: "c-diwali", name: String(localized: "Happy Diwali"), category: .holidays, mode: .collage, format: .post,
        layoutId: "4-grid", gap: 34, backdrop: gradient(1), frame: .neon, frameColor: "#ffd23f",
        captions: [caption(String(localized: "Happy Diwali"), .vows, y: 0.5, size: 96, color: "#fff3c4", ornament: .sparkles)],
        stickers: [emoji("🪔", x: 0.5, y: 0.94, w: 0.1)]
    ),
    DesignTemplate(
        id: "c-new-year", name: String(localized: "New Year"), category: .holidays, mode: .collage, format: .story,
        layoutId: "6-grid", gap: 10, radius: 8, backdrop: gradient(5), frame: .date,
        captions: [caption(String(localized: "2027"), .poster, y: 0.5, size: 170, look: .outline)]
    ),
    DesignTemplate(
        id: "c-valentine", name: String(localized: "Be mine"), category: .love, mode: .collage, format: .post,
        layoutId: "4-grid", gap: 26, bg: "#ffe4ec", frame: .heart,
        captions: [caption(String(localized: "be mine"), .script, y: 0.5, size: 100, color: "#d6336c")]
    ),

    // MARK: Creative collages
    DesignTemplate(
        id: "c-tossed", name: String(localized: "Tossed prints"), category: .scrapbook, mode: .collage, format: .post,
        layoutId: "3-tossed", bg: "#e8dcc6", backdrop: pattern(.dots), frame: .instant, frameColor: "#fbfaf6", frameWidth: 18,
        captions: [caption(String(localized: "weekend"), .hand, x: 0.76, y: 0.93, size: 66, color: "#3b2f2a", rotation: -6)],
        stickers: [emoji("📌", x: 0.3, y: 0.07, w: 0.08), emoji("🌿", x: 0.9, y: 0.8, w: 0.1, tilt: 12)]
    ),
    DesignTemplate(
        id: "c-summer-tape", name: String(localized: "Summer memories"), category: .travel, tags: [.beach], mode: .collage, format: .post,
        layoutId: "4-tossed", backdrop: gradient(2), frame: .tape, frameColor: "#fffaf2", frameWidth: 14, filter: .warm,
        captions: [caption(String(localized: "summer memories"), .vows, y: 0.475, size: 80, color: "#ffffff", look: .plate, rotation: -4)],
        stickers: [emoji("☀️", x: 0.92, y: 0.05, w: 0.1)]
    ),
    DesignTemplate(
        id: "c-scrapbook-page", name: String(localized: "Scrapbook page"), category: .scrapbook, mode: .collage, format: .story,
        layoutId: "5-scrapbook", bg: "#efe6d8", backdrop: pattern(.grid), frameColor: "#fbfaf6", frameWidth: 14,
        cellFrames: [.instant, .stamp, .tape, .torn, .instant],
        captions: [caption(String(localized: "our little\nadventure"), .note, x: 0.25, y: 0.49, size: 58, color: "#7a3b2e", rotation: -5)],
        stickers: [emoji("✈️", x: 0.84, y: 0.5, w: 0.1, tilt: -15), shape("heart.fill", color: "#e2557a", x: 0.5, y: 0.97, w: 0.05)]
    ),
    DesignTemplate(
        id: "c-magazine", name: String(localized: "Magazine cover"), category: .moodboard, mode: .collage, format: .post,
        layoutId: "4-magazine", bg: "#f6f1ea",
        captions: [
            caption(String(localized: "THE EDIT"), .magazine, x: 0.5, y: 0.075, size: 120, color: "#111114", allCaps: true),
            caption(String(localized: "ISSUE 01"), .engraved, x: 0.33, y: 0.9, size: 34, color: "#ffffff"),
            caption(String(localized: "STYLE"), .poster, x: 0.97, y: 0.55, size: 30, color: "#111114", allCaps: true, vertical: true),
        ]
    ),
    DesignTemplate(
        id: "c-noir-strip", name: String(localized: "Noir film"), category: .minimal, mode: .collage, format: .post,
        layoutId: "3-filmstrip", bg: "#0b0b0d", frame: .film, frameColor: "#141416", frameWidth: 24, filter: .noir,
        captions: [
            caption(String(localized: "after hours"), .typewriter, x: 0.5, y: 0.055, size: 46, color: "#f2f2f2"),
            caption(String(localized: "frames 24—26"), .typewriter, x: 0.5, y: 0.955, size: 30, color: "#ff9a3c"),
        ]
    ),
    DesignTemplate(
        id: "c-bubbles", name: String(localized: "Bubbles"), category: .friends, mode: .collage, format: .post,
        layoutId: "4-cluster", backdrop: gradient(8), frame: .circle,
        captions: [caption(String(localized: "good vibes"), .retro, x: 0.27, y: 0.935, size: 74, color: "#ffffff", look: .neon)],
        stickers: [emoji("✨", x: 0.88, y: 0.07, w: 0.09), emoji("💫", x: 0.1, y: 0.92, w: 0.08)]
    ),
    DesignTemplate(
        id: "c-staircase", name: String(localized: "Staircase"), category: .minimal, mode: .collage, format: .post,
        layoutId: "3-stairs", bg: "#f3efe8", frame: .shadow,
        captions: [caption(String(localized: "step by step"), .serif, x: 0.26, y: 0.82, size: 52, color: "#1b1b1f")]
    ),
    DesignTemplate(
        id: "c-pip", name: String(localized: "Picture in picture"), category: .love, tags: [.dateNight], mode: .collage, format: .post,
        layoutId: "2-overlap", bg: "#1a1418", frame: .border, frameColor: "#ffffff", frameWidth: 12,
        captions: [caption(String(localized: "you, always"), .signature, x: 0.2, y: 0.86, size: 74, color: "#ffd6e7")]
    ),
    DesignTemplate(
        id: "c-golden-hour", name: String(localized: "Golden hour"), category: .travel, tags: [.beach], mode: .collage, format: .story,
        layoutId: "4-offset", radius: 22, backdrop: gradient(1), filter: .warm,
        captions: [caption(String(localized: "golden hour"), .romance, x: 0.5, y: 0.965, size: 92, color: "#fff3e0")]
    ),
    DesignTemplate(
        id: "c-neon-grid", name: String(localized: "Neon nights"), category: .friends, tags: [.party], mode: .collage, format: .story,
        layoutId: "4-grid", gap: 48, bg: "#07070b", frame: .neon, frameColor: "#ff4fd8",
        captions: [caption(String(localized: "NEON NIGHTS"), .poster, x: 0.5, y: 0.5, size: 110, color: "#3de0ff", look: .neon, allCaps: true)]
    ),
    DesignTemplate(
        id: "c-postcard-vintage", name: String(localized: "Wish you were here"), category: .travel, mode: .collage, format: .post,
        layoutId: "1-tilt", bg: "#e9dfcf", backdrop: pattern(.stripes), frame: .stamp, frameColor: "#fbfaf6", frameWidth: 22, filter: .vintage,
        captions: [caption(String(localized: "wish you were here"), .script, x: 0.5, y: 0.9, size: 84, color: "#2b4a8b", rotation: -3)],
        stickers: [shape("seal.fill", color: "#c0392b", x: 0.86, y: 0.1, w: 0.12, tilt: 12)]
    ),
    DesignTemplate(
        id: "c-print-wall", name: String(localized: "Print wall"), category: .photoDump, mode: .collage, format: .post,
        layoutId: "6-wall", bg: "#c9a77c", backdrop: pattern(.confetti), frame: .instant, frameColor: "#fbfaf6", frameWidth: 12, filter: .film,
        captions: [caption(String(localized: "the good days"), .note, x: 0.5, y: 0.86, size: 72, color: "#3b2416", look: .label)]
    ),
    DesignTemplate(
        id: "c-lookbook", name: String(localized: "Lookbook"), category: .moodboard, mode: .collage, format: .story,
        layoutId: "3-big-left", gap: 14, bg: "#111114", filter: .chrome,
        captions: [
            caption(String(localized: "LOOKBOOK"), .poster, x: 0.06, y: 0.5, size: 54, color: "#ffffff", allCaps: true, vertical: true),
            caption(String(localized: "autumn '26"), .magazine, x: 0.7, y: 0.965, size: 48, color: "#e9e2d6"),
        ]
    ),
    DesignTemplate(
        id: "c-retro-chrome", name: String(localized: "Retro"), category: .friends, mode: .collage, format: .square,
        layoutId: "4-grid", gap: 20, radius: 26, backdrop: gradient(4), filter: .vivid,
        captions: [caption(String(localized: "Retro"), .retro, x: 0.5, y: 0.5, size: 120, color: "#ff5fa2", look: .sticker)]
    ),

    // MARK: Mixed & overlapping collages
    DesignTemplate(
        id: "c-photo-pile", name: String(localized: "Photo pile"), category: .photoDump, mode: .collage, format: .post,
        layoutId: "5-pile", bg: "#b98f62", backdrop: pattern(.dots), frameColor: "#fbfaf6", frameWidth: 14,
        cellFrames: [.instant, .torn, .tape, .stamp, .instant], filter: .film,
        captions: [caption(String(localized: "the best of\nSUMMER"), .poster, x: 0.5, y: 0.5, size: 96, color: "#ffffff", look: .label,
                           rotation: -4, allCaps: false, mix: .lead, accent: .hand)],
        stickers: [emoji("📌", x: 0.28, y: 0.05, w: 0.07), emoji("📌", x: 0.7, y: 0.06, w: 0.07, tilt: 20)]
    ),
    DesignTemplate(
        id: "c-fan", name: String(localized: "Fan of three"), category: .friends, mode: .collage, format: .post,
        layoutId: "3-fan", backdrop: gradient(6), frame: .instant, frameColor: "#ffffff", frameWidth: 14,
        captions: [
            caption(String(localized: "us, lately"), .vows, x: 0.5, y: 0.1, size: 96, color: "#5a3a00"),
            caption(String(localized: "no. 07"), .typewriter, x: 0.5, y: 0.9, size: 36, color: "#5a3a00"),
        ],
        stickers: [emoji("🌼", x: 0.12, y: 0.86, w: 0.1, tilt: -12), emoji("🌼", x: 0.88, y: 0.84, w: 0.08, tilt: 14)]
    ),
    DesignTemplate(
        id: "c-two-of-us", name: String(localized: "Two of us"), category: .love, tags: [.dateNight], mode: .collage, format: .post,
        layoutId: "2-pile", bg: "#f6e8e4", backdrop: pattern(.hearts), frameColor: "#ffffff", frameWidth: 16,
        cellFrames: [.instant, .tape],
        captions: [caption(String(localized: "you + me"), .signature, x: 0.83, y: 0.2, size: 76, color: "#b23a5b", rotation: 8)],
        stickers: [shape("heart.fill", color: "#e2557a", x: 0.13, y: 0.9, w: 0.08, tilt: -14)]
    ),
    DesignTemplate(
        id: "c-heart", name: String(localized: "Heart of photos"), category: .love, mode: .collage, format: .post,
        layoutId: "8-heart", backdrop: gradient(7), frame: .circle,
        captions: [caption(String(localized: "love"), .romance, x: 0.83, y: 0.9, size: 84, color: "#ffffff", look: .plain)],
        stickers: [emoji("💗", x: 0.9, y: 0.06, w: 0.07, tilt: 12)]
    ),
    DesignTemplate(
        id: "c-hero-prints", name: String(localized: "Hero & prints"), category: .travel, mode: .collage, format: .story,
        layoutId: "4-hero-prints", bg: "#111114", frameColor: "#fbfaf6", frameWidth: 12,
        cellFrames: [.shadow, .instant, .instant, .instant],
        captions: [
            caption(String(localized: "LISBON"), .poster, x: 0.5, y: 0.045, size: 90, color: "#ffffff", allCaps: true),
            caption(String(localized: "38.72° N · 9.13° W"), .typewriter, x: 0.5, y: 0.09, size: 30, color: "#ffd84d"),
        ]
    ),
    DesignTemplate(
        id: "c-cascade", name: String(localized: "Cascade"), category: .minimal, mode: .collage, format: .post,
        layoutId: "3-cascade", bg: "#efeae3", frameColor: "#101016", frameWidth: 20,
        cellFrames: [.border, .film, .border], filter: .chrome,
        captions: [
            caption(String(localized: "SEQUENCE"), .poster, x: 0.04, y: 0.75, size: 34, color: "#101016", allCaps: true, vertical: true),
            caption(String(localized: "01 — 03"), .engraved, x: 0.22, y: 0.93, size: 34, color: "#101016"),
        ]
    ),
    DesignTemplate(
        id: "c-pinboard", name: String(localized: "Pinboard"), category: .moodboard, mode: .collage, format: .story,
        layoutId: "7-board", bg: "#c9a77c", backdrop: pattern(.confetti), frameColor: "#fbfaf6", frameWidth: 10,
        cellFrames: [.instant, .tape, .stamp, .instant, .torn, .tape, .instant],
        captions: [caption(String(localized: "mood: \nsoft & sunny"), .note, x: 0.18, y: 0.97, size: 44, color: "#3b2416", look: .label, rotation: -3)],
        stickers: [emoji("📌", x: 0.24, y: 0.04, w: 0.06), emoji("📍", x: 0.6, y: 0.04, w: 0.06, tilt: 10),
                   emoji("📌", x: 0.86, y: 0.08, w: 0.06, tilt: -14), emoji("✨", x: 0.94, y: 0.6, w: 0.07)]
    ),
    DesignTemplate(
        id: "c-zigzag", name: String(localized: "Zigzag trip"), category: .travel, mode: .collage, format: .story,
        layoutId: "4-zigzag", bg: "#e9dfcf", backdrop: pattern(.dots), frameColor: "#fbfaf6", frameWidth: 14,
        cellFrames: [.stamp, .instant, .stamp, .instant], filter: .vintage,
        captions: [
            caption(String(localized: "day 1"), .hand, x: 0.78, y: 0.12, size: 64, color: "#2b4a8b", rotation: 6),
            caption(String(localized: "day 2"), .hand, x: 0.22, y: 0.42, size: 64, color: "#2b4a8b", rotation: -6),
            caption(String(localized: "day 3"), .hand, x: 0.78, y: 0.56, size: 64, color: "#2b4a8b", rotation: 6),
            caption(String(localized: "day 4"), .hand, x: 0.22, y: 0.86, size: 64, color: "#2b4a8b", rotation: -6),
        ],
        stickers: [emoji("✈️", x: 0.9, y: 0.97, w: 0.08, tilt: -20)]
    ),
    DesignTemplate(
        id: "c-plus", name: String(localized: "Five senses"), category: .minimal, mode: .collage, format: .square,
        layoutId: "5-cross", bg: "#f7f4ee", frame: .shadow,
        captions: [
            caption(String(localized: "see"), .serif, x: 0.17, y: 0.17, size: 46, color: "#1b1b1f"),
            caption(String(localized: "feel"), .serif, x: 0.83, y: 0.17, size: 46, color: "#1b1b1f"),
            caption(String(localized: "taste"), .serif, x: 0.17, y: 0.83, size: 46, color: "#1b1b1f"),
            caption(String(localized: "hear"), .serif, x: 0.83, y: 0.83, size: 46, color: "#1b1b1f"),
        ]
    ),
    DesignTemplate(
        id: "c-party-fan", name: String(localized: "Party fan"), category: .birthday, tags: [.party], mode: .collage, format: .story,
        layoutId: "3-fan", backdrop: gradient(5), frame: .neon, frameColor: "#ffd23f", filter: .vivid,
        captions: [
            caption(String(localized: "it's my\nBIRTHDAY"), .poster, x: 0.5, y: 0.12, size: 120, color: "#ffffff", look: .neon, mix: .lead, accent: .retro),
            caption(String(localized: "bring cake"), .marker, x: 0.5, y: 0.88, size: 60, color: "#101016", look: .sticker),
        ],
        stickers: [emoji("🎈", x: 0.1, y: 0.8, w: 0.12, tilt: -10), emoji("🎉", x: 0.9, y: 0.78, w: 0.12, tilt: 12)]
    ),
    DesignTemplate(
        id: "c-recipe", name: String(localized: "Recipe card"), category: .food, mode: .collage, format: .post,
        layoutId: "4-hero-prints", bg: "#fff8ee", backdrop: pattern(.checks), frameColor: "#ffffff", frameWidth: 14,
        cellFrames: [.gallery, .tape, .tape, .tape], filter: .warm,
        captions: [caption(String(localized: "Sunday pasta"), .script, x: 0.5, y: 0.06, size: 84, color: "#a3392b", look: .plate)]
    ),
    DesignTemplate(
        id: "c-headline", name: String(localized: "Headline"), category: .moodboard, mode: .collage, format: .post,
        layoutId: "4-magazine", bg: "#f2efe8", filter: .mono,
        captions: [
            caption(String(localized: "The Daily Edit"), .magazine, x: 0.5, y: 0.07, size: 92, color: "#111114"),
            caption(String(localized: "WEEKEND EDITION · NO. 12"), .typewriter, x: 0.5, y: 0.135, size: 24, color: "#111114"),
            caption(String(localized: "BREAKING:\nbest day ever"), .poster, x: 0.34, y: 0.86, size: 54, color: "#ffffff", look: .plate, mix: .lead, accent: .typewriter),
        ]
    ),
    DesignTemplate(
        id: "c-neon-pile", name: String(localized: "Concert night"), category: .friends, tags: [.party], mode: .collage, format: .story,
        layoutId: "5-pile", bg: "#07070b", frame: .neon, frameColor: "#ff4fd8", filter: .chrome,
        captions: [caption(String(localized: "LIVE"), .poster, x: 0.5, y: 0.5, size: 150, color: "#3de0ff", look: .neon, allCaps: true, vertical: false)],
        stickers: [emoji("🎸", x: 0.9, y: 0.95, w: 0.09, tilt: 14), emoji("⚡️", x: 0.1, y: 0.95, w: 0.08)]
    ),
    DesignTemplate(
        id: "c-pet-passport", name: String(localized: "Pet passport"), category: .pets, mode: .collage, format: .post,
        layoutId: "2-pile", bg: "#dfe7d8", backdrop: pattern(.grid), frameColor: "#fbfaf6", frameWidth: 18,
        cellFrames: [.stamp, .border],
        captions: [
            caption(String(localized: "PASSPORT"), .engraved, x: 0.73, y: 0.08, size: 46, color: "#2f4a3a"),
            caption(String(localized: "name: best boy\nfavourite: treats"), .typewriter, x: 0.25, y: 0.84, size: 34, color: "#2f4a3a", look: .label),
        ],
        stickers: [emoji("🐾", x: 0.88, y: 0.92, w: 0.1, tilt: 12)]
    ),

    // MARK: Carousels
    DesignTemplate(
        id: "k-swipe-story", name: String(localized: "Swipe story"), category: .photoDump, mode: .carousel,
        style: .flow, backdrop: Backdrop(kind: .blur),
        captions: [caption(String(localized: "swipe →"), .rounded, x: 0.82, y: 0.93, size: 46, look: .label)]
    ),
    DesignTemplate(
        id: "k-travel", name: String(localized: "Where we went"), category: .travel, mode: .carousel,
        style: .duo, gap: 10, radius: 14, backdrop: gradient(3),
        captions: [caption(String(localized: "where we went"), .script, x: 0.5, y: 0.5, size: 96, look: .plain, ornament: .swash)]
    ),
    DesignTemplate(
        id: "k-scrapbook", name: String(localized: "Scrapbook"), category: .scrapbook, mode: .carousel,
        style: .scatter, bg: "#efe6d8", backdrop: pattern(.grid), frame: .instant, frameColor: "#fbfaf6",
        stickers: [emoji("✨", x: 0.12, y: 0.08, w: 0.1), emoji("📸", x: 1.88, y: 0.9, w: 0.12, tilt: 10)]
    ),
    DesignTemplate(
        id: "k-gallery", name: String(localized: "Gallery wall"), category: .minimal, mode: .carousel,
        style: .wall, gap: 18, bg: "#f4f1ec", frame: .border, frameColor: "#1b1b1f", frameWidth: 8
    ),
    DesignTemplate(
        id: "k-mosaic", name: String(localized: "Mosaic dump"), category: .photoDump, mode: .carousel,
        style: .mosaic, gap: 6, bg: "#0b0b0d",
        captions: [caption(String(localized: "recap"), .marker, x: 0.5, y: 0.5, size: 110, look: .label)]
    ),
    DesignTemplate(
        id: "k-film", name: String(localized: "Film roll"), category: .photoDump, mode: .carousel,
        style: .flow, bg: "#121212", frame: .film, frameColor: "#101016", frameWidth: 30
    ),
    DesignTemplate(
        id: "k-neon", name: String(localized: "After dark"), category: .friends, mode: .carousel,
        style: .squareFlow, bg: "#07070b", frame: .neon, frameColor: "#3de0ff",
        captions: [caption(String(localized: "after dark"), .marker, x: 0.5, y: 0.08, size: 64, look: .label)]
    ),
    DesignTemplate(
        id: "k-holiday", name: String(localized: "Holiday dump"), category: .holidays, mode: .carousel,
        style: .wall, gap: 22, bg: "#efe6d8", frame: .tape, frameColor: "#fbfaf6", frameWidth: 12,
        captions: [caption(String(localized: "holiday dump"), .hand, x: 0.5, y: 0.5, size: 80, color: "#3b2f2a", look: .label)]
    ),
    DesignTemplate(
        id: "k-noir", name: String(localized: "Noir story"), category: .minimal, mode: .carousel,
        style: .flow, bg: "#0b0b0d", filter: .noir,
        captions: [
            caption(String(localized: "chapter one"), .magazine, x: 0.5, y: 0.06, size: 70, color: "#f2f2f2"),
            caption(String(localized: "swipe →"), .typewriter, x: 1.82, y: 0.95, size: 34, color: "#bdbdbd"),
        ]
    ),
    DesignTemplate(
        id: "k-polaroid-tour", name: String(localized: "Polaroid tour"), category: .travel, mode: .carousel,
        style: .scatter, bg: "#e8dcc6", backdrop: pattern(.dots), frame: .instant, frameColor: "#fbfaf6", filter: .film,
        captions: [caption(String(localized: "the trip"), .hand, x: 0.5, y: 0.5, size: 96, color: "#3b2f2a", rotation: -6)],
        stickers: [emoji("🗺️", x: 1.5, y: 0.9, w: 0.12, tilt: 8), emoji("📍", x: 0.85, y: 0.12, w: 0.08)]
    ),
    DesignTemplate(
        id: "k-neon-wave", name: String(localized: "Neon wave"), category: .friends, tags: [.party], mode: .carousel,
        style: .wave, bg: "#07070b", frame: .neon, frameColor: "#3de0ff",
        captions: [caption(String(localized: "night out"), .retro, x: 0.5, y: 0.9, size: 92, color: "#ff4fd8", look: .neon)]
    ),
    DesignTemplate(
        id: "k-magazine", name: String(localized: "Magazine spread"), category: .moodboard, mode: .carousel,
        style: .mosaic, gap: 10, bg: "#f6f1ea", filter: .chrome,
        captions: [
            caption(String(localized: "THE EDIT"), .magazine, x: 0.5, y: 0.5, size: 110, color: "#ffffff", allCaps: true),
            caption(String(localized: "VOL. 2"), .poster, x: 0.06, y: 0.5, size: 30, color: "#ffffff", allCaps: true, vertical: true),
        ]
    ),
    DesignTemplate(
        id: "k-golden", name: String(localized: "Golden days"), category: .travel, mode: .carousel,
        style: .duo, gap: 12, radius: 20, backdrop: gradient(1), filter: .warm,
        captions: [caption(String(localized: "golden days"), .romance, x: 0.5, y: 0.5, size: 100, color: "#fff3e0")]
    ),
    DesignTemplate(
        id: "k-stamps", name: String(localized: "Stamp journey"), category: .travel, mode: .carousel,
        style: .stagger, gap: 24, bg: "#e9dfcf", frame: .stamp, frameColor: "#fbfaf6", frameWidth: 16, filter: .vintage,
        captions: [caption(String(localized: "par avion"), .typewriter, x: 0.5, y: 0.6, size: 44, color: "#2b4a8b", look: .label, rotation: -5)]
    ),
    DesignTemplate(
        id: "k-torn-wall", name: String(localized: "Torn wall"), category: .scrapbook, mode: .carousel,
        style: .wall, gap: 20, bg: "#d9cdb8", backdrop: pattern(.grid), frame: .torn, frameColor: "#fbfaf6",
        cellFrames: [.torn, .tape, .instant],
        captions: [caption(String(localized: "collected moments"), .note, x: 0.5, y: 0.5, size: 72, color: "#3b2416", look: .label)]
    ),
    DesignTemplate(
        id: "k-chapters", name: String(localized: "Chapters"), category: .travel, mode: .carousel,
        style: .flow, bg: "#0e0e12", filter: .film,
        captions: [
            caption(String(localized: "chapter one\nArrival"), .magazine, x: 0.5, y: 0.1, size: 70, color: "#ffffff", look: .plate, mix: .lead, accent: .typewriter),
            caption(String(localized: "chapter two\nWandering"), .magazine, x: 1.5, y: 0.1, size: 70, color: "#ffffff", look: .plate, mix: .lead, accent: .typewriter),
            caption(String(localized: "chapter three\nGoodbye"), .magazine, x: 2.5, y: 0.1, size: 70, color: "#ffffff", look: .plate, mix: .lead, accent: .typewriter),
        ]
    ),
    DesignTemplate(
        id: "k-scrap-journey", name: String(localized: "Scrapbook journey"), category: .scrapbook, mode: .carousel,
        style: .scatter, bg: "#efe6d8", backdrop: pattern(.grid), frameColor: "#fbfaf6", frameWidth: 14,
        cellFrames: [.instant, .tape, .stamp, .torn],
        captions: [caption(String(localized: "where we\nwandered"), .note, x: 0.5, y: 0.52, size: 72, color: "#7a3b2e", look: .label, rotation: -4)],
        stickers: [emoji("✂️", x: 1.0, y: 0.06, w: 0.1, tilt: 30), emoji("🗺️", x: 2.0, y: 0.92, w: 0.12, tilt: -10),
                   emoji("📎", x: 0.12, y: 0.1, w: 0.08, tilt: -20)]
    ),
    DesignTemplate(
        id: "k-film-diary", name: String(localized: "Film diary"), category: .photoDump, mode: .carousel,
        style: .squareFlow, bg: "#141416", frameColor: "#101016", frameWidth: 26,
        cellFrames: [.film, .date], filter: .film,
        captions: [caption(String(localized: "roll 02 · 36 exp"), .typewriter, x: 0.5, y: 0.04, size: 30, color: "#ff9a3c")]
    ),
    DesignTemplate(
        id: "k-postcards", name: String(localized: "Postcards"), category: .travel, mode: .carousel,
        style: .stagger, gap: 22, bg: "#e9dfcf", backdrop: pattern(.stripes), frameColor: "#fbfaf6", frameWidth: 16,
        cellFrames: [.stamp, .border], filter: .vintage,
        captions: [caption(String(localized: "greetings\nfrom far away"), .script, x: 0.5, y: 0.55, size: 90, color: "#2b4a8b", look: .label,
                           rotation: -5, mix: .tail, accent: .typewriter)],
        stickers: [shape("seal.fill", color: "#c0392b", x: 0.9, y: 0.08, w: 0.1, tilt: 12)]
    ),
    DesignTemplate(
        id: "k-party-wall", name: String(localized: "Party wall"), category: .birthday, tags: [.party], mode: .carousel,
        style: .wall, gap: 18, bg: "#1b1030", backdrop: pattern(.confetti), frameColor: "#ffffff", frameWidth: 10,
        cellFrames: [.instant, .shadow, .neon], filter: .vivid,
        captions: [caption(String(localized: "best night\nEVER"), .retro, x: 0.5, y: 0.5, size: 140, color: "#ff4fd8", look: .neon, mix: .tail, accent: .poster)]
    ),
    DesignTemplate(
        id: "k-moodboard", name: String(localized: "Mood swipe"), category: .moodboard, mode: .carousel,
        style: .mosaic, gap: 8, bg: "#e9e2d6", cellFrames: [.none, .none, .circle, .none, .arch], filter: .fade,
        captions: [
            caption(String(localized: "MOOD"), .poster, x: 0.06, y: 0.5, size: 40, color: "#ffffff", allCaps: true, vertical: true),
            caption(String(localized: "soft season"), .romance, x: 1.5, y: 0.5, size: 90, color: "#ffffff"),
        ]
    ),
    DesignTemplate(
        id: "k-wave", name: String(localized: "Summer wave"), category: .friends, tags: [.beach], mode: .carousel,
        style: .wave, radius: 18, backdrop: gradient(6),
        captions: [caption(String(localized: "summer"), .dreamy, x: 0.5, y: 0.1, size: 96, color: "#5a3a00")],
        stickers: [emoji("☀️", x: 0.9, y: 0.12, w: 0.12)]
    ),
]

func templates(for mode: EditMode?, category: TemplateCategory? = nil) -> [DesignTemplate] {
    allTemplates.filter { t in
        (mode == nil || t.mode == mode) && (category.map { t.category == $0 || t.tags.contains($0) } ?? true)
    }
}

// MARK: - Previews

/// Pictures of templates for the browser: filled with the person's own pictures when there are some, otherwise with
/// soft sample scenes. Drawn by the same renderer as the editor and exports, so a template looks exactly as it will.
/// Drawing happens off the main thread (the renderer is plain Core Graphics, as in exports), so a list of cards scrolls
/// smoothly while their pictures are made.
enum TemplatePreview {
    private static let cache = NSCache<NSString, UIImage>()

    private static func key(_ t: DesignTemplate, _ photos: [MediaItem]) -> NSString {
        "\(t.id)|\(photos.map(\.id).joined(separator: ","))" as NSString
    }

    /// A preview already drawn, if there is one (so a card that scrolls back into view shows it at once).
    static func cached(_ t: DesignTemplate, pictures: [MediaItem] = []) -> UIImage? {
        cache.object(forKey: key(t, pictures.filter { $0.kind == .photo }))
    }

    /// Animation frames by template, priced in bytes: a motion card holds 10–50 frames, so a count limit kept too few.
    private static let motionCache: NSCache<NSString, NSArray> = {
        let cache = NSCache<NSString, NSArray>()
        cache.totalCostLimit = 96 * 1_048_576
        return cache
    }()
    static let motionFrameCount = 12

    /// Seconds each frame of a card's animation stays up. A motion template's card plays the design itself, in real time.
    static func frameInterval(_ t: DesignTemplate) -> Double { t.motion == nil ? 0.16 : 0.2 }

    static func cachedMotionFrames(_ t: DesignTemplate) -> [UIImage]? {
        motionCache.object(forKey: t.id as NSString) as? [UIImage]
    }

    /// A card's animation frames. They are drawn once in the background and kept: a card that scrolls away before they
    /// are ready leaves the work running, and one that comes back joins it instead of starting over.
    static func motionFrames(_ t: DesignTemplate) async -> [UIImage] {
        if let frames = cachedMotionFrames(t) { return frames }
        return await MotionFrameJobs.shared.frames(for: t)
    }

    fileprivate static func renderMotionFrames(_ t: DesignTemplate) -> [UIImage] {
        let count = t.motion.map { max(2, Int(($0.total / frameInterval(t)).rounded())) } ?? motionFrameCount
        var frames: [UIImage] = []
        var bytes = 0
        for index in 0..<count {
            let phase = Double(index) * 2 * .pi / Double(count)
            guard let frame = draw(t, photos: [], phase: phase) else { continue }
            frames.append(frame)
            bytes += frame.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        }
        if !frames.isEmpty { motionCache.setObject(frames as NSArray, forKey: t.id as NSString, cost: bytes) }
        return frames
    }

    /// The card's still picture, drawn in the background the first time and kept.
    static func image(_ t: DesignTemplate, pictures: [MediaItem] = []) async -> UIImage? {
        let photos = pictures.filter { $0.kind == .photo }
        let key = key(t, photos)
        if let hit = cache.object(forKey: key) { return hit }
        let img = await Task.detached(priority: .userInitiated) { draw(t, photos: photos) }.value
        if let img { cache.setObject(img, forKey: key) }
        return img
    }

    private static func draw(_ t: DesignTemplate, photos: [MediaItem], phase: Double? = nil) -> UIImage? {
        let items = photos.isEmpty ? samples : photos
        // a carousel preview stays readable: four sample pictures (about three slides), or the person's own pictures
        let wanted = t.mode == .collage ? t.slots : (photos.isEmpty ? 4 : min(items.count, maxCarouselPhotos))
        let ids = (0..<wanted).map { items[$0 % items.count].id }
        let unique = t.mode == .collage ? ids : Array(ids.prefix(items.count))
        var project = t.project(basedOn: Project(), pictures: unique)
        // a motion template's card runs through its scenes; a living one sways its main picture
        var time = 0.0
        if let phase, let motion = project.motion {
            time = phase / (2 * .pi) * motion.total
        } else if let phase, !project.cells.isEmpty {
            project.cells[0].zoom = 1.24 + 0.12 * cos(phase)
            project.cells[0].panX = 0.55 * sin(phase)
        }
        let byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let maxSide = phase == nil ? 520.0 : (project.motion == nil ? 360.0 : 280.0)
        let k = maxSide / max(project.canvasWidth, project.canvasHeight)
        let w = max(1, Int((project.canvasWidth * k).rounded())), h = max(1, Int((project.canvasHeight * k).rounded()))
        guard let ctx = CollageRenderer.makeContext(width: w, height: h) else { return nil }
        // a still card of a motion template shows its last scene, with every picture in it
        if phase == nil, let motion = project.motion { time = motion.total }
        CollageRenderer.draw(ctx: ctx, W: Double(w), H: Double(h), snapshot: ExportSnapshot(project: project, items: byId), t: time) { id in
            // a small card: the 420 px tray thumbnail is plenty, and decodes nothing new
            guard let item = byId[id] else { return nil }
            return (item.fixedPreview ?? item.thumbnail).cgImage
        }
        guard let cg = ctx.makeImage() else { return nil }
        return UIImage(cgImage: cg)
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
            return MediaItem(id: "sample-\(i)", kind: .photo, url: URL(fileURLWithPath: "/dev/null"), name: String(localized: "Sample"),
                             width: Double(size.width), height: Double(size.height), duration: 0, hasAudio: false,
                             thumbnail: img, preview: img)
        }
    }()
}

/// One background drawing of a motion card's frames per template at a time, shared by every card that asks for it.
private actor MotionFrameJobs {
    static let shared = MotionFrameJobs()
    private var running: [String: Task<[UIImage], Never>] = [:]

    func frames(for t: DesignTemplate) async -> [UIImage] {
        if let job = running[t.id] { return await job.value }
        let job = Task.detached(priority: .utility) { TemplatePreview.renderMotionFrames(t) }
        running[t.id] = job
        let frames = await job.value
        running[t.id] = nil
        return frames
    }
}
