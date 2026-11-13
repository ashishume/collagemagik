import SwiftUI

// MARK: - Media

struct MediaPanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        let inCells = Set(store.project.cells.compactMap(\.mediaId))
        let placed = inCells.union(store.project.overlays.map(\.mediaId))
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trayCaption(placed: inCells.count))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                if store.importing { ProgressView().controlSize(.small) }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        addTile
                        ForEach(store.items) { m in
                            thumb(m, used: placed.contains(m.id))
                        }
                        // A few faint empty slots: the strip shows there is room left (the tray holds up to \(maxTrayItems)).
                        ForEach(0..<min(4, max(0, maxTrayItems - store.items.count)), id: \.self) { _ in
                            emptySlot
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .scrollClipDisabled()
            if !store.items.isEmpty {
                Label("Tap to fill a cell · hold and drag onto the design to put it on top", systemImage: "square.on.square")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    /// "5 of 15 in tray · 5 of 9 in collage · 1 of 2 videos": the tray holds more than the collage can show.
    private func trayCaption(placed: Int) -> String {
        var text = "\(store.items.count) of \(maxTrayItems) in tray  ·  \(placed) of \(store.cellLimit) in \(store.isCarousel ? "carousel" : "collage")"
        if !store.isCarousel { text += "  ·  \(store.videoCount) of \(maxVideos) videos" }
        return text
    }

    private var addTile: some View {
        Menu {
            Button { store.openAdd() } label: { Label("Photo Library", systemImage: "photo.on.rectangle") }
            Button { store.openFiles() } label: { Label("Files", systemImage: "folder") }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "plus").font(.title3.weight(.semibold))
                Text("Add").font(.caption2.weight(.medium))
            }
            .frame(width: 58, height: 58)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .glassEffect(.regular.tint(Color.brand.opacity(0.55)).interactive(), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        // Not disabled when the tray is full: tapping explains how to make room.
        .disabled(store.importing)
        .accessibilityLabel("Add photos or videos")
    }

    private var emptySlot: some View {
        Button { store.openAdd() } label: {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .frame(width: 58, height: 58)
                .overlay { Image(systemName: "plus").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.35)) }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(store.importing)
        .accessibilityHidden(true)
    }

    private func thumb(_ m: MediaItem, used: Bool) -> some View {
        Button {
            store.placeMedia(m.id, cell: store.selectedCell)
        } label: {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: m.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(used ? Color.brand : .white.opacity(0.15), lineWidth: used ? 2.5 : 1)
                    }
                HStack(spacing: 3) {
                    if m.kind == .video {
                        Image(systemName: "film").font(.system(size: 9, weight: .bold))
                        Text(formatTime(m.duration)).font(.system(size: 10, weight: .semibold).monospacedDigit())
                    } else if !used {
                        Text("In tray").font(.system(size: 9, weight: .semibold))
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.black.opacity(0.55), in: Capsule())
                .opacity(m.kind == .video || !used ? 1 : 0)
                .padding(4)
            }
        }
        .buttonStyle(.plain)
        // hold and drag onto the design to lay the photo on top, anywhere
        .draggable(m.id) {
            Image(uiImage: m.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(5)
                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .rotationEffect(.degrees(-4))
        }
        .contextMenu {
            Button { store.placeMedia(m.id, cell: store.selectedCell) } label: { Label("Use in selected cell", systemImage: "square.and.arrow.down") }
            if m.kind == .photo {
                Button { withAnimation(.smooth) { _ = store.addOverlay(m.id) } } label: { Label("Put on top", systemImage: "square.on.square") }
            }
            Button(role: .destructive) { withAnimation(.smooth) { store.removeMedia(m.id) } } label: { Label("Remove", systemImage: "trash") }
        }
        .accessibilityLabel("\(m.kind == .video ? "Video" : "Photo") \(m.name). \(used ? "In the collage" : "In the tray. Tap to put it in the selected cell")")
    }
}

// MARK: - Layout

struct LayoutThumb: View {
    let layout: CollageLayout
    let isOn: Bool
    /// Carousel layouts: how many slides, so the thumbnail can show where the seams fall.
    var slides: Int? = nil

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(Array(layout.rects.enumerated()), id: \.offset) { _, r in
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(isOn ? Color.white : Color.white.opacity(0.55))
                            .frame(width: max(2, geo.size.width * (r.w - (slides == nil ? 0.045 : 0.012))), height: max(2, geo.size.height * (r.h - 0.03)))
                            .offset(x: geo.size.width * (r.x + (slides == nil ? 0.0225 : 0.006)), y: geo.size.height * (r.y + 0.015))
                    }
                    if let slides {
                        ForEach(1..<max(slides, 1), id: \.self) { k in
                            Path { p in
                                let x = geo.size.width * Double(k) / Double(slides)
                                p.move(to: CGPoint(x: x, y: -2))
                                p.addLine(to: CGPoint(x: x, y: geo.size.height + 2))
                            }
                            .stroke(Color.brand, style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2]))
                        }
                    }
                }
            }
            .frame(width: slides == nil ? 28 : 76, height: slides == nil ? 44 : 30)
            Text(layout.name)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
                .frame(width: slides == nil ? 52 : 76)
                .foregroundStyle(isOn ? .primary : .secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .glassEffect(isOn ? .regular.tint(Color.brand.opacity(0.7)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 13))
    }
}

