import SwiftUI
import UIKit

enum MediaKind { case photo, video }

/// A photo or video the person has added. Files live in the app's temporary folder; export re-reads them at full quality.
struct MediaItem: Identifiable {
    let id: String
    let kind: MediaKind
    let url: URL
    let name: String
    /// Display size in pixels, with orientation / rotation already applied.
    let width: Double
    let height: Double
    /// Seconds. 0 for photos.
    let duration: Double
    let hasAudio: Bool
    let thumbnail: UIImage
    /// Photos: a light copy used by the live preview.
    let preview: UIImage?
}

/// x, y, width, height as fractions (0...1) of the collage area.
struct LayoutRect: Hashable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double
}

/// How a grid layout is split, as fractions that each add up to 1. `rows`: `outer` are band heights from top to
/// bottom and `inner[i]` the cell widths in band i. Otherwise `outer` are column widths and `inner[i]` cell heights.
struct LayoutGrid: Hashable {
    var rows: Bool
    var outer: [Double]
    var inner: [[Double]]

    var rects: [LayoutRect] { gridRects(rows: rows, outer: outer, inner: inner) }

    /// True when `other` splits the same bands into the same number of cells (so its sizes can stand in for these).
    func sameShape(_ other: LayoutGrid) -> Bool {
        rows == other.rows && outer.count == other.outer.count && inner.map(\.count) == other.inner.map(\.count)
    }
}

struct CollageLayout: Identifiable, Hashable {
    let id: String
    let name: String
    let rects: [LayoutRect]
    /// The grid behind the layout, when it is one: its dividers can be dragged to resize the cells.
    var grid: LayoutGrid? = nil
    var count: Int { rects.count }
}

struct CellState: Equatable {
    var mediaId: String? = nil
    /// 1 = the photo or video just covers the cell.
    var zoom: Double = 1
    /// -1...1, 0 = centred.
    var panX: Double = 0
    var panY: Double = 0
    /// Quarter turns clockwise, in degrees: 0, 90, 180 or 270.
    var rotation: Double = 0
    var flip: Bool = false
    /// Straighten: extra tilt in degrees, -45...45.
    var angle: Double = 0

    var view: MediaView {
        MediaView(zoom: zoom, panX: panX, panY: panY, rotation: rotation, flip: flip, angle: angle)
    }
}

/// A piece of a video placed on the timeline. All values are seconds.
struct Clip: Identifiable, Equatable {
    var id: String
    /// Where the clip begins on the timeline.
    var start: Double
    /// Trim: first and last second used from the source file.
    var inPoint: Double
    var outPoint: Double
}

struct Lane: Equatable {
    var mediaId: String
    var clips: [Clip]
    /// Repeat the lane's clips when they end (otherwise the last frame is held).
    var loop: Bool
    /// 0 = muted, 1 = full volume.
    var volume: Double
}

/// Background music (the person's own audio file), shown as its own ribbon on the timeline.
struct MusicTrack: Equatable {
    var url: URL
    var name: String
    var duration: Double
    var volume: Double
    var start: Double
    var inPoint: Double
    var outPoint: Double
    var loop: Bool
    var fadeOut: Bool
}

enum FormatId: String, CaseIterable, Identifiable {
    case story, post, square
    var id: String { rawValue }

    var width: Double { 1080 }
    var height: Double {
        switch self {
        case .story: 1920
        case .post: 1350
        case .square: 1080
        }
    }
    var label: String {
        switch self {
        case .story: "Story 9:16"
        case .post: "Post 4:5"
        case .square: "Square 1:1"
        }
    }
    var short: String {
        switch self {
        case .story: "9:16"
        case .post: "4:5"
        case .square: "1:1"
        }
    }
    /// Instagram carousels take 4:5 or square slides (not 9:16).
    static let carouselFormats: [FormatId] = [.post, .square]
}

/// Collage: one picture or video frame. Carousel: several Instagram slides designed as one long picture, so photos
/// run across the seams between slides and people swipe to see the rest.
enum EditMode: String, CaseIterable, Identifiable {
    case collage, carousel
    var id: String { rawValue }
    var label: String { self == .collage ? "Collage" : "Carousel" }
}

struct Project: Equatable {
    var mode: EditMode = .collage
    var format: FormatId = .story
    var cellCount: Int = initialCellCount
    var layoutId: String = defaultLayout(for: initialCellCount).id {
        // sizes dragged for one layout don't carry over to another
        didSet { if layoutId != oldValue { cellSizes = nil } }
    }
    /// Collage cell sizes the person has dragged the dividers to, or nil for the layout's own sizes.
    var cellSizes: LayoutGrid? = nil
    var cells: [CellState] = Array(repeating: CellState(), count: initialCellCount)
    /// Pixels at 1080 px wide; scaled for other sizes.
    var gap: Double = 12
    var radius: Double = 16
    var bg: String = "#101016"
    var safeZone: Bool = false
    var lanes: [Lane] = []
    var music: MusicTrack? = nil
    /// Text placed on top of the pictures, drawn in order (the last one is on top).
    var captions: [Caption] = []
}

/// The editor's bottom tabs. Picture is not one of them: it opens by itself while a picture is selected.
enum Tab: String, CaseIterable, Identifiable {
    case media, layout, style, text, video, picture
    var id: String { rawValue }
    var label: String {
        switch self {
        case .media: "Media"
        case .layout: "Layout"
        case .style: "Style"
        case .text: "Text"
        case .video: "Video"
        case .picture: "Picture"
        }
    }
    var symbol: String {
        switch self {
        case .media: "photo.on.rectangle.angled"
        case .layout: "square.grid.2x2"
        case .style: "paintpalette"
        case .text: "textformat"
        case .video: "film.stack"
        case .picture: "slider.horizontal.3"
        }
    }

    /// The tabs shown in the dock. Carousels are photos only, so they have no Video tab.
    static func dock(for mode: EditMode) -> [Tab] {
        mode == .carousel ? [.media, .layout, .style, .text] : [.media, .layout, .style, .text, .video]
    }
}

/// Inside the Video tab: cutting clips, or sound.
enum VideoSection: String, CaseIterable, Identifiable {
    case timeline, sound
    var id: String { rawValue }
    var label: String { self == .timeline ? "Timeline" : "Sound" }
}

// MARK: - Colour helpers

extension Color {
    static let brand = Color(red: 0.545, green: 0.424, blue: 1.0)
    static let laneA = Color(red: 1.0, green: 0.37, blue: 0.64)
    static let laneB = Color(red: 0.30, green: 0.78, blue: 1.0)
    static let musicGreen = Color(red: 0.32, green: 0.85, blue: 0.55)

    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }

    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}

extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(
            red: CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255,
            alpha: 1
        )
    }
}

let backgroundSwatches = ["#101016", "#ffffff", "#f4e9d8", "#ffd6e7", "#c9e4ff", "#d4f5dc", "#ff5fa2", "#6c4dff"]
