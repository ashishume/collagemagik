import CoreText
import SwiftUI
import UIKit

/// Most captions on one design, and the longest a caption can be.
let maxCaptions = 8
let maxCaptionLength = 140
/// Caption size in pixels at 1080 wide.
let captionSizeRange: ClosedRange<Double> = 28...240
/// A caption wraps so it never gets wider than this much of one slide.
let captionMaxWidth = 0.88

/// Script fonts that ship inside the app (all SIL Open Font License, from Google Fonts; the licences are in Fonts/).
/// They are registered the first time any caption font is asked for.
enum BundledFonts {
    static let registered: Bool = {
        let names = ["GreatVibes-Regular", "MrsSaintDelafield-Regular", "Sacramento-Regular", "Caveat"]
        for n in names {
            guard let url = Bundle.main.url(forResource: n, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()
}

/// The lettering styles. Most ship with iOS; Vows, Signature, Dreamy and Diary are bundled (see `BundledFonts`).
enum CaptionFont: String, CaseIterable, Identifiable {
    case classic, script, vows, signature, dreamy, diary, hand, italic, rounded, serif, marker, poster, typewriter, chalk
    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic: "Classic"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .italic: "Elegant"
        case .script: "Script"
        case .vows: "Vows"
        case .signature: "Signature"
        case .dreamy: "Dreamy"
        case .diary: "Diary"
        case .hand: "Hand"
        case .marker: "Marker"
        case .poster: "Poster"
        case .typewriter: "Typed"
        case .chalk: "Chalk"
        }
    }

    /// Some typefaces look small or large at the same point size: this evens them out.
    private var sizeFactor: Double {
        switch self {
        case .script: 1.3
        case .vows: 1.45
        case .signature: 1.7
        case .dreamy: 1.55
        case .diary: 1.2
        case .italic, .hand: 1.1
        case .poster: 1.12
        case .chalk: 0.82
        default: 1
        }
    }

    /// Extra room around the letters, as a fraction of the size (script letters swing far outside their line box).
    var overhang: Double {
        switch self {
        case .script, .vows, .dreamy: 0.3
        case .signature: 0.45
        default: 0.12
        }
    }

    /// Flowing scripts whose letters join up: they sit on tighter lines.
    var isScript: Bool { self == .script || self == .vows || self == .signature || self == .dreamy }

    /// Line spacing (a multiple of the font's own line height). The bundled scripts have small letters on very tall
    /// lines, so they are pulled together to about the same spacing as Script.
    var lineSpacing: Double {
        switch self {
        case .script: 0.92
        case .vows: 0.82
        case .signature: 0.5
        case .dreamy: 0.68
        default: 1.02
        }
    }

    func uiFont(size: Double) -> UIFont {
        _ = BundledFonts.registered
        let s = CGFloat(size * sizeFactor)
        func system(_ weight: UIFont.Weight, _ design: UIFontDescriptor.SystemDesign) -> UIFont {
            let base = UIFont.systemFont(ofSize: s, weight: weight)
            return base.fontDescriptor.withDesign(design).map { UIFont(descriptor: $0, size: s) } ?? base
        }
        func named(_ name: String) -> UIFont { UIFont(name: name, size: s) ?? .systemFont(ofSize: s, weight: .bold) }
        switch self {
        case .classic: return .systemFont(ofSize: s, weight: .bold)
        case .rounded: return system(.heavy, .rounded)
        case .serif: return system(.bold, .serif)
        case .italic: return named("Baskerville-SemiBoldItalic")
        case .script: return named("SnellRoundhand-Bold")
        case .vows: return named("GreatVibes-Regular")
        case .signature: return named("MrsSaintDelafield-Regular")
        case .dreamy: return named("Sacramento-Regular")
        case .diary:
            // a variable font: ask for a semibold weight so it reads on busy photos
            let wght = 0x7767_6874 // 'wght'
            let d = UIFontDescriptor(fontAttributes: [
                .name: "Caveat-Regular",
                UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wght: 620],
            ])
            let f = UIFont(descriptor: d, size: s)
            return f.fontName.hasPrefix("Caveat") ? f : named("BradleyHandITCTT-Bold")
        case .hand: return named("BradleyHandITCTT-Bold")
        case .marker: return named("MarkerFelt-Wide")
        case .poster: return named("Futura-CondensedExtraBold")
        case .typewriter: return named("AmericanTypewriter-Semibold")
        case .chalk: return named("Chalkduster")
        }
    }
}