struct LayoutPanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        let options = layoutOptions(for: store.project)
        let carousel = store.isCarousel
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                if carousel {
                    // nobody picks the slide count: it follows the pictures and the style
                    let photos = store.project.cellCount, slides = store.project.slides
                    Label("\(photos) \(photos == 1 ? "photo" : "photos") · \(slides) slides, added for you", systemImage: "rectangle.split.3x1")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                } else {
                    Text("Cells").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        GlassEffectContainer(spacing: 6) {
                            HStack(spacing: 6) {
                                ForEach(Array(1...maxCells), id: \.self) { n in
                                    let on = store.project.cellCount == n
                                    Button {
                                        withAnimation(.smooth) { store.setCellCount(n) }
                                    } label: {
                                        Text("\(n)")
                                            .font(.footnote.weight(.semibold).monospacedDigit())
                                            .frame(width: 28, height: 28)
                                            .glassEffect(on ? .regular.tint(Color.brand.opacity(0.8)).interactive() : .regular.interactive(), in: .circle)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(n) cells")
                                    .accessibilityAddTraits(on ? .isSelected : [])
                                }
                            }
                        }
                    }
                }
                GlassIconButton(symbol: "shuffle", label: "Try another arrangement", size: 30) {
                    withAnimation(.smooth) { store.shuffleLayout() }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(options) { l in
                            let on = carousel ? (carouselStyle(of: l.id) == store.project.carouselStyleInUse) : (l.id == store.project.layoutId)
                            Button {
                                // a random style keeps its current arrangement when you tap it again
                                withAnimation(.smooth) { store.setLayout(on ? store.project.layoutId : l.id) }
                            } label: {
                                LayoutThumb(layout: l, isOn: on, slides: carousel ? carouselStyle(of: l.id).map { autoSlides(count: store.project.cellCount, style: $0) } : nil)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(l.name)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
            }
            .scrollClipDisabled()
            if !carousel && store.project.resizableGrid?.dividers.isEmpty == false {
                HStack(spacing: 6) {
                    Label("Drag the borders between pictures to resize them", systemImage: "arrow.left.and.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    if store.project.hasCustomSizes {
                        ChipButton(title: "Reset sizes", symbol: "arrow.uturn.backward") {
                            withAnimation(.smooth) { store.project.cellSizes = nil }
                        }
                        .transition(.opacity)
                        .accessibilityHint("Puts every cell back to the layout's own size")
                    }
                }
                .frame(minHeight: 28)
            }
        }
        .sensoryFeedback(.selection, trigger: store.project.layoutId)
    }
}

// MARK: - Style

struct StylePanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 6) {
            Picker("Format", selection: $store.project.format) {
                ForEach(store.isCarousel ? FormatId.carouselFormats : FormatId.allCases) { f in Text(f.label).tag(f) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 14) {
                compactSlider("Gap", value: $store.project.gap, range: 0...48)
                compactSlider("Corners", value: $store.project.radius, range: 0...80)
            }

            HStack(spacing: 10) {
                Text("Colour")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(backgroundSwatches, id: \.self) { c in
                            let on = store.project.bg.lowercased() == c
                            Button { store.project.bg = c } label: {
                                Circle().fill(Color(hex: c))
                                    .frame(width: 24, height: 24)
                                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                                    .overlay(Circle().strokeBorder(Color.brand, lineWidth: on ? 3 : 0).padding(-4))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Background \(c)")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(5)
                }
                ColorPicker("Custom colour", selection: Binding(
                    get: { Color(hex: store.project.bg) },
                    set: { store.project.bg = $0.hexString }
                ), supportsOpacity: false)
                .labelsHidden()
            }

            frameSection

            if store.project.format == .story {
                Toggle(isOn: $store.project.safeZone) {
                    Label("Show the area Instagram covers", systemImage: store.project.safeZone ? "eye.slash" : "eye")
                        .font(.footnote)
                }
            }
        }
    }
}

