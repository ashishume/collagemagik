import SwiftUI

/// UIKit gesture layer for the preview: tap, drag, pinch, and press-and-hold-then-drag. UIKit lets these coexist cleanly.
struct StageGestureLayer: UIViewRepresentable {
    var onTap: (CGPoint) -> Void
    var onPanBegin: (CGPoint) -> Void
    var onPan: (CGSize) -> Void
    var onPanEnd: (CGSize) -> Void = { _ in }
    var onPinchBegin: (CGPoint) -> Void
    var onPinch: (CGFloat) -> Void
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
        for g in [tap, pan, pinch, long] as [UIGestureRecognizer] {
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
                parent.onPanBegin(g.location(in: g.view))
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
            (a is UIPinchGestureRecognizer && b is UIPanGestureRecognizer) || (a is UIPanGestureRecognizer && b is UIPinchGestureRecognizer)
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

    /// True while a drag that started outside the selected picture is swiping the carousel.
    @State private var swiping = false

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
        }
        .clipShape(RoundedRectangle(cornerRadius: interactive ? 6 : 0, style: .continuous))
        .shadow(color: .black.opacity(interactive ? 0.45 : 0), radius: 22, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Collage preview. Tap a picture for options, drag to move it, pinch to zoom, press and hold then drag to swap.")
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
        }
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
                cell(i, r, radius: radius)
            }

            if interactive {
                if project.mode == .carousel { seamGuides(size) }
                // selection and swap marks
                if let s = store.selectedCell, px.indices.contains(s) {
                    ring(px[s], color: .brand, radius: radius)
                }
                if let s = store.swapFrom, px.indices.contains(s) {
                    ring(px[s], color: .orange, radius: radius)
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
            onPanBegin: { panBegin(at($0), size, carousel: frame != nil) },
            onPan: { pan($0, size, frame: frame) },
            onPanEnd: { panEnd($0, frame: frame) },
            onPinchBegin: { pinchBegin(at($0), size) },
            onPinch: { pinch($0) },
            onLiftBegin: { liftBegin(at($0), size) },
            onLiftMove: { liftMove(at($0), size) },
            onLiftEnd: { liftEnd(at($0), size, completed: $1) }
        )
    }

    @ViewBuilder
    private func cell(_ i: Int, _ r: PxRect, radius: Double) -> some View {
        let state = store.project.cells.indices.contains(i) ? store.project.cells[i] : CellState()
        let item = state.mediaId.flatMap { store.item($0) }
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
                EmptySlot(index: i, side: min(r.w, r.h), radius: min(radius, r.w / 2, r.h / 2))
            }
        }
        .frame(width: r.w, height: r.h)
        .clipShape(RoundedRectangle(cornerRadius: min(radius, r.w / 2, r.h / 2), style: .continuous))
        .offset(x: r.x, y: r.y)
        .allowsHitTesting(false)
    }

    private func ring(_ r: PxRect, color: Color, radius: Double) -> some View {
        RoundedRectangle(cornerRadius: min(radius, r.w / 2, r.h / 2), style: .continuous)
            .strokeBorder(color, lineWidth: 3)
            .frame(width: r.w, height: r.h)
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

    private func tap(_ p: CGPoint, _ size: CGSize) {
        let cell = hitCell(rects(size), x: p.x, y: p.y)
        if let from = store.swapFrom {
            if cell >= 0 && cell != from { store.swapCells(from, cell) } else { withAnimation { store.swapFrom = nil } }
            return
        }
        if cell < 0 {
            store.selectCell(nil)
        } else if store.project.cells[cell].mediaId == nil {
            selectAndOpen(cell)
            store.openAdd(cell: cell)
        } else {
            selectAndOpen(cell)
        }
    }

    private func panBegin(_ p: CGPoint, _ size: CGSize, carousel: Bool) {
        let cell = hitCell(rects(size), x: p.x, y: p.y)
        gestureCell = cell
        if carousel {
            // In a carousel a drag moves a picture only if it is already selected; anywhere else it swipes the slides,
            // like swiping the finished post.
            swiping = !(cell >= 0 && cell == store.selectedCell && store.project.cells[cell].mediaId != nil && store.swapFrom == nil)
            return
        }
        if cell >= 0, store.swapFrom == nil, store.project.cells[cell].mediaId != nil, cell != store.selectedCell {
            selectAndOpen(cell)
        }
    }

    private func panEnd(_ velocity: CGSize, frame: CarouselFrame?) {
        guard swiping, let frame else { swiping = false; return }
        swiping = false
        store.settleCarousel(velocitySlidesPerSecond: -velocity.width / frame.slideW)
    }

    private func pan(_ d: CGSize, _ size: CGSize, frame: CarouselFrame?) {
        if swiping, let frame {
            store.carouselOffset = clamp(store.carouselOffset - d.width / frame.slideW, 0, frame.maxOffset)
            return
        }
        let ci = gestureCell
        guard ci >= 0, store.swapFrom == nil, store.project.cells.indices.contains(ci),
              let id = store.project.cells[ci].mediaId, let item = store.item(id) else { return }
        let r = rects(size)[ci]
        let cell = store.project.cells[ci]
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

    private func pinchBegin(_ p: CGPoint, _ size: CGSize) {
        pinchCell = store.selectedCell ?? hitCell(rects(size), x: p.x, y: p.y)
        pinchBase = store.project.cells.indices.contains(pinchCell) ? store.project.cells[pinchCell].zoom : 1
    }

    private func pinch(_ scale: CGFloat) {
        guard store.project.cells.indices.contains(pinchCell), store.project.cells[pinchCell].mediaId != nil else { return }
        store.setCellView(pinchCell) { $0.zoom = clamp(pinchBase * Double(scale), 1, 4) }
    }

    private func liftBegin(_ p: CGPoint, _ size: CGSize) {
        let cell = hitCell(rects(size), x: p.x, y: p.y)
        guard cell >= 0, store.swapFrom == nil, store.project.cells[cell].mediaId != nil else { return }
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