/// What sits behind the letters so they stay readable on any photo.
enum CaptionLook: String, CaseIterable, Identifiable {
    /// Letters with a soft shadow.
    case plain
    /// A solid rounded label in the caption's colour, with the letters in black or white.
    case label
    /// A see-through dark (or light) plate behind the letters.
    case plate
    /// Letters with a thick contrasting edge.
    case outline
    var id: String { rawValue }

    var title: String {
        switch self {
        case .plain: "Shadow"
        case .label: "Label"
        case .plate: "Plate"
        case .outline: "Outline"
        }
    }
    var symbol: String {
        switch self {
        case .plain: "textformat"
        case .label: "a.square.fill"
        case .plate: "a.square"
        case .outline: "character.textbox"
        }
    }
}

enum CaptionAlign: String, CaseIterable {
    case left, center, right

    var symbol: String {
        switch self {
        case .left: "text.alignleft"
        case .center: "text.aligncenter"
        case .right: "text.alignright"
        }
    }
    var next: CaptionAlign {
        switch self {
        case .left: .center
        case .center: .right
        case .right: .left
        }
    }
    var textAlignment: NSTextAlignment {
        switch self {
        case .left: .left
        case .center: .center
        case .right: .right
        }
    }
    var swiftUI: TextAlignment {
        switch self {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
    }
}

/// A small drawing that goes with the words.
enum CaptionOrnament: String, CaseIterable, Identifiable {
    case none, heart, divider, sparkles, swash
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "None"
        case .heart: "Heart"
        case .divider: "Divider"
        case .sparkles: "Sparkles"
        case .swash: "Swash"
        }
    }
    var symbol: String {
        switch self {
        case .none: "circle.slash"
        case .heart: "heart"
        case .divider: "minus"
        case .sparkles: "sparkles"
        case .swash: "scribble"
        }
    }
}

/// Mixing two sizes in one caption, line by line: the small lines use the accent lettering
/// ("woke up to" / THIS VIEW / "Kashmir, you beauty!").
enum CaptionMix: String, CaseIterable, Identifiable {
    case none, lead, tail, both
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "One size"
        case .lead: "Small first line"
        case .tail: "Small last line"
        case .both: "Small first & last"
        }
    }
    var short: String {
        switch self {
        case .none: "Off"
        case .lead: "First"
        case .tail: "Last"
        case .both: "Both"
        }
    }

    /// Which of `count` lines are small.
    func isSmall(_ i: Int, of count: Int) -> Bool {
        guard count > 1 else { return false }
        switch self {
        case .none: return false
        case .lead: return i == 0
        case .tail: return i == count - 1
        case .both: return count >= 3 ? (i == 0 || i == count - 1) : i == 0
        }
    }
}

/// How big the small lines of a mixed caption are, next to the main lines.
let captionAccentScale = 0.44

/// A line of text placed on top of the collage.
struct Caption: Identifiable, Equatable, Codable {
    var id: String = UUID().uuidString
    var text: String = ""
    var font: CaptionFont = .classic
    var color: String = "#ffffff"
    var look: CaptionLook = .plain
    var align: CaptionAlign = .center
    /// Letter size in pixels at 1080 wide.
    var size: Double = 76
    /// Centre of the caption. `x` is in slide widths (0...1 in a collage, 0...slides in a carousel), `y` is 0...1 down the design.
    var x: Double = 0.5
    var y: Double = 0.5
    /// Degrees, clockwise.
    var rotation: Double = 0
    var ornament: CaptionOrnament = .none
    var mix: CaptionMix = .none
    /// Lettering of the small lines when `mix` is on.
    var accentFont: CaptionFont = .diary
    /// Basic text formatting, on top of the lettering style. Lettering without a bold or italic face gets a drawn one.
    var bold: Bool = false
    var italic: Bool = false
    var underline: Bool = false
    var strikethrough: Bool = false
    /// Shown in capital letters (the words keep the case they were typed in).
    var allCaps: Bool = false
}