extension StylePanel {
    /// Frame: the style, then its colour and thickness.
    @ViewBuilder
    var frameSection: some View {
        @Bindable var store = store
        let frame = store.project.frame
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Text("Frame")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer(spacing: 6) {
                        HStack(spacing: 6) {
                            ForEach(PhotoFrame.allCases) { f in
                                ChipButton(title: f.title, symbol: f.symbol, isOn: f == frame) {
                                    withAnimation(.smooth) { store.project.frame = f }
                                }
                                .accessibilityAddTraits(f == frame ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .scrollClipDisabled()
            }
            if frame.hasEdge {
                HStack(spacing: 8) {
                    ForEach(frameSwatches, id: \.self) { c in
                        let on = store.project.frameColor.lowercased() == c
                        Button { store.project.frameColor = c } label: {
                            Circle().fill(Color(hex: c))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                                .overlay(Circle().strokeBorder(Color.brand, lineWidth: on ? 3 : 0).padding(-4))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Frame colour \(c)")
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                    ColorPicker("Custom frame colour", selection: Binding(
                        get: { Color(hex: store.project.frameColor) },
                        set: { store.project.frameColor = $0.hexString }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    Slider(value: $store.project.frameWidth, in: 6...60)
                        .accessibilityLabel("Frame thickness")
                }
                .padding(.leading, 4)
            }
            if frame != .none {
                // one line: the card's height leaves room for exactly one
                Text("Frames every photo in the layout. Photos on top have their own.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    func compactSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
                .accessibilityLabel(title)
        }
    }
}

// MARK: - Audio

struct AudioPanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        let lanes = placedLanes(store.project)
        VStack(alignment: .leading, spacing: 6) {
            if lanes.isEmpty {
                HintRow(symbol: "waveform.slash", text: "Add a video to control its sound and add background music.")
            } else {
                ForEach(Array(lanes.enumerated()), id: \.element.mediaId) { i, lane in
                    laneRow(i, lane)
                }
                musicSection
            }
        }
    }

    private func laneRow(_ i: Int, _ lane: Lane) -> some View {
        let item = store.item(lane.mediaId)
        let name = i == 0 ? "A" : "B"
        return HStack(spacing: 8) {
            Text(name)
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(i == 0 ? Color.laneA : Color.laneB, in: Circle())
                .foregroundStyle(.black.opacity(0.8))
            if item?.hasAudio == true {
                Image(systemName: lane.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: 22)
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { lane.volume },
                    set: { v in store.setLane(lane.mediaId) { $0.volume = v } }
                ), in: 0...1)
                .accessibilityLabel("Volume of video \(name)")
            } else {
                Text("No sound in this video").font(.footnote).foregroundStyle(.secondary)
                Spacer()
            }
            ChipButton(title: "Loop", symbol: "repeat", isOn: lane.loop) {
                store.setLane(lane.mediaId) { $0.loop.toggle() }
            }
        }
    }

    @ViewBuilder
    private var musicSection: some View {
        @Bindable var store = store
        if let music = store.project.music {
            HStack(spacing: 8) {
                Image(systemName: "music.note").foregroundStyle(Color.musicGreen).frame(width: 22)
                Text(music.name).font(.footnote.weight(.medium)).lineLimit(1)
                Spacer()
                Button(role: .destructive) { store.removeMusic() } label: { Image(systemName: "trash").font(.footnote) }
                    .buttonStyle(.glass).buttonBorderShape(.circle).controlSize(.small)
                    .accessibilityLabel("Remove music")
            }
            HStack(spacing: 8) {
                Text("Volume").font(.footnote).foregroundStyle(.secondary).frame(width: 50, alignment: .leading)
                Slider(value: Binding(
                    get: { music.volume },
                    set: { v in store.project.music?.volume = v }
                ), in: 0...1)
                .accessibilityLabel("Music volume")
            }
            Toggle("Fade out at the end", isOn: Binding(
                get: { music.fadeOut },
                set: { v in store.project.music?.fadeOut = v }
            ))
            .font(.footnote)
        } else {
            ChipButton(title: "Add background music", symbol: "music.note.list") { store.openMusicImporter() }
        }
    }
}

// MARK: - Picture

struct PicturePanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        if let sel = store.selectedCell, store.project.cells.indices.contains(sel) {
            let cell = store.project.cells[sel]
            let filled = cell.mediaId != nil
            if store.swapFrom != nil {
                HStack {
                    Label("Tap another cell in the preview to swap.", systemImage: "arrow.left.arrow.right")
                        .font(.footnote)
                    Spacer()
                    ChipButton(title: "Cancel", symbol: "xmark") { withAnimation { store.swapFrom = nil } }
                }
            } else if !filled {
                HStack(spacing: 8) {
                    ChipButton(title: "Add photo or video", symbol: "photo.badge.plus") { store.openAdd(cell: sel) }
                    Spacer(minLength: 0)
                    doneButton
                }
            } else {
                VStack(spacing: 8) {
                    GlassEffectContainer(spacing: 6) {
                        HStack(spacing: 6) {
                            CompactTool(title: "Change", symbol: "photo.badge.plus") { store.openAdd(cell: sel) }
                            CompactTool(title: "Swap", symbol: "arrow.left.arrow.right") { withAnimation { store.swapFrom = sel } }
                            CompactTool(title: "Rotate", symbol: "rotate.right") { withAnimation(.smooth) { store.rotateCell(sel) } }
                            CompactTool(title: "Flip", symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right", isOn: cell.flip) {
                                withAnimation(.smooth) { store.flipCell(sel) }
                            }
                            CompactTool(title: "Crop", symbol: "crop") { store.cropCell = sel }
                            CompactTool(title: "Delete", symbol: "xmark", role: .destructive) { store.clearCell(sel) }
                        }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "minus.magnifyingglass").font(.footnote).foregroundStyle(.secondary)
                        Slider(value: Binding(
                            get: { cell.zoom },
                            set: { v in store.setCellView(sel) { $0.zoom = v } }
                        ), in: 1...4)
                        .accessibilityLabel("Zoom")
                        Image(systemName: "plus.magnifyingglass").font(.footnote).foregroundStyle(.secondary)
                        GlassIconButton(symbol: "arrow.counterclockwise", label: "Reset zoom, position, rotation and flip", size: 30) {
                            withAnimation(.smooth) { store.resetCell(sel) }
                        }
                        doneButton
                    }
                }
            }
        } else {
            HintRow(symbol: "hand.tap", text: "Tap a picture in the preview to replace, swap, rotate, flip, crop and zoom it.")
        }
    }

    private var doneButton: some View {
        Button { store.selectCell(nil) } label: {
            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).frame(width: 30, height: 30)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .accessibilityLabel("Done")
    }
}

// MARK: - Photo on top

/// Opens by itself while a photo laid on top is selected: its frame, size, tilt, place in the pile.
struct OverlayPanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        if let o = store.overlay(store.selectedOverlay) {
            VStack(spacing: 7) {
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer(spacing: 6) {
                        HStack(spacing: 6) {
                            ForEach(PhotoFrame.allCases) { f in
                                ChipButton(title: f.title, symbol: f.symbol, isOn: f == o.frame) {
                                    withAnimation(.smooth) { store.updateOverlay(o.id) { $0.frame = f } }
                                }
                                .accessibilityAddTraits(f == o.frame ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .scrollClipDisabled()
                if o.frame.hasEdge {
                    HStack(spacing: 9) {
                        ForEach(frameSwatches, id: \.self) { c in
                            let on = o.frameColor.lowercased() == c
                            Button { store.updateOverlay(o.id) { $0.frameColor = c } } label: {
                                Circle().fill(Color(hex: c))
                                    .frame(width: 22, height: 22)
                                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                                    .overlay(Circle().strokeBorder(Color.brand, lineWidth: on ? 3 : 0).padding(-4))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Frame colour \(c)")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                        ColorPicker("Custom frame colour", selection: Binding(
                            get: { Color(hex: o.frameColor) },
                            set: { v in store.updateOverlay(o.id) { $0.frameColor = v.hexString } }
                        ), supportsOpacity: false)
                        .labelsHidden()
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 4)
                }
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right").font(.footnote).foregroundStyle(.secondary)
                    Slider(value: Binding(get: { o.w }, set: { v in store.updateOverlay(o.id) { $0.w = v } }), in: overlayWidthRange)
                        .accessibilityLabel("Size")
                    Image(systemName: "rotate.right").font(.footnote).foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { clamp(o.tilt, -45, 45) },
                        // level holds on a little, so a straight photo is easy to get back
                        set: { v in store.updateOverlay(o.id) { $0.tilt = abs(v) < 1.5 ? 0 : v } }
                    ), in: -45...45)
                    .accessibilityLabel("Tilt")
                }
                HStack(spacing: 6) {
                    GlassEffectContainer(spacing: 6) {
                        HStack(spacing: 6) {
                            CompactTool(title: "Forward", symbol: "square.2.layers.3d.top.filled") {
                                withAnimation(.smooth) { store.restackOverlay(o.id, up: true) }
                            }
                            CompactTool(title: "Back", symbol: "square.2.layers.3d.bottom.filled") {
                                withAnimation(.smooth) { store.restackOverlay(o.id, up: false) }
                            }
                            CompactTool(title: "Duplicate", symbol: "plus.square.on.square") {
                                withAnimation(.smooth) { store.duplicateOverlay(o.id) }
                            }
                            CompactTool(title: "Delete", symbol: "trash", role: .destructive) {
                                withAnimation(.smooth) { store.removeOverlay(o.id) }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Button { store.selectOverlay(nil) } label: {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .accessibilityLabel("Done")
                }
            }
        } else {
            HintRow(symbol: "hand.draw", text: "Hold a photo in the tray and drag it onto the design to lay it on top.")
        }
    }
}
