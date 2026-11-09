import SwiftUI

/// UIKit gesture layer for the preview: tap, drag, pinch, and press-and-hold-then-drag. UIKit lets these coexist cleanly.
struct StageGestureLayer: UIViewRepresentable {
    var onTap: (CGPoint) -> Void
    var onPanBegin: (CGPoint) -> Void
    var onPan: (CGSize) -> Void
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

    var body: some View {
        GeometryReader { geo in
            let f = store.project.format
            let aspect = f.width / f.height
            let fitW = min(geo.size.width, geo.size.height * aspect)
            let size = CGSize(width: fitW, height: fitW / aspect)
            stage(size: size)
                .frame(width: size.width, height: size.height)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    private func rects(_ size: CGSize) -> [PxRect] {
        cellPixelRects(store.currentLayout.rects, W: size.width, H: size.height, gap: store.project.gap)
    }

    @ViewBuilder
    private func stage(size: CGSize) -> some View {
        let project = store.project
        let px = rects(size)
        let scale = size.width / 1080
        let radius = project.radius * scale

        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(hex: project.bg))

            ForEach(Array(px.enumerated()), id: \.offset) { i, r in
                cell(i, r, radius: radius)
            }

            if interactive {
            // selection and swap marks
            if let s = store.selectedCell, px.indices.contains(s) {
                ring(px[s], color: .brand, radius: radius)
            }
            if let s = store.swapFrom, px.indices.contains(s) {
                ring(px[s], color: .orange, radius: radius)
            }

            if project.safeZone && project.format == .story {
                safeZone(size)
            }

            if let lift, px.indices.contains(lift.from) {
                liftOverlay(lift, px: px, radius: radius, size: size)
            }

            StageGestureLayer(
                onTap: { tap($0, size) },
                onPanBegin: { panBegin($0, size) },
                onPan: { pan($0, size) },
                onPinchBegin: { pinchBegin($0, size) },
                onPinch: { pinch($0) },
                onLiftBegin: { liftBegin($0, size) },
                onLiftMove: { liftMove($0, size) },
                onLiftEnd: { liftEnd($0, size, completed: $1) }
            )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: interactive ? 6 : 0, style: .continuous))
        .shadow(color: .black.opacity(interactive ? 0.45 : 0), radius: 22, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Collage preview. Tap a picture for options, drag to move it, pinch to zoom, press and hold then drag to swap.")
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
                Color.white.opacity(0.08)
                Image(systemName: "plus")
                    .font(.system(size: min(r.w, r.h) * 0.2, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(min(r.w, r.h) * 0.14)
                    .glassEffect(.regular, in: .circle)
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

    private func panBegin(_ p: CGPoint, _ size: CGSize) {
        let cell = hitCell(rects(size), x: p.x, y: p.y)
        gestureCell = cell
        if cell >= 0, store.swapFrom == nil, store.project.cells[cell].mediaId != nil, cell != store.selectedCell {
            selectAndOpen(cell)
        }
    }

    private func pan(_ d: CGSize, _ size: CGSize) {
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