/// The formatting toggles of a caption, in the order they are shown.
enum CaptionFormat: String, CaseIterable, Identifiable {
    case bold, italic, underline, strikethrough, allCaps
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bold: "Bold"
        case .italic: "Italic"
        case .underline: "Underline"
        case .strikethrough: "Strikethrough"
        case .allCaps: "All caps"
        }
    }
    var symbol: String {
        switch self {
        case .bold: "bold"
        case .italic: "italic"
        case .underline: "underline"
        case .strikethrough: "strikethrough"
        case .allCaps: "textformat.alt"
        }
    }
    var keyPath: WritableKeyPath<Caption, Bool> {
        switch self {
        case .bold: \.bold
        case .italic: \.italic
        case .underline: \.underline
        case .strikethrough: \.strikethrough
        case .allCaps: \.allCaps
        }
    }
}

let captionSwatches = ["#ffffff", "#101016", "#ffd84d", "#ff5fa2", "#ff6b4a", "#8b6cff", "#4cc7ff", "#52d98c", "#f4e9d8"]

extension UIColor {
    /// True for colours that need dark letters on top of them (and a light edge around them).
    var isLight: Bool { brightness > 0.6 }

    /// 0 (black) ... 1 (white), as the eye sees it.
    var brightness: Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return Double(0.299 * r + 0.587 * g + 0.114 * b)
    }
}

// MARK: - Drawing

/// A caption measured for one canvas size: what to draw and how big it is.
struct CaptionLayout {
    var caption: Caption
    /// Letter size in canvas pixels (of the main lines).
    var fontPx: Double
    var text: NSAttributedString
    var textSize: CGSize
    /// The caption's box (letters, decoration and padding), before rotation.
    var box: CGSize
    /// Centre on the canvas, in canvas pixels.
    var center: CGPoint
    /// Where the words sit in the box: their centre, from the box centre (a decoration can take room on one side).
    var textOffset: CGPoint = .zero
    /// The main (big) lines of a mixed caption, as fractions of the text height, and their width as a fraction of the text width.
    var mainTop = 0.0
    var mainBottom = 1.0
    var mainWidth = 1.0
    /// Where the small last line starts, as a fraction of the text height (1 when there is none).
    var tailTop = 1.0
    var rotationRad: Double { caption.rotation * RAD }
    /// Room kept around the box when it is drawn on its own, so shadows and script swashes aren't cut off.
    var bleed: Double { fontPx * 0.6 }

    /// Is the canvas point inside the caption (with a little slack so small captions are easy to touch)?
    func contains(_ p: CGPoint, slack: Double) -> Bool {
        let dx = p.x - center.x, dy = p.y - center.y
        let c = cos(-rotationRad), s = sin(-rotationRad)
        let lx = dx * c - dy * s, ly = dx * s + dy * c
        return abs(lx) <= box.width / 2 + slack && abs(ly) <= box.height / 2 + slack
    }

    /// The same caption measured `k` times bigger (for drawing at screen scale).
    func scaled(_ k: Double) -> CaptionLayout {
        var l = self
        l.fontPx *= k
        l.textSize = CGSize(width: textSize.width * k, height: textSize.height * k)
        l.box = CGSize(width: box.width * k, height: box.height * k)
        l.textOffset = CGPoint(x: textOffset.x * k, y: textOffset.y * k)
        l.text = CaptionRenderer.attributed(caption, fontPx: l.fontPx)
        return l
    }
}

