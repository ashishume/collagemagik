import SwiftUI
import UIKit

/// An emoji or a shape laid on the design. It sits above the photos on top and below the captions, and can be moved,
/// pinched, twisted and flipped like them. Shapes take a colour; emoji keep their own.
struct Sticker: Identifiable, Equatable, Codable {
    var id: String = UUID().uuidString
    var kind: StickerKind
    /// The emoji itself, or an SF Symbol name for a shape.
    var content: String
    var color: String = "#ffffff"
    /// Centre. `cx` is in slide widths (0...slides), `cy` is 0...1 down the design.
    var cx: Double
    var cy: Double
    /// Side of the sticker's square, in slide widths.
    var w: Double = 0.24
    /// Degrees, clockwise.
    var tilt: Double = 0
    var flip: Bool = false
}

enum StickerKind: String, Codable { case emoji, shape }

/// Most stickers on one design.
let maxStickers = 30
/// Smallest and largest a sticker can be, in slide widths.
let stickerSizeRange: ClosedRange<Double> = 0.06...1.0

/// The sticker picker's groups.
enum StickerGroup: String, PanelSection {
    case faces, love, fun, shapes
    var id: String { rawValue }
    var title: String {
        switch self {
        case .faces: "Faces"
        case .love: "Love"
        case .fun: "Fun"
        case .shapes: "Shapes"
        }
    }
    var symbol: String {
        switch self {
        case .faces: "face.smiling"
        case .love: "heart"
        case .fun: "party.popper"
        case .shapes: "star"
        }
    }
    var kind: StickerKind { self == .shapes ? .shape : .emoji }

    var items: [String] {
        switch self {
        case .faces:
            ["😀", "😂", "🥹", "😍", "🥰", "😎", "🤩", "😜", "🤗", "😇", "🥳", "😭", "😴", "🤔", "🙃", "😏", "🤯", "😱", "🫶", "👍", "👏", "🙌", "✌️", "🤞", "💪", "🙈"]
        case .love:
            ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "💖", "💘", "💝", "💕", "💞", "💗", "💓", "❣️", "💋", "🌹", "💐", "💍", "🥂", "😘"]
        case .fun:
            ["🎉", "🎂", "🎈", "🎁", "✨", "🌟", "⭐️", "🔥", "💯", "👑", "🌈", "☀️", "🌙", "⚡️", "🍕", "🍦", "☕️", "📸", "✈️", "🏖️", "🌸", "🌻", "🍀", "🦋", "🐶", "🐱", "🎵", "🏆"]
        case .shapes:
            ["heart.fill", "star.fill", "sparkle", "sparkles", "circle.fill", "square.fill", "triangle.fill", "diamond.fill",
             "seal.fill", "burst.fill", "bolt.fill", "flame.fill", "sun.max.fill", "moon.fill", "cloud.fill", "crown.fill",
             "music.note", "camera.fill", "location.fill", "hand.thumbsup.fill", "arrow.right", "arrow.down.right",
             "arrowshape.right.fill", "quote.opening", "checkmark.seal.fill", "scribble.variable"]
        }
    }
}

let stickerSwatches = ["#ffffff", "#101016", "#ff5fa2", "#ff7a45", "#ffd166", "#52d98c", "#4dc7ff", "#8b6cff"]

extension Project {
    /// Where a sticker is drawn on a canvas `W` × `H`: a square, turned by its tilt.
    func stickerRect(_ s: Sticker, W: Double, H: Double) -> PxRect {
        let slideW = W / canvasWidth * format.width
        let side = clamp(s.w, stickerSizeRange.lowerBound, stickerSizeRange.upperBound) * slideW
        let cx = clamp(s.cx, 0, Double(slides)) * slideW
        let cy = clamp(s.cy, 0, 1) * H
        return PxRect(x: cx - side / 2, y: cy - side / 2, w: side, h: side, tilt: s.tilt)
    }
}

/// Draws stickers. The preview and every export use this, so what you see is what you get.
enum StickerRenderer {
    private static let cache = NSCache<NSString, UIImage>()

