import SwiftUI

struct CropTarget: Identifiable {
    let id: Int
}

/// Crop screen for one picture or video: the whole picture is shown with the cell's frame over it, so you can see what is cut off.
/// Drag to move, pinch or use the slider to zoom, rotate, flip and straighten. Apply keeps the changes.
struct CropEditor: View {
    @Environment(CollageStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let cellIndex: Int

    @State private var draft = MediaView()
    @State private var loaded = false
    @State private var dragging = false
    @State private var lastTranslation: CGSize = .zero
    @State private var pinchBase: Double?

    private var item: MediaItem? {
        guard store.project.cells.indices.contains(cellIndex), let id = store.project.cells[cellIndex].mediaId else { return nil }
        return store.item(id)
    }

    /// Aspect ratio of the cell this picture sits in, so the frame matches what will be used.
    private var aspect: Double {
        let f = store.project.format
        let rects = cellPixelRects(store.currentLayout.rects, W: f.width, H: f.height, gap: store.project.gap)
        guard rects.indices.contains(cellIndex) else { return 1 }
        return rects[cellIndex].w / rects[cellIndex].h
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                GeometryReader { geo in
                    canvas(geo.size)
                }
                Text("The bright area is what's used. Drag to move, pinch or use the slider to zoom.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                controls
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            .background { AuroraBackground().ignoresSafeArea() }
            .navigationTitle("Crop and rotate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply", systemImage: "checkmark") {
                        store.applyView(cellIndex, draft)
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .onAppear {
            guard !loaded, store.project.cells.indices.contains(cellIndex) else { return }
            draft = store.project.cells[cellIndex].view
            loaded = true
        }
    }

    // MARK: Canvas

    @ViewBuilder
    private func canvas(_ size: CGSize) -> some View {
        let margin = 0.88
        let fw = min(size.width * margin, size.height * margin * aspect)
        let frame = PxRect(x: (size.width - fw) / 2, y: (size.height - fw / aspect) / 2, w: fw, h: fw / aspect)
        ZStack(alignment: .topLeading) {
            if let item {
                // everything, dimmed: this is what is being cut off
                MediaPlacementView(item: item, rect: frame, view: draft).opacity(0.35)
                // inside the frame, at full strength
                MediaPlacementView(item: item, rect: frame, view: draft)
                    .mask(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .frame(width: frame.w, height: frame.h)
                            .position(x: frame.x + frame.w / 2, y: frame.y + frame.h / 2)
                    )
                if dragging {
                    Path { p in
                        for k in [1.0 / 3, 2.0 / 3] {
                            p.move(to: CGPoint(x: frame.x + frame.w * k, y: frame.y))
                            p.addLine(to: CGPoint(x: frame.x + frame.w * k, y: frame.y + frame.h))
                            p.move(to: CGPoint(x: frame.x, y: frame.y + frame.h * k))
                            p.addLine(to: CGPoint(x: frame.x + frame.w, y: frame.y + frame.h * k))
                        }
                    }
                    .stroke(.white.opacity(0.4), lineWidth: 1)
                }
            }
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: frame.w, height: frame.h)
                .offset(x: frame.x, y: frame.y)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    dragging = true
                    let d = CGSize(width: v.translation.width - lastTranslation.width, height: v.translation.height - lastTranslation.height)
                    lastTranslation = v.translation
                    pan(d, frame: frame)
                }
                .onEnded { _ in
                    dragging = false
                    lastTranslation = .zero
                }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { v in
                    if pinchBase == nil { pinchBase = draft.zoom }
                    draft.zoom = clamp((pinchBase ?? 1) * Double(v.magnification), 1, 4)
                }
                .onEnded { _ in pinchBase = nil }
        )
    }

    private func pan(_ d: CGSize, frame: PxRect) {
        guard let item else { return }
        let moved = placeMedia(srcW: item.width, srcH: item.height, cell: frame, view: draft)
        let panX = panAfterDrag(draft.panX, deltaPx: d.width, overflowPx: moved.overflowX)
        let panY = panAfterDrag(draft.panY, deltaPx: d.height, overflowPx: moved.overflowY)
        var v = draft
        v.panX = panX
        v.panY = panY
        let fit = placeMedia(srcW: item.width, srcH: item.height, cell: frame, view: v).fit
        draft.panX = panX * fit
        draft.panY = panY * fit
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 10) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ChipButton(title: "Left", symbol: "rotate.left") { turn(-1) }
                    ChipButton(title: "Right", symbol: "rotate.right") { turn(1) }
                    ChipButton(title: "Flip", symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right", isOn: draft.flip) {
                        withAnimation(.smooth) { draft.flip.toggle(); draft.panX = -draft.panX }
                    }
                    ChipButton(title: "Reset", symbol: "arrow.counterclockwise") {
                        withAnimation(.smooth) { draft = MediaView() }
                    }
                }
            }
            SliderRow(title: "Zoom", value: $draft.zoom, range: 1...4, step: 0.01) { "\(Int(($0 * 100).rounded()))%" }
            SliderRow(title: "Straighten", value: $draft.angle, range: -45...45, step: 0.5) {
                ($0 > 0 ? "+" : "") + String(format: "%.1f", $0).replacingOccurrences(of: ".0", with: "") + "°"
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private func turn(_ dir: Double) {
        withAnimation(.smooth) {
            draft.rotation = (draft.rotation + 90 * dir + 360).truncatingRemainder(dividingBy: 360)
            draft.panX = 0
            draft.panY = 0
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
