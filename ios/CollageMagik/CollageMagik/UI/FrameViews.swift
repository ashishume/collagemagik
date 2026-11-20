import SwiftUI

/// The outline a picture is cut to in the live preview: the same path the export clips to (`pictureClipPath`).
struct PictureShape: Shape {
    let frame: PhotoFrame
    let radius: Double

    func path(in rect: CGRect) -> Path { Path(pictureClipPath(frame, rect: rect, radius: radius)) }
}

/// A frame's extras (film holes under the picture; tape, mat line, date stamp or neon over it) in the live preview,
/// drawn by the very code the export uses (`FrameDecor`). It is a little larger than the print, so glows and tape that
/// reach past the edge aren't cut off. `picture` is in the print's own space (0, 0 = its top-left corner).
struct FrameDecorLayer: View {
    let frame: PhotoFrame
    let size: CGSize
    let picture: CGRect
    let color: String
    let unit: Double
    let seed: Int
    let over: Bool

    var body: some View {
        let pad = max(24, 60 * unit)
        Canvas { ctx, _ in
            ctx.withCGContext { cg in
                cg.translateBy(x: pad, y: pad)
                let outer = CGRect(origin: .zero, size: size)
                if over {
                    FrameDecor.drawOver(cg, frame: frame, outer: outer, picture: picture, color: color, unit: unit, seed: seed)
                } else {
                    FrameDecor.drawUnder(cg, frame: frame, outer: outer, picture: picture, color: color, unit: unit)
                }
            }
        }
        .frame(width: size.width + pad * 2, height: size.height + pad * 2)
        .offset(x: -pad, y: -pad)
        .allowsHitTesting(false)
    }
}

extension PhotoFrame {
    /// Does this frame draw anything beyond its edge and shadow?
    var hasDecor: Bool { self == .film || self == .tape || self == .gallery || self == .date || self == .neon }

    /// Corner radius of a photo laid on top with this frame.
    func printRadius(unit: Double) -> Double {
        switch self {
        case .torn, .stamp, .film: 0
        case .neon: 16 * unit
        default: 3 * unit
        }
    }
}