    /// The sticker as a square image `side` pixels across (kept, so a video export makes it once).
    static func image(_ s: Sticker, side: Double) -> UIImage? {
        // sizes are bucketed so a pinch doesn't make a new image for every step
        let px = max(16, min(1600, (side / 8).rounded(.up) * 8))
        let key = "\(s.kind.rawValue)|\(s.content)|\(s.color)|\(Int(px))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: px, height: px)
        let made: UIImage
        switch s.kind {
        case .emoji:
            made = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                let font = UIFont.systemFont(ofSize: px * 0.82)
                let text = s.content as NSString
                let attrs: [NSAttributedString.Key: Any] = [.font: font]
                let b = text.size(withAttributes: attrs)
                text.draw(at: CGPoint(x: (px - b.width) / 2, y: (px - b.height) / 2), withAttributes: attrs)
            }
        case .shape:
            let config = UIImage.SymbolConfiguration(pointSize: px * 0.8, weight: .semibold)
            guard let symbol = UIImage(systemName: s.content, withConfiguration: config)?
                .withTintColor(UIColor(hex: s.color), renderingMode: .alwaysOriginal) else { return nil }
            made = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                let sz = symbol.size
                let fit = min(px * 0.92 / sz.width, px * 0.92 / sz.height)
                let w = sz.width * fit, h = sz.height * fit
                symbol.draw(in: CGRect(x: (px - w) / 2, y: (px - h) / 2, width: w, height: h))
            }
        }
        cache.setObject(made, forKey: key)
        return made
    }

    /// Draws every sticker into a top-left-origin context.
    static func drawAll(ctx: CGContext, project: Project, W: Double, H: Double) {
        for s in project.stickers {
            let r = project.stickerRect(s, W: W, H: H)
            guard let img = image(s, side: r.w)?.cgImage else { continue }
            ctx.saveGState()
            let c = r.center
            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: r.tilt * RAD)
            if s.flip { ctx.scaleBy(x: -1, y: 1) }
            ctx.scaleBy(x: 1, y: -1) // images are drawn upright in a flipped context
            ctx.draw(img, in: CGRect(x: -r.w / 2, y: -r.h / 2, width: r.w, height: r.h))
            ctx.restoreGState()
        }
    }
}

// MARK: - Store actions

extension CollageStore {
    func sticker(_ id: String?) -> Sticker? { id.flatMap { id in project.stickers.first { $0.id == id } } }

    /// Selects a sticker and shows its tools (nil clears the selection).
    func selectSticker(_ id: String?) {
        if id != nil {
            if selectedCell != nil { selectCell(nil) }
            swapFrom = nil
            selectedCaption = nil
            if selectedOverlay != nil { selectOverlay(nil) }
            if tab != .text { withAnimation(.smooth) { tab = .text } }
        }
        if id != selectedSticker {
            selectedSticker = id
            if id != nil { UISelectionFeedbackGenerator().selectionChanged() }
        }
    }

    /// Adds a sticker in the middle of the slide on screen, a little apart from the last one, and selects it.
    func addSticker(_ content: String, kind: StickerKind) {
        guard project.stickers.count < maxStickers else {
            notify("Up to \(maxStickers) stickers fit on one design. Remove one to add another.")
            return
        }
        let n = project.stickers.count
        let base = isCarousel ? Double(visibleSlide - 1) + 0.5 : 0.5
        var s = Sticker(kind: kind, content: content, cx: base + Double(n % 4 - 1) * 0.08, cy: 0.42 + Double(n % 3) * 0.07)
        if kind == .shape { s.color = project.stickers.last(where: { $0.kind == .shape })?.color ?? "#ffffff" }
        s.tilt = [0, -8, 6, -4, 10][n % 5]
        project.stickers.append(s)
        selectSticker(s.id)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func updateSticker(_ id: String, _ patch: (inout Sticker) -> Void) {
        guard let i = project.stickers.firstIndex(where: { $0.id == id }) else { return }
        var s = project.stickers[i]
        patch(&s)
        s.cx = clamp(s.cx, 0, Double(project.slides))
        s.cy = clamp(s.cy, 0, 1)
        s.w = clamp(s.w, stickerSizeRange.lowerBound, stickerSizeRange.upperBound)
        s.tilt = clamp(s.tilt, -180, 180)
        project.stickers[i] = s
    }

    func removeSticker(_ id: String) {
        project.stickers.removeAll { $0.id == id }
        if selectedSticker == id { selectSticker(nil) }
    }

    func duplicateSticker(_ id: String) {
        guard let src = sticker(id), project.stickers.count < maxStickers else { return }
        var s = src
        s.id = UUID().uuidString
        s.cx += 0.06
        s.cy += 0.04
        project.stickers.append(s)
        updateSticker(s.id) { _ in }
        selectSticker(s.id)
    }

    /// Moves a sticker one step towards the viewer (up) or away.
    func restackSticker(_ id: String, up: Bool) {
        guard let i = project.stickers.firstIndex(where: { $0.id == id }) else { return }
        let j = up ? i + 1 : i - 1
        guard project.stickers.indices.contains(j) else { return }
        project.stickers.swapAt(i, j)
    }
}
