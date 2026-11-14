import SwiftUI

/// UIKit gesture layer for the preview: tap, drag, pinch, and press-and-hold-then-drag. UIKit lets these coexist cleanly.
struct StageGestureLayer: UIViewRepresentable {
    var onTap: (CGPoint) -> Void
    /// Where the drag started, and how far it had moved when it was recognised.
    var onPanBegin: (CGPoint, CGSize) -> Void
    var onPan: (CGSize) -> Void
    var onPanEnd: (CGSize) -> Void = { _ in }
    var onPinchBegin: (CGPoint) -> Void
    var onPinch: (CGFloat) -> Void
    /// Two-finger twist, in radians (clockwise is positive). Turns the selected caption.
    var onRotateBegin: () -> Void = {}
    var onRotate: (CGFloat) -> Void = { _ in }
    var onRotateEnd: () -> Void = {}
    var onLiftBegin: (CGPoint) -> Void
    var onLiftMove: (CGPoint) -> Void
    var onLiftEnd: (CGPoint, Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        let c = context.coordinator
        let tap = UITapGestureRecognizer(target: c, action: #selector(Coordinator.tap(_:)))
        let pan = UIPanGestureRecognizer(target: c, action: #selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: c, action: #selector(Coordinator.pinch(_:)))
        let long = UILongPressGestureRecognizer(target: c, action: #selector(Coordinator.long(_:)))
        long.minimumPressDuration = 0.38
        long.allowableMovement = 8
        let twist = UIRotationGestureRecognizer(target: c, action: #selector(Coordinator.twist(_:)))
        for g in [tap, pan, pinch, twist, long] as [UIGestureRecognizer] {
            g.delegate = c
            v.addGestureRecognizer(g)
        }
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) { context.coordinator.parent = self }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: StageGestureLayer
        init(_ p: StageGestureLayer) { parent = p }

        @objc func tap(_ g: UITapGestureRecognizer) {
            if g.state == .ended { parent.onTap(g.location(in: g.view)) }
        }

        @objc func pan(_ g: UIPanGestureRecognizer) {
            switch g.state {
            case .began:
                let p = g.location(in: g.view)
                let t = g.translation(in: g.view)
                parent.onPanBegin(CGPoint(x: p.x - t.x, y: p.y - t.y), CGSize(width: t.x, height: t.y))
            case .changed:
                let t = g.translation(in: g.view)
                g.setTranslation(.zero, in: g.view)
                parent.onPan(CGSize(width: t.x, height: t.y))
            case .ended, .cancelled:
                let v = g.velocity(in: g.view)
                parent.onPanEnd(CGSize(width: v.x, height: v.y))
            default: break
            }
        }

        @objc func pinch(_ g: UIPinchGestureRecognizer) {
            switch g.state {
            case .began: parent.onPinchBegin(g.location(in: g.view))
            case .changed: parent.onPinch(g.scale)
            default: break
            }
        }

        @objc func twist(_ g: UIRotationGestureRecognizer) {
            switch g.state {
            case .began: parent.onRotateBegin()
            case .changed: parent.onRotate(g.rotation)
            case .ended, .cancelled, .failed: parent.onRotateEnd()
            default: break
            }
        }

        @objc func long(_ g: UILongPressGestureRecognizer) {
            let p = g.location(in: g.view)
            switch g.state {
            case .began: parent.onLiftBegin(p)
            case .changed: parent.onLiftMove(p)
            case .ended: parent.onLiftEnd(p, true)
            case .cancelled, .failed: parent.onLiftEnd(p, false)
            default: break
            }
        }

        func gestureRecognizer(_ a: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith b: UIGestureRecognizer) -> Bool {
            func moves(_ g: UIGestureRecognizer) -> Bool { g is UIPinchGestureRecognizer || g is UIPanGestureRecognizer || g is UIRotationGestureRecognizer }
            return moves(a) && moves(b)
        }
    }
}

/// The live collage. Pictures and playing videos sit in their cells with rounded corners; gestures edit them.
struct StageView: View {
    @Environment(CollageStore.self) private var store
    /// False for the full-screen preview: no selection rings, "+" marks or gestures, just the collage.
    var interactive = true

    private struct Lift: Equatable {
        var from: Int
        var point: CGPoint
        var over: Int
    }

    @State private var gestureCell = -1
    @State private var pinchBase = 1.0
    @State private var pinchCell = -1
    @State private var lift: Lift?

    /// How a carousel is laid out on screen: one slide plus a peek of the next, scrolled sideways.
    private struct CarouselFrame {
        var slideW: Double
        var slideH: Double
        var slides: Int
        var viewport: CGSize
        var size: CGSize { CGSize(width: slideW * Double(slides), height: slideH) }
        var viewportSlides: Double { viewport.width / slideW }
        var maxOffset: Double { max(0, Double(slides) - viewportSlides) }
    }

    /// A border between cells being dragged: the sizes when it started, the layout's own sizes, and how far it has moved.
    private struct DividerDrag {
        var divider: LayoutDivider
        var start: LayoutGrid
        var base: LayoutGrid?
        var moved = 0.0
        var limited = false
        var snapped = false
    }
    @State private var dividerDrag: DividerDrag?

    /// True while a drag that started outside the selected picture is swiping the carousel.
    @State private var swiping = false

    /// A caption being dragged, with where the finger has taken it before any snapping.
    private struct CaptionDrag {
        var id: String
        var x: Double
        var y: Double
    }

    @Environment(\.displayScale) private var displayScale
    @State private var captionDrag: CaptionDrag?
    /// Guides shown while a dragged caption sits on the middle of a slide (across) or of the design (down).
    @State private var snapX = false
    @State private var snapY = false
    @State private var captionPinch: (id: String, size: Double)?
    @State private var captionTurn: (id: String, rotation: Double)?
    /// A photo on top being moved, sized or turned.
    @State private var overlayDrag: (id: String, cx: Double, cy: Double)?
    @State private var overlayPinch: (id: String, w: Double)?
    @State private var overlayTurn: (id: String, tilt: Double)?
    /// A picture in a cell being straightened with a two-finger twist.
    @State private var cellTurn: (cell: Int, angle: Double)?
    /// The angle, in degrees, a two-finger twist has locked onto (a quarter or eighth turn), shown with guide lines.
    @State private var turnLock: Double?
    /// True while a photo from the tray is dragged over the design.
    @State private var dropTargeted = false

    var body: some View {
        GeometryReader { geo in
            let p = store.project
            if p.mode == .carousel && interactive {
                carouselStage(geo.size)
            } else {
                let aspect = p.canvasAspect
                let fitW = min(geo.size.width, geo.size.height * aspect)
                let size = CGSize(width: fitW, height: fitW / aspect)
                stage(size: size)
                    .frame(width: size.width, height: size.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }

    private func rects(_ size: CGSize) -> [PxRect] {
        store.project.cellRects(W: size.width, H: size.height)
    }

    // MARK: Collage and full-screen preview

    private func stage(size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            canvas(size: size)
            if interactive { gestures(size: size, shift: .zero, frame: nil) }
            if dropTargeted { dropHighlight }
        }
        .dropDestination(for: String.self) { ids, loc in
            interactive && drop(ids, at: loc, size)
        } isTargeted: { dropTargeted = interactive && $0 }
        .clipShape(RoundedRectangle(cornerRadius: interactive ? 6 : 0, style: .continuous))
        .shadow(color: .black.opacity(interactive ? 0.45 : 0), radius: 22, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Collage preview. Tap a picture, photo on top or caption to select it; drag, pinch or twist then edits only what is selected. Tap outside it to deselect. Press and hold a picture then drag to swap.")
    }

    /// Shown while a tray photo is dragged over the design.
    private var dropHighlight: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.brand, lineWidth: 3)
            Label("Drop to place on top", systemImage: "square.on.square")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .glassEffect(.regular.tint(Color.brand.opacity(0.6)), in: .capsule)
        }
        .allowsHitTesting(false)
    }

    // MARK: Carousel

    private func carouselStage(_ vp: CGSize) -> some View {
        let p = store.project
        let slideAspect = p.format.width / p.format.height
        // one slide and about a quarter of the next, so the picture that crosses the seam is visible
        let slideH = min(vp.height, vp.width * 0.78 / slideAspect)
        let frame = CarouselFrame(slideW: slideH * slideAspect, slideH: slideH, slides: p.slides, viewport: CGSize(width: vp.width, height: slideH))
        let offset = clamp(store.carouselOffset, 0, frame.maxOffset)
        let shift = CGPoint(x: offset * frame.slideW, y: 0)
        return ZStack(alignment: .topLeading) {
            canvas(size: frame.size)
                .frame(width: frame.size.width, height: frame.size.height)
                .offset(x: -shift.x)
            gestures(size: frame.size, shift: shift, frame: frame)
                .frame(width: frame.viewport.width, height: frame.viewport.height)
            if dropTargeted { dropHighlight.frame(width: frame.viewport.width, height: frame.viewport.height) }
        }
        .dropDestination(for: String.self) { ids, loc in
            drop(ids, at: CGPoint(x: loc.x + shift.x, y: loc.y + shift.y), frame.size)
        } isTargeted: { dropTargeted = $0 }
        .frame(width: frame.viewport.width, height: frame.viewport.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 22, y: 10)
        .position(x: vp.width / 2, y: vp.height / 2)
        .onAppear { store.viewportSlides = frame.viewportSlides }
        .onChange(of: frame.viewportSlides) { _, v in store.viewportSlides = v }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Carousel preview, slide \(store.visibleSlide) of \(p.slides). Drag to swipe between slides. Tap a picture to edit it.")
    }

    /// Dashed lines where one slide ends and the next begins, and a number on each slide.
    private func seamGuides(_ size: CGSize) -> some View {
        let slides = store.project.slides
        let slideW = size.width / Double(slides)
        return ZStack(alignment: .topLeading) {
            ForEach(1..<max(slides, 1), id: \.self) { k in
                Path { path in
                    path.move(to: CGPoint(x: slideW * Double(k), y: 0))
                    path.addLine(to: CGPoint(x: slideW * Double(k), y: size.height))
                }
                .stroke(.white.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [7, 6]))
            }
            ForEach(0..<slides, id: \.self) { k in
                Text("\(k + 1)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .glassEffect(.regular, in: .capsule)
                    .offset(x: slideW * Double(k) + 8, y: 8)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Canvas and gestures

    /// Everything drawn on the design itself, in canvas coordinates.
    @ViewBuilder
    private func canvas(size: CGSize) -> some View {
        let project = store.project
        let px = rects(size)
        let radius = project.cornerRadius(W: size.width)

        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(hex: project.bg))

            ForEach(Array(px.enumerated()), id: \.offset) { i, r in
                cell(i, r, size: size)
            }

            ForEach(Array(project.overlays.enumerated()), id: \.element.id) { k, o in
                overlayView(o, index: k, size)
            }

            ForEach(project.captions) { c in
                if !c.text.isEmpty { captionView(c, size) }
            }

            if interactive {
                if project.mode == .carousel { seamGuides(size) }
                if let c = store.caption(store.selectedCaption), !c.text.isEmpty {
                    captionFrame(c, size)
                }
                // selection and swap marks
                if let s = store.selectedCell, px.indices.contains(s) {
                    ring(px[s], color: .brand, radius: project.pictureRadius(s, W: size.width))
                }
                if let s = store.swapFrom, px.indices.contains(s) {
                    ring(px[s], color: .orange, radius: project.pictureRadius(s, W: size.width))
                }
                if let o = store.overlay(store.selectedOverlay), let g = overlayGeometry(o, size) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(.white, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.brand, lineWidth: 2.5))
                        .frame(width: g.outer.w + 10, height: g.outer.h + 10)
                        .rotationEffect(.degrees(g.outer.tilt))
                        .position(g.outer.center)
                        .allowsHitTesting(false)
                }


                if let t = overlayTurn, let o = store.overlay(t.id), let g = overlayGeometry(o, size) {
                    rotationGuides(center: g.outer.center, degrees: o.tilt, size: size)
                } else if let t = cellTurn, px.indices.contains(t.cell), project.cells.indices.contains(t.cell) {
                    rotationGuides(center: px[t.cell].center, degrees: project.cells[t.cell].angle, size: size)
                } else if let t = captionTurn, let c = store.caption(t.id), !c.text.isEmpty {
                    let l = CaptionRenderer.layout(c, project: project, W: size.width, H: size.height)
                    rotationGuides(center: l.center, degrees: c.rotation, size: size)
                }

                if project.mode == .collage && (store.tab == .layout || dividerDrag != nil) {
                    dividerHandles(size)
                }

                if project.safeZone && project.format == .story && project.mode == .collage {
                    safeZone(size)
                }

                if let lift, px.indices.contains(lift.from) {
                    liftOverlay(lift, px: px, radius: radius, size: size)
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// The touch layer. `shift` is how far the canvas is scrolled, so a touch maps to a canvas point.
    private func gestures(size: CGSize, shift: CGPoint, frame: CarouselFrame?) -> some View {
        func at(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + shift.x, y: p.y + shift.y) }
        return StageGestureLayer(
            onTap: { tap(at($0), size) },
            onPanBegin: { start, moved in
                let p = at(start)
                panBegin(CGPoint(x: p.x + moved.width, y: p.y + moved.height), from: p, moved: moved, size, carousel: frame != nil)
            },
            onPan: { pan($0, size, frame: frame) },
            onPanEnd: { panEnd($0, frame: frame) },
            onPinchBegin: { pinchBegin(at($0), size) },
            onPinch: { pinch($0) },
            onRotateBegin: { turnBegin() },
            onRotate: { turn($0) },
            onRotateEnd: { turnEnd() },
            onLiftBegin: { liftBegin(at($0), size) },
            onLiftMove: { liftMove(at($0), size) },
            onLiftEnd: { liftEnd(at($0), size, completed: $1) }
        )
    }

    @ViewBuilder
    private func cell(_ i: Int, _ r: PxRect, size: CGSize) -> some View {
        let project = store.project
        let state = project.cells.indices.contains(i) ? project.cells[i] : CellState()
        let item = state.mediaId.flatMap { store.item($0) }
        let outers = project.frameRects(W: size.width, H: size.height)
        let outer = outers.indices.contains(i) ? outers[i] : r
        let pr = min(project.pictureRadius(i, W: size.width), r.w / 2, r.h / 2)
        let unit = size.width / project.canvasWidth
        let framed = project.isFramed(i)
        ZStack(alignment: .topLeading) {
            if framed {
                if project.frame.hasEdge {
                    Path(frameOutline(project.frame, size: CGSize(width: outer.w, height: outer.h), radius: 3 * unit,
                                      edge: project.frameEdges(i, outer, W: size.width).side, seed: i))
                        .fill(Color(hex: project.frameColor))
                        .shadow(color: .black.opacity(0.38), radius: 11 * unit, y: 7 * unit)
                } else {
                    RoundedRectangle(cornerRadius: pr, style: .continuous)
                        .fill(.black)
                        .frame(width: r.w, height: r.h)
                        .shadow(color: .black.opacity(0.38), radius: 11 * unit, y: 7 * unit)
                        .offset(x: r.x - outer.x, y: r.y - outer.y)
                }
            }
            ZStack {
                if let item {
                    MediaPlacementView(
                        item: item,
                        rect: PxRect(x: 0, y: 0, w: r.w, h: r.h),
                        view: state.view,
                        player: item.kind == .video ? store.playback.player(for: item) : nil
                    )
                } else if !interactive {
                    Color.white.opacity(0.06)
                } else {
                    EmptySlot(index: i, side: min(r.w, r.h), radius: pr)
                }
            }
            .frame(width: r.w, height: r.h)
            .clipShape(RoundedRectangle(cornerRadius: pr, style: .continuous))
            .offset(x: r.x - outer.x, y: r.y - outer.y)
        }
        .frame(width: outer.w, height: outer.h, alignment: .topLeading)
        .rotationEffect(.degrees(outer.tilt))
        .offset(x: outer.x, y: outer.y)
        .allowsHitTesting(false)
    }

    private func overlayGeometry(_ o: PhotoOverlay, _ size: CGSize) -> OverlayGeometry? {
        guard let item = store.item(o.mediaId) else { return nil }
        return store.project.overlayGeometry(o, item: item, W: size.width, H: size.height)
    }

    /// A photo laid on top: its frame (with a drop shadow) and the whole photo inside, turned by its tilt.
    @ViewBuilder
    private func overlayView(_ o: PhotoOverlay, index k: Int, _ size: CGSize) -> some View {
        if let item = store.item(o.mediaId), let g = overlayGeometry(o, size) {
            let unit = size.width / store.project.canvasWidth
            let pr: Double = o.frame == .torn ? 0 : 3 * unit
            ZStack(alignment: .topLeading) {
                if o.frame.hasEdge {
                    Path(frameOutline(o.frame, size: CGSize(width: g.outer.w, height: g.outer.h), radius: 3 * unit, edge: g.edge, seed: 1000 + k))
                        .fill(Color(hex: o.frameColor))
                        .shadow(color: .black.opacity(0.38), radius: 11 * unit, y: 7 * unit)
                } else if o.frame == .shadow {
                    RoundedRectangle(cornerRadius: pr, style: .continuous)
                        .fill(.black)
                        .frame(width: g.picture.w, height: g.picture.h)
                        .shadow(color: .black.opacity(0.38), radius: 11 * unit, y: 7 * unit)
                        .offset(x: g.picture.x - g.outer.x, y: g.picture.y - g.outer.y)
                }
                MediaPlacementView(item: item, rect: PxRect(x: 0, y: 0, w: g.picture.w, h: g.picture.h), view: o.view, player: nil)
                    .frame(width: g.picture.w, height: g.picture.h)
                    .clipShape(RoundedRectangle(cornerRadius: pr, style: .continuous))
                    .offset(x: g.picture.x - g.outer.x, y: g.picture.y - g.outer.y)
            }
            .frame(width: g.outer.w, height: g.outer.h, alignment: .topLeading)
            .rotationEffect(.degrees(g.outer.tilt))
            .offset(x: g.outer.x, y: g.outer.y)
            .allowsHitTesting(false)
            .accessibilityLabel("Photo on top: \(item.name)")
        }
    }

    /// The photo on top under a touch (the one on top of the pile wins).
    private func overlayAt(_ p: CGPoint, _ size: CGSize) -> PhotoOverlay? {
        store.project.overlays.last { o in
            overlayGeometry(o, size)?.outer.contains(p.x, p.y) ?? false
        }
    }

    /// A photo dragged in from the tray: it lands on top, centred where it was dropped.
    private func drop(_ ids: [String], at p: CGPoint, _ size: CGSize) -> Bool {
        guard let id = ids.first, store.item(id) != nil else { return false }
        let slideW = size.width / Double(max(1, store.project.slides))
        return store.addOverlay(id, cx: p.x / slideW, cy: p.y / size.height)
    }

    /// A caption, drawn by the same code as the export and then turned and placed.
    @ViewBuilder
    private func captionView(_ c: Caption, _ size: CGSize) -> some View {
        let l = CaptionRenderer.layout(c, project: store.project, W: size.width, H: size.height)
        if let img = CaptionRenderer.image(l, scale: displayScale) {
            Image(uiImage: img)
                .rotationEffect(.radians(l.rotationRad))
                .position(l.center)
                .allowsHitTesting(false)
                .accessibilityLabel("Caption: \(c.text)")
        }
    }

    /// The frame around the selected caption, and the centre guides while it is dragged onto them.
    @ViewBuilder
    private func captionFrame(_ c: Caption, _ size: CGSize) -> some View {
        let l = CaptionRenderer.layout(c, project: store.project, W: size.width, H: size.height)
        if captionDrag != nil {
            Path { p in
                if snapX {
                    p.move(to: CGPoint(x: l.center.x, y: 0))
                    p.addLine(to: CGPoint(x: l.center.x, y: size.height))
                }
                if snapY {
                    let slideW = size.width / Double(max(1, store.project.slides))
                    let left = (l.center.x / slideW).rounded(.down) * slideW
                    p.move(to: CGPoint(x: left, y: l.center.y))
                    p.addLine(to: CGPoint(x: left + slideW, y: l.center.y))
                }
            }
            .stroke(Color.yellow, lineWidth: 1)
            .allowsHitTesting(false)
        }
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(.white, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.brand, lineWidth: 1.5))
            .frame(width: l.box.width + 10, height: l.box.height + 10)
            .rotationEffect(.radians(l.rotationRad))
            .position(l.center)
            .allowsHitTesting(false)
    }

    /// While a caption or photo on top is twisted: its angle, and when it locks onto a straight, quarter or eighth turn,
    /// lines along both of its axes across the design so the lock can be seen as well as felt.
    @ViewBuilder
    private func rotationGuides(center: CGPoint, degrees: Double, size: CGSize) -> some View {
        let locked = turnLock != nil
        if locked {
            let reach = hypot(size.width, size.height)
            Path { p in
                for axis in [degrees, degrees + 90] {
                    let a = axis * RAD
                    let dx = cos(a) * reach, dy = sin(a) * reach
                    p.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
                    p.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
                }
            }
            .stroke(Color.yellow, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            .allowsHitTesting(false)
        }
        Text("\(Int(normalizedDegrees(degrees).rounded()))°")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(locked ? .black : .white)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(locked ? Color.yellow : Color.black.opacity(0.55)))
            .position(x: center.x, y: max(16, center.y - 54))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The caption under a touch (the one on top wins). A little slack makes small captions easy to grab.
    private func captionAt(_ p: CGPoint, _ size: CGSize) -> Caption? {
        store.project.captions.last { c in
            !c.text.isEmpty && CaptionRenderer.layout(c, project: store.project, W: size.width, H: size.height).contains(p, slack: 12)
        }
    }

    /// Grips on the borders between cells (shown on the Layout tab), and the border being dragged.
    @ViewBuilder
    private func dividerHandles(_ size: CGSize) -> some View {
        let project = store.project
        if let grid = project.resizableGrid {
            let g = project.gap * size.width / project.canvasWidth
            ZStack(alignment: .topLeading) {
                Color.clear
                ForEach(Array(grid.dividers.enumerated()), id: \.offset) { _, d in
                    let l = grid.line(d)
                    let ends = dividerPixelLine(l, W: size.width, H: size.height, gapPx: g)
                    let active = dividerDrag?.divider == d
                    let length = l.vertical ? ends.b.y - ends.a.y : ends.b.x - ends.a.x
                    let grip = min(28, max(10, length * 0.35))
                    if active {
                        Path { p in
                            p.move(to: ends.a)
                            p.addLine(to: ends.b)
                        }
                        .stroke(Color.brand, style: StrokeStyle(lineWidth: max(2, min(g, 4)), lineCap: .round))
                    }
                    Capsule()
                        .fill(active ? Color.brand : Color.white)
                        .overlay(Capsule().strokeBorder(.black.opacity(0.25), lineWidth: 0.5))
                        .frame(width: l.vertical ? 5 : grip, height: l.vertical ? grip : 5)
                        .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                        .position(x: (ends.a.x + ends.b.x) / 2, y: (ends.a.y + ends.b.y) / 2)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// The border between cells a drag starting at `p` should move. The touch has to be close to the border and moving
    /// across it: a drag along a border is a picture being moved.
    private func dividerAt(_ p: CGPoint, moving t: CGSize, _ size: CGSize) -> LayoutDivider? {
        let project = store.project
        guard store.swapFrom == nil, let grid = project.resizableGrid else { return nil }
        let g = project.gap * size.width / project.canvasWidth
        let slop = max(18, g / 2 + 10)
        var best: (divider: LayoutDivider, distance: CGFloat)?
        for d in grid.dividers {
            let l = grid.line(d)
            let ends = dividerPixelLine(l, W: size.width, H: size.height, gapPx: g)
            let across = l.vertical ? abs(p.x - ends.a.x) : abs(p.y - ends.a.y)
            let along = l.vertical ? p.y : p.x
            let lo = (l.vertical ? ends.a.y : ends.a.x) - g / 2
            let hi = (l.vertical ? ends.b.y : ends.b.x) + g / 2
            guard across <= slop, along >= lo, along <= hi else { continue }
            let moveAcross = l.vertical ? abs(t.width) : abs(t.height)
            let moveAlong = l.vertical ? abs(t.height) : abs(t.width)
            guard moveAcross >= moveAlong * 0.6 else { continue }
            if best == nil || across < best!.distance { best = (d, across) }
        }
        return best?.divider
    }

    private func ring(_ r: PxRect, color: Color, radius: Double) -> some View {
        RoundedRectangle(cornerRadius: min(radius, r.w / 2, r.h / 2), style: .continuous)
            .strokeBorder(color, lineWidth: 3)
            .frame(width: r.w, height: r.h)
            .rotationEffect(.degrees(r.tilt))
            .offset(x: r.x, y: r.y)
            .allowsHitTesting(false)
    }

    private func safeZone(_ size: CGSize) -> some View {
        ZStack(alignment: .top) {
            Color.red.opacity(0.14).frame(height: size.height * safeTop).frame(maxHeight: .infinity, alignment: .top)
            Color.red.opacity(0.14).frame(height: size.height * safeBottom).frame(maxHeight: .infinity, alignment: .bottom)
            Path { p in
                for y in [size.height * safeTop, size.height * (1 - safeBottom)] {
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
            }
            .stroke(Color(red: 1, green: 0.43, blue: 0.43), style: StrokeStyle(lineWidth: 1.5, dash: [8, 6]))
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func liftOverlay(_ l: Lift, px: [PxRect], radius: Double, size: CGSize) -> some View {
        let from = px[l.from]
        RoundedRectangle(cornerRadius: min(radius, from.w / 2, from.h / 2), style: .continuous)
            .fill(.black.opacity(0.5))
            .frame(width: from.w, height: from.h)
            .offset(x: from.x, y: from.y)
            .allowsHitTesting(false)
        if l.over >= 0, l.over != l.from, px.indices.contains(l.over) {
            ring(px[l.over], color: .pink, radius: radius)
        }
        if let id = store.project.cells[l.from].mediaId, let item = store.item(id) {
            let gw = min(size.width, size.height) * 0.3
            let gh = min(size.height * 0.3, gw * (from.h / from.w))
            Image(uiImage: item.preview ?? item.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: gw, height: gh)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white, lineWidth: 2))
                .shadow(radius: 12)
                .opacity(0.94)
                .position(l.point)
                .allowsHitTesting(false)
        }
    }

    // MARK: Gestures

    private func selectAndOpen(_ cell: Int) {
        if cell != store.selectedCell {
            store.selectCell(cell)
            UISelectionFeedbackGenerator().selectionChanged()
        }
        store.openPicture()
    }

    // Editing rule: only the selected thing (a caption, a photo on top, or a picture in a cell) moves, zooms or turns.
    // Nothing is picked up by accident: a drag, pinch or twist with nothing selected leaves every layer alone, and a
    // tap outside the selected thing only clears the selection (it doesn't select or change what is underneath).

    /// Whatever is selected, and whether a touch at `p` is on it.
    private func onSelection(_ p: CGPoint, _ size: CGSize) -> Bool {
        if let c = store.caption(store.selectedCaption), !c.text.isEmpty {
            return CaptionRenderer.layout(c, project: store.project, W: size.width, H: size.height).contains(p, slack: 12)
        }
        if let o = store.overlay(store.selectedOverlay) {
            return overlayGeometry(o, size)?.outer.contains(p.x, p.y) ?? false
        }
        if let s = store.selectedCell {
            let r = rects(size)
            return r.indices.contains(s) && r[s].contains(p.x, p.y)
        }
        return false
    }

    private var hasSelection: Bool {
        store.selectedCaption != nil || store.selectedOverlay != nil || store.selectedCell != nil
    }

    private func tap(_ p: CGPoint, _ size: CGSize) {
        let cell = hitCell(rects(size), x: p.x, y: p.y)
        if let from = store.swapFrom {
            if cell >= 0 && cell != from { store.swapCells(from, cell) } else { withAnimation { store.swapFrom = nil } }
            return
        }
        if hasSelection {
            if onSelection(p, size) {
                // tap the selected caption again to change its words; an empty selected cell asks for a picture
                if let id = store.selectedCaption {
                    store.editingCaption = id
                } else if let s = store.selectedCell, store.project.cells.indices.contains(s), store.project.cells[s].mediaId == nil {
                    store.openAdd(cell: s)
                }
            } else {
                withAnimation(.smooth) { store.deselectAll() }
                UISelectionFeedbackGenerator().selectionChanged()
            }
            return
        }
        // Nothing selected: select the top-most thing under the finger (captions, then photos on top, then cells).
        if let c = captionAt(p, size) {
            store.selectCaption(c.id)
        } else if let o = overlayAt(p, size) {
            store.selectOverlay(o.id)
            UISelectionFeedbackGenerator().selectionChanged()
        } else if cell >= 0 {
            selectAndOpen(cell)
            if store.project.cells[cell].mediaId == nil { store.openAdd(cell: cell) }
        }
    }

    private func panBegin(_ p: CGPoint, from start: CGPoint, moved: CGSize, _ size: CGSize, carousel: Bool) {
        captionDrag = nil
        dividerDrag = nil
        overlayDrag = nil
        gestureCell = -1
        swiping = false
        let onIt = store.swapFrom == nil && (onSelection(start, size) || onSelection(p, size))
        if onIt, let c = store.caption(store.selectedCaption) {
            captionDrag = CaptionDrag(id: c.id, x: c.x, y: c.y)
            return
        }
        if onIt, let o = store.overlay(store.selectedOverlay) {
            overlayDrag = (o.id, o.cx, o.cy)
            return
        }
        if onIt, let s = store.selectedCell, store.project.cells[s].mediaId != nil {
            gestureCell = s
            return
        }
        // The borders between cells can be dragged while nothing is selected.
        if !carousel, !hasSelection, store.swapFrom == nil, captionAt(start, size) == nil, overlayAt(start, size) == nil,
           let d = dividerAt(start, moving: moved, size), let grid = store.project.resizableGrid {
            dividerDrag = DividerDrag(divider: d, start: grid, base: layout(byId: store.project.layoutId).grid)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        // A carousel swipes between slides, like swiping the finished post.
        swiping = carousel
    }

    private func panEnd(_ velocity: CGSize, frame: CarouselFrame?) {
        if overlayDrag != nil {
            overlayDrag = nil
            return
        }
        if dividerDrag != nil {
            dividerDrag = nil
            return
        }
        if captionDrag != nil {
            captionDrag = nil
            snapX = false
            snapY = false
            return
        }
        guard swiping, let frame else { swiping = false; return }
        swiping = false
        store.settleCarousel(velocitySlidesPerSecond: -velocity.width / frame.slideW)
    }

    private func pan(_ d: CGSize, _ size: CGSize, frame: CarouselFrame?) {
        if var drag = captionDrag {
            let slides = Double(max(1, store.project.slides))
            drag.x = clamp(drag.x + d.width / (size.width / slides), 0, slides)
            drag.y = clamp(drag.y + d.height / size.height, 0, 1)
            // a caption can't leave the design: follow the finger only as far as the caption still fits
            if var probe = store.caption(drag.id) {
                probe.x = drag.x
                probe.y = drag.y
                let c = CaptionRenderer.layout(probe, project: store.project, W: size.width, H: size.height).center
                drag.x = c.x / (size.width / slides)
                drag.y = c.y / size.height
            }
            captionDrag = drag
            // the caption clicks onto the middle of a slide, and onto the middle of the design
            let slide = min(drag.x.rounded(.down), slides - 1)
            let onX = abs(drag.x - slide - 0.5) < 0.025
            let onY = abs(drag.y - 0.5) < 0.014
            if (onX && !snapX) || (onY && !snapY) { UISelectionFeedbackGenerator().selectionChanged() }
            snapX = onX
            snapY = onY
            store.updateCaption(drag.id) {
                $0.x = onX ? slide + 0.5 : drag.x
                $0.y = onY ? 0.5 : drag.y
            }
            return
        }
        if var drag = overlayDrag {
            let slideW = size.width / Double(max(1, store.project.slides))
            drag.cx += d.width / slideW
            drag.cy += d.height / size.height
            overlayDrag = drag
            store.updateOverlay(drag.id) { $0.cx = drag.cx; $0.cy = drag.cy }
            return
        }
        if dividerDrag != nil {
            dragDivider(d, size)
            return
        }
        if swiping, let frame {
            store.carouselOffset = clamp(store.carouselOffset - d.width / frame.slideW, 0, frame.maxOffset)
            return
        }
        let ci = gestureCell
        guard ci >= 0, store.swapFrom == nil, store.project.cells.indices.contains(ci),
              let id = store.project.cells[ci].mediaId, let item = store.item(id) else { return }
        let r = rects(size)[ci]
        let cell = store.project.cells[ci]
        // a turned photo moves along its own sides
        var d = d
        if r.tilt != 0 {
            let t = -r.tilt * RAD
            d = CGSize(width: d.width * cos(t) - d.height * sin(t), height: d.width * sin(t) + d.height * cos(t))
        }
        let moved = placeMedia(srcW: item.width, srcH: item.height, cell: r, view: cell.view)
        let panX = panAfterDrag(cell.panX, deltaPx: d.width, overflowPx: moved.overflowX)
        let panY = panAfterDrag(cell.panY, deltaPx: d.height, overflowPx: moved.overflowY)
        var v = cell.view
        v.panX = panX
        v.panY = panY
        // a tilted picture can't move as far: pull the stored position back so dragging never has a dead zone
        let fit = placeMedia(srcW: item.width, srcH: item.height, cell: r, view: v).fit
        store.setCellView(ci) { $0.panX = panX * fit; $0.panY = panY * fit }
    }

    /// Moves the dragged border: the cells on both sides change size, down to a minimum. It clicks onto the layout's own
    /// position and onto an even split.
    private func dragDivider(_ d: CGSize, _ size: CGSize) {
        guard var drag = dividerDrag else { return }
        let project = store.project
        let line = drag.start.line(drag.divider)
        let g = project.gap * size.width / project.canvasWidth
        let area = max(1, (line.vertical ? size.width : size.height) - g)
        drag.moved += Double(line.vertical ? d.width : d.height) / area
        let (a, b) = drag.start.sizes(at: drag.divider)
        var first = a + drag.moved
        var targets = [(a + b) / 2]
        if let base = drag.base, base.sameShape(drag.start) { targets.append(a + base.line(drag.divider).at - line.at) }
        let snap = targets.first { abs(first - $0) < 0.012 }
        if let snap { first = snap }
        let moved = drag.start.moving(drag.divider, first: first)
        if snap != nil && !drag.snapped { UISelectionFeedbackGenerator().selectionChanged() }
        if moved.limited && !drag.limited { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        drag.snapped = snap != nil
        drag.limited = moved.limited
        dividerDrag = drag
        store.project.cellSizes = moved.grid
    }

    /// A pinch anywhere sizes the selected thing (its edges are often too small a target for two fingers).
    /// With nothing selected it does nothing.
    private func pinchBegin(_ p: CGPoint, _ size: CGSize) {
        captionPinch = store.caption(store.selectedCaption).map { ($0.id, $0.size) }
        overlayPinch = captionPinch == nil ? store.overlay(store.selectedOverlay).map { ($0.id, $0.w) } : nil
        pinchCell = -1
        if captionPinch == nil, overlayPinch == nil, let s = store.selectedCell, store.swapFrom == nil,
           store.project.cells.indices.contains(s), store.project.cells[s].mediaId != nil {
            pinchCell = s
            pinchBase = store.project.cells[s].zoom
        }
    }

    /// A two-finger twist turns the selected caption or photo on top, or straightens the selected picture in its cell.
    private func turnBegin() {
        captionTurn = store.caption(store.selectedCaption).map { ($0.id, $0.rotation) }
        overlayTurn = captionTurn == nil ? store.overlay(store.selectedOverlay).map { ($0.id, $0.tilt) } : nil
        cellTurn = nil
        if captionTurn == nil, overlayTurn == nil, let s = store.selectedCell, store.swapFrom == nil,
           store.project.cells.indices.contains(s), store.project.cells[s].mediaId != nil {
            cellTurn = (s, store.project.cells[s].angle)
        }
        turnLock = nil
    }

    private func turnEnd() {
        captionTurn = nil
        overlayTurn = nil
        cellTurn = nil
        turnLock = nil
    }

    /// Straight and quarter turns hold on a little, eighth turns a little less, so a level or square angle is easy to hit.
    /// Clicks when it locks on.
    private func lockedAngle(_ deg: Double) -> Double {
        let quarter = (deg / 90).rounded() * 90
        let eighth = (deg / 45).rounded() * 45
        let lock: Double? = abs(deg - quarter) < 4 ? quarter : abs(deg - eighth) < 2.5 ? eighth : nil
        if let lock, lock != turnLock {
            if lock.truncatingRemainder(dividingBy: 90) == 0 {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        turnLock = lock
        return lock ?? deg
    }

    private func turn(_ radians: CGFloat) {
        if let t = cellTurn {
            let deg = clamp(lockedAngle(t.angle + Double(radians) / RAD), -45, 45)
            store.setCellView(t.cell) { $0.angle = deg }
            return
        }
        if let t = overlayTurn {
            let deg = lockedAngle(t.tilt + Double(radians) / RAD)
            store.updateOverlay(t.id) { $0.tilt = deg }
            return
        }
        guard let t = captionTurn else { return }
        let deg = lockedAngle(t.rotation + Double(radians) / RAD)
        store.updateCaption(t.id) { $0.rotation = deg }
    }

    private func pinch(_ scale: CGFloat) {
        if let o = overlayPinch {
            store.updateOverlay(o.id) { $0.w = o.w * Double(scale) }
            return
        }
        if let c = captionPinch {
            store.updateCaption(c.id) { $0.size = c.size * Double(scale) }
            return
        }
        guard store.project.cells.indices.contains(pinchCell), store.project.cells[pinchCell].mediaId != nil else { return }
        store.setCellView(pinchCell) { $0.zoom = clamp(pinchBase * Double(scale), 1, 4) }
    }

    /// Press and hold a picture to pick it up and drop it on another cell. Only the selected picture can be picked up,
    /// or any picture while nothing is selected (and no caption or photo on top is in the way).
    private func liftBegin(_ p: CGPoint, _ size: CGSize) {
        guard store.selectedCaption == nil, store.selectedOverlay == nil else { return }
        guard captionAt(p, size) == nil, overlayAt(p, size) == nil else { return }
        let cell = hitCell(rects(size), x: p.x, y: p.y)
        guard cell >= 0, store.swapFrom == nil, store.project.cells[cell].mediaId != nil else { return }
        if let s = store.selectedCell, s != cell { return }
        selectAndOpen(cell)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        lift = Lift(from: cell, point: p, over: -1)
    }

    private func liftMove(_ p: CGPoint, _ size: CGSize) {
        guard var l = lift else { return }
        l.point = p
        let over = hitCell(rects(size), x: p.x, y: p.y)
        if over != l.over, over >= 0, over != l.from { UISelectionFeedbackGenerator().selectionChanged() }
        l.over = over
        lift = l
    }

    private func liftEnd(_ p: CGPoint, _ size: CGSize, completed: Bool) {
        defer { lift = nil }
        guard completed, let l = lift else { return }
        let over = hitCell(rects(size), x: p.x, y: p.y)
        if over >= 0 && over != l.from { store.swapCells(l.from, over) }
    }
}


/// An angle in degrees as 0 to 359.
private func normalizedDegrees(_ d: Double) -> Double {
    let n = d.truncatingRemainder(dividingBy: 360)
    let r = n < 0 ? n + 360 : n
    return r.rounded() == 360 ? 0 : r
}

/// An empty cell: a dashed slot with a "+". They pop in one after another, so a new collage reads as nine places to fill.
private struct EmptySlot: View {
    let index: Int
    let side: CGFloat
    let radius: CGFloat
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.white.opacity(0.07)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            Image(systemName: "plus")
                .font(.system(size: side * 0.2, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(side * 0.14)
                .glassEffect(.regular, in: .circle)
        }
        .scaleEffect(shown ? 1 : 0.8)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.3).delay(Double(index) * 0.05)) { shown = true }
        }
    }
}