/// Draws captions. The live preview and every export go through here, so what you see is what you get.
enum CaptionRenderer {
    private static let imageCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 48
        return c
    }()

    private static func letterColor(_ c: Caption) -> UIColor {
        let base = UIColor(hex: c.color)
        return c.look == .label ? (base.isLight ? UIColor(hex: "#101016") : .white) : base
    }

    private static func lines(_ c: Caption) -> [String] {
        let text = c.allCaps ? c.text.uppercased() : c.text
        return (text.isEmpty ? " " : text).components(separatedBy: "\n")
    }

    /// The font with the caption's bold / italic asked for. Returns which of the two the typeface couldn't give,
    /// so they can be drawn instead (a thicker edge for bold, a slant for italic).
    private static func formatted(_ f: UIFont, _ c: Caption) -> (font: UIFont, fakeBold: Bool, fakeItalic: Bool) {
        guard c.bold || c.italic else { return (f, false, false) }
        var want = f.fontDescriptor.symbolicTraits
        if c.bold { want.insert(.traitBold) }
        if c.italic { want.insert(.traitItalic) }
        var out = f
        if let d = f.fontDescriptor.withSymbolicTraits(want) {
            let g = UIFont(descriptor: d, size: f.pointSize)
            // keep the lettering: a face from another family is no good (scripts would turn into the system font)
            if g.familyName == f.familyName { out = g }
        }
        let has = out.fontDescriptor.symbolicTraits
        return (out, c.bold && !has.contains(.traitBold), c.italic && !has.contains(.traitItalic))
    }

    /// The font of line `i` of `count` (small lines of a mixed caption use the accent lettering).
    private static func lineFont(_ c: Caption, _ i: Int, _ count: Int, fontPx: Double) -> (font: UIFont, spacing: Double) {
        let (base, spacing) = c.mix.isSmall(i, of: count)
            ? (c.accentFont.uiFont(size: fontPx * captionAccentScale), c.accentFont.lineSpacing)
            : (c.font.uiFont(size: fontPx), c.font.lineSpacing)
        return (formatted(base, c).font, spacing)
    }

    /// Index of the last big line when the small last line follows it (that's where a divider goes).
    private static func lastMainBeforeTail(_ c: Caption, count: Int) -> Int? {
        guard count > 1, c.mix.isSmall(count - 1, of: count), !c.mix.isSmall(count - 2, of: count) else { return nil }
        return count - 2
    }

    /// The words, each line in its own lettering.
    static func attributed(_ c: Caption, fontPx: Double) -> NSAttributedString {
        let ls = lines(c)
        let gapAfter = c.ornament == .divider ? lastMainBeforeTail(c, count: ls.count) : nil
        let out = NSMutableAttributedString()
        for (i, line) in ls.enumerated() {
            let (font, spacing) = lineFont(c, i, ls.count, fontPx: fontPx)
            let para = NSMutableParagraphStyle()
            para.alignment = c.align.textAlignment
            para.lineBreakMode = .byWordWrapping
            para.lineHeightMultiple = spacing
            if i == gapAfter { para.paragraphSpacing = fontPx * 0.6 }
            // a big script line reaches far above its line: keep it off the small line before it
            if i + 1 < ls.count, c.mix.isSmall(i, of: ls.count), !c.mix.isSmall(i + 1, of: ls.count) {
                para.paragraphSpacing = max(para.paragraphSpacing, fontPx * (c.font.isScript ? 0.45 : 0.12))
            }
            var attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: letterColor(c),
                .paragraphStyle: para,
            ]
            let fake = formatted(font, c)
            // negative stroke width = fill and edge, which thickens the letters
            if fake.fakeBold { attrs[.strokeWidth] = -4.0; attrs[.strokeColor] = letterColor(c) }
            if fake.fakeItalic { attrs[.obliqueness] = 0.2 }
            if c.underline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue; attrs[.underlineColor] = letterColor(c) }
            if c.strikethrough { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue; attrs[.strikethroughColor] = letterColor(c) }
            out.append(NSAttributedString(string: line + (i < ls.count - 1 ? "\n" : ""), attributes: attrs))
        }
        return out
    }

    private static func measure(_ t: NSAttributedString, _ maxW: Double) -> CGSize {
        let b = t.boundingRect(
            with: CGSize(width: maxW, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil
        )
        return CGSize(width: ceil(b.width), height: ceil(b.height))
    }

    /// Room a decoration takes beside the words, in letter sizes: right, top, bottom.
    private static func ornamentRoom(_ c: Caption, lineCount: Int) -> (right: Double, top: Double, bottom: Double) {
        switch c.ornament {
        case .none: (0, 0, 0)
        case .heart: (0.85, 0, 0)
        case .divider: lastMainBeforeTail(c, count: lineCount) == nil ? (0, 0, 0.6) : (0, 0, 0)
        case .sparkles: (0.5, 0.35, 0)
        case .swash: (0, 0, 0.55)
        }
    }

    /// Measures a caption for a canvas `W` pixels wide showing a design `canvasWidth` "1080 pixels" wide.
    /// The letters are made smaller than asked for when they wouldn't fit: no word is ever broken in two, and the
    /// caption is never taller than the design.
    static func layout(_ c: Caption, project: Project, W: Double, H: Double) -> CaptionLayout {
        let unit = W / project.canvasWidth
        let slideW = project.format.width * unit
        let boxed = c.look == .label || c.look == .plate
        let ls = lines(c)
        let room = ornamentRoom(c, lineCount: ls.count)

        var fontPx = clamp(c.size, captionSizeRange.lowerBound, captionSizeRange.upperBound) * unit
        var text = NSAttributedString()
        var ts = CGSize.zero
        var padX = 0.0, padY = 0.0
        var maxW = 0.0
        let overhang = max(c.font.overhang, c.mix == .none ? 0 : c.accentFont.overhang * captionAccentScale)
        for _ in 0..<6 {
            padX = fontPx * (boxed ? 0.42 : overhang)
            padY = fontPx * (boxed ? 0.2 : 0.08)
            maxW = max(fontPx, slideW * captionMaxWidth - padX * 2 - room.right * fontPx)
            var widest = 0.0
            for (i, line) in ls.enumerated() {
                let font = lineFont(c, i, ls.count, fontPx: fontPx).font
                for w in line.split(separator: " ") {
                    widest = max(widest, (String(w) as NSString).size(withAttributes: [.font: font]).width)
                }
            }
            if widest > maxW {
                fontPx *= maxW / widest * 0.98
                continue
            }
            text = attributed(c, fontPx: fontPx)
            ts = measure(text, maxW)
            let tall = (ts.height + padY * 2 + (room.top + room.bottom) * fontPx) / (H * 0.9)
            if tall <= 1 { break }
            fontPx *= max(0.5, 1 / tall.squareRoot()) * 0.98
        }

        // where the big lines are, for decorations that sit beside or under them
        var mainTop = 0.0, mainBottom = 1.0, mainWidth = 1.0, tailTop = 1.0
        // one size: a heart goes after the last line, so treat that line as the "main" one
        let mains = c.mix == .none ? [ls.count - 1] : ls.indices.filter { !c.mix.isSmall($0, of: ls.count) }
        if let first = mains.first, let last = mains.last, ls.count > 1, ts.height > 0 {
            func part(_ r: Range<Int>) -> NSAttributedString {
                let starts = ls.indices.map { i in ls[..<i].reduce(0) { $0 + ($1 as NSString).length + 1 } }
                let a = starts[r.lowerBound]
                let b = r.upperBound < ls.count ? starts[r.upperBound] - 1 : text.length
                return text.attributedSubstring(from: NSRange(location: a, length: max(0, b - a)))
            }
            if first > 0 { mainTop = min(1, measure(part(0..<first), maxW).height / ts.height) }
            mainBottom = min(1, measure(part(0..<(last + 1)), maxW).height / ts.height)
            if last + 1 < ls.count { tailTop = max(mainBottom, 1 - measure(part((last + 1)..<ls.count), maxW).height / ts.height) }
            if ts.width > 0 { mainWidth = min(1, measure(part(first..<(last + 1)), maxW).width / ts.width) }
        }

        let box = CGSize(
            width: ts.width + padX * 2 + room.right * fontPx,
            height: ts.height + padY * 2 + (room.top + room.bottom) * fontPx
        )
        let offset = CGPoint(x: -room.right * fontPx / 2, y: (room.top - room.bottom) * fontPx / 2)
        // The whole caption stays inside the design, however it is turned or sized: nothing is ever cut off at an edge.
        let cosT = abs(cos(c.rotation * RAD)), sinT = abs(sin(c.rotation * RAD))
        let margin = slideW * 0.015
        let halfW = (box.width * cosT + box.height * sinT) / 2 + margin
        let halfH = (box.width * sinT + box.height * cosT) / 2 + margin
        func inside(_ v: Double, _ half: Double, _ full: Double) -> Double { half * 2 >= full ? full / 2 : clamp(v, half, full - half) }
        return CaptionLayout(
            caption: c, fontPx: fontPx, text: text, textSize: ts, box: box,
            center: CGPoint(x: inside(c.x * slideW, halfW, W), y: inside(c.y * H, halfH, H)),
            textOffset: offset, mainTop: mainTop, mainBottom: mainBottom, mainWidth: mainWidth, tailTop: tailTop
        )
    }

    /// The decoration's outline, centred on the same origin as the caption. `filled` shapes are filled, the rest stroked.
    private static func ornamentPath(_ l: CaptionLayout) -> (path: CGPath, filled: Bool, width: Double)? {
        let f = l.fontPx
        let tw = l.textSize.width, th = l.textSize.height
        let left = l.textOffset.x - tw / 2, right = l.textOffset.x + tw / 2
        let top = l.textOffset.y - th / 2, bottom = l.textOffset.y + th / 2
        let mainW = tw * l.mainWidth
        let mainRight: Double = switch l.caption.align {
        case .left: left + mainW
        case .center: l.textOffset.x + mainW / 2
        case .right: right
        }
        let path = CGMutablePath()
        switch l.caption.ornament {
        case .none:
            return nil
        case .heart:
            let s = f * 0.5
            let cx = mainRight + f * 0.45
            let cy = top + th * (l.mainTop + l.mainBottom) / 2
            path.move(to: CGPoint(x: cx, y: cy + s * 0.45))
            path.addCurve(to: CGPoint(x: cx - s * 0.5, y: cy - s * 0.2), control1: CGPoint(x: cx - s * 0.2, y: cy + s * 0.25), control2: CGPoint(x: cx - s * 0.5, y: cy + s * 0.08))
            path.addCurve(to: CGPoint(x: cx, y: cy - s * 0.22), control1: CGPoint(x: cx - s * 0.5, y: cy - s * 0.55), control2: CGPoint(x: cx - s * 0.05, y: cy - s * 0.55))
            path.addCurve(to: CGPoint(x: cx + s * 0.5, y: cy - s * 0.2), control1: CGPoint(x: cx + s * 0.05, y: cy - s * 0.55), control2: CGPoint(x: cx + s * 0.5, y: cy - s * 0.55))
            path.addCurve(to: CGPoint(x: cx, y: cy + s * 0.45), control1: CGPoint(x: cx + s * 0.5, y: cy + s * 0.08), control2: CGPoint(x: cx + s * 0.2, y: cy + s * 0.25))
            return (path, false, f * 0.05)
        case .divider:
            let y = l.tailTop < 1 ? top + th * (l.mainBottom + l.tailTop) / 2 : bottom + f * 0.3
            let w = l.caption.mix == .none ? tw : min(tw, max(mainW, f * 3))
            let x0: Double = switch l.caption.align {
            case .left: left
            case .center: l.textOffset.x - w / 2
            case .right: right - w
            }
            let xc = x0 + w / 2, gap = f * 0.14
            path.move(to: CGPoint(x: x0, y: y))
            path.addLine(to: CGPoint(x: xc - gap, y: y))
            path.move(to: CGPoint(x: xc + gap, y: y))
            path.addLine(to: CGPoint(x: x0 + w, y: y))
            let r = f * 0.045
            path.addEllipse(in: CGRect(x: xc - r, y: y - r, width: r * 2, height: r * 2))
            return (path, false, f * 0.03)
        case .sparkles:
            func star(_ cx: Double, _ cy: Double, _ r: Double) {
                let k = r * 0.22
                path.move(to: CGPoint(x: cx, y: cy - r))
                path.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + k, y: cy - k))
                path.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx + k, y: cy + k))
                path.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - k, y: cy + k))
                path.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx - k, y: cy - k))
                path.closeSubpath()
            }
            star(right + f * 0.22, top - f * 0.05, f * 0.26)
            star(right + f * 0.42, top + f * 0.28, f * 0.13)
            star(left - f * 0.02, bottom - f * 0.05, f * 0.1)
            return (path, true, f * 0.02)
        case .swash:
            let y0 = bottom + f * 0.22
            let x0 = left + tw * 0.08, x1 = right - tw * 0.04
            let d = x1 - x0
            path.move(to: CGPoint(x: x0, y: y0 + f * 0.06))
            path.addCurve(to: CGPoint(x: x1, y: y0 - f * 0.1), control1: CGPoint(x: x0 + d * 0.35, y: y0 + f * 0.26), control2: CGPoint(x: x0 + d * 0.7, y: y0 - f * 0.2))
            path.addCurve(to: CGPoint(x: x1 - f * 0.4, y: y0 + f * 0.04), control1: CGPoint(x: x1 + f * 0.22, y: y0 - f * 0.22), control2: CGPoint(x: x1 + f * 0.02, y: y0 + f * 0.14))
            return (path, false, f * 0.04)
        }
    }

    private static func drawOrnament(_ l: CaptionLayout, in ctx: CGContext, color: UIColor, extra: Double = 0) {
        guard let o = ornamentPath(l) else { return }
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.addPath(o.path)
        if o.filled {
            ctx.setFillColor(color.cgColor)
            if extra > 0 {
                ctx.setStrokeColor(color.cgColor)
                ctx.setLineWidth(extra)
                ctx.drawPath(using: .fillStroke)
            } else {
                ctx.fillPath()
            }
        } else {
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(o.width + extra)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    /// Draws the caption centred on the origin. The context must be a bitmap context from `CollageRenderer.makeContext`
    /// (top-left origin), which is what both the preview images and the exports use, so shadows match exactly.
    static func draw(_ l: CaptionLayout, in ctx: CGContext) {
        let c = l.caption
        let base = UIColor(hex: c.color)
        let ink = letterColor(c)
        let box = CGRect(x: -l.box.width / 2, y: -l.box.height / 2, width: l.box.width, height: l.box.height)
        // A hair wider and taller than measured, so rounding can never push a word onto a new line or drop the last line.
        let slackX = l.fontPx * 0.03
        let textRect = CGRect(
            x: l.textOffset.x - l.textSize.width / 2 - slackX, y: l.textOffset.y - l.textSize.height / 2,
            width: l.textSize.width + slackX * 2, height: l.textSize.height + l.fontPx
        )
        let opts: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

        UIGraphicsPushContext(ctx)
        defer { UIGraphicsPopContext() }
        ctx.saveGState()
        defer { ctx.restoreGState() }

        switch c.look {
        case .label, .plate:
            let r = min(l.fontPx * 0.36, box.height / 2)
            let path = CGPath(roundedRect: box, cornerWidth: r, cornerHeight: r, transform: nil)
            let fill: UIColor = c.look == .label ? base : (base.isLight ? UIColor.black.withAlphaComponent(0.5) : UIColor.white.withAlphaComponent(0.72))
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: l.fontPx * 0.22, color: UIColor.black.withAlphaComponent(c.look == .label ? 0.3 : 0.18).cgColor)
            ctx.addPath(path)
            ctx.setFillColor(fill.cgColor)
            ctx.fillPath()
            ctx.restoreGState()
            l.text.draw(with: textRect, options: opts, context: nil)
            drawOrnament(l, in: ctx, color: ink)
        case .outline:
            let edgeColor = base.isLight ? UIColor(hex: "#101016") : UIColor.white
            let edge = NSMutableAttributedString(attributedString: l.text)
            let all = NSRange(location: 0, length: edge.length)
            edge.addAttribute(.strokeColor, value: edgeColor, range: all)
            edge.addAttribute(.strokeWidth, value: 14, range: all) // % of the letter size; positive = edge only
            ctx.setLineJoin(.round)
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: l.fontPx * 0.12, color: UIColor.black.withAlphaComponent(0.3).cgColor)
            edge.draw(with: textRect, options: opts, context: nil)
            drawOrnament(l, in: ctx, color: edgeColor, extra: l.fontPx * 0.1)
            ctx.restoreGState()
            l.text.draw(with: textRect, options: opts, context: nil)
            drawOrnament(l, in: ctx, color: ink)
        case .plain:
            let shade = base.isLight ? UIColor.black.withAlphaComponent(0.6) : UIColor.white.withAlphaComponent(0.7)
            ctx.setShadow(offset: .zero, blur: l.fontPx * 0.16, color: shade.cgColor)
            l.text.draw(with: textRect, options: opts, context: nil)
            drawOrnament(l, in: ctx, color: ink)
        }
    }

    /// Every caption of the project, drawn onto a canvas `W` × `H` pixels.
    static func drawAll(ctx: CGContext, project: Project, W: Double, H: Double) {
        for c in project.captions where !c.text.isEmpty {
            let l = layout(c, project: project, W: W, H: H)
            ctx.saveGState()
            ctx.translateBy(x: l.center.x, y: l.center.y)
            ctx.rotate(by: l.rotationRad)
            draw(l, in: ctx)
            ctx.restoreGState()
        }
    }

    /// All captions on a clear layer the size of the canvas. A video export draws this once and stamps it on every frame.
    static func layer(project: Project, W: Int, H: Int) -> CGImage? {
        guard project.captions.contains(where: { !$0.text.isEmpty }),
              let ctx = CollageRenderer.makeContext(width: W, height: H) else { return nil }
        drawAll(ctx: ctx, project: project, W: Double(W), H: Double(H))
        return ctx.makeImage()
    }

    /// One caption as a picture for the live preview (upright; the view turns and places it). `scale` is the screen scale.
    static func image(_ l: CaptionLayout, scale: Double) -> UIImage? {
        let c = l.caption
        let key = "\(c.text)|\(c.font.rawValue)|\(c.color)|\(c.look.rawValue)|\(c.align.rawValue)|\(c.ornament.rawValue)|\(c.mix.rawValue)|\(c.accentFont.rawValue)|\(c.bold)\(c.italic)\(c.underline)\(c.strikethrough)\(c.allCaps)|\(Int((l.fontPx * 100).rounded()))|\(Int(l.box.width.rounded()))|\(Int(l.box.height.rounded()))|\(scale)" as NSString
        if let hit = imageCache.object(forKey: key) { return hit }
        let w = Int(((l.box.width + l.bleed * 2) * scale).rounded(.up))
        let h = Int(((l.box.height + l.bleed * 2) * scale).rounded(.up))
        guard w > 0, h > 0, w < 8192, h < 8192, let ctx = CollageRenderer.makeContext(width: w, height: h) else { return nil }
        // Measure and draw at pixel size, so the shadow is as wide here as it is in an export.
        let big = l.scaled(scale)
        ctx.translateBy(x: Double(w) / 2, y: Double(h) / 2)
        draw(big, in: ctx)
        guard let cg = ctx.makeImage() else { return nil }
        let img = UIImage(cgImage: cg, scale: scale, orientation: .up)
        imageCache.setObject(img, forKey: key)
        return img
    }
}
