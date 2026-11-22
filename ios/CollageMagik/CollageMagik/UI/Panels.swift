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
                Label(
                    store.selectedOverlay != nil ? String(localized: "Tap a photo to put it in the selected photo on top")
                        : store.selectedCell != nil ? String(localized: "Tap to put it in the selected cell · hold and drag onto the design to put it on top")
                        : String(localized: "Tap to fill a cell · hold and drag onto the design to put it on top"),
                    systemImage: "square.on.square"
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    /// "5 of 25 in tray · 5 of 12 in collage · 1 of 3 videos": the tray holds more than the collage can show.
    private func trayCaption(placed: Int) -> String {
        var text = String(localized: "\(store.items.count) of \(maxTrayItems) in tray  ·  \(placed) of \(store.cellLimit) in the design")
        if !store.isCarousel { text += String(localized: "  ·  \(store.videoCount) of \(maxVideos) videos") }
        return text
    }

    private var addTile: some View {
        Menu {
            Button { store.openAdd() } label: { Label(String(localized: "Photo Library"), systemImage: "photo.on.rectangle") }
            Button { store.openFiles() } label: { Label(String(localized: "Files"), systemImage: "folder") }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "plus").font(.title3.weight(.semibold))
                Text(String(localized: "Add")).font(.caption2.weight(.medium))
            }
            .frame(width: 58, height: 58)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .glassEffect(.regular.tint(Color.brand.opacity(0.55)).interactive(), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        // Not disabled when the tray is full: tapping explains how to make room.
        .disabled(store.importing)
        .accessibilityLabel(String(localized: "Add photos or videos"))
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
            if let o = store.selectedOverlay {
                withAnimation(.smooth) { store.replaceOverlayMedia(o, with: m.id) }
            } else {
                store.placeMedia(m.id, cell: store.selectedCell)
            }
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
                        Text(String(localized: "In tray")).font(.system(size: 9, weight: .semibold))
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
            Button { store.placeMedia(m.id, cell: store.selectedCell) } label: { Label(String(localized: "Use in selected cell"), systemImage: "square.and.arrow.down") }
            if m.kind == .photo {
                Button { withAnimation(.smooth) { _ = store.addOverlay(m.id) } } label: { Label(String(localized: "Put on top"), systemImage: "square.on.square") }
            }
            Button(role: .destructive) { withAnimation(.smooth) { store.removeMedia(m.id) } } label: { Label(String(localized: "Remove"), systemImage: "trash") }
        }
        .accessibilityLabel(String(localized: "\(m.kind == .video ? String(localized: "Video") : String(localized: "Photo")) \(m.name). \(used ? String(localized: "In the collage") : String(localized: "In the tray. Tap to put it in the selected cell"))"))
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
    @State private var templatesOpen = false

    var body: some View {
        if store.project.isMotion {
            MotionPanel()
        } else {
            stillBody
        }
    }

    private var stillBody: some View {
        let options = layoutOptions(for: store.project)
        let carousel = store.isCarousel
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                if carousel {
                    // nobody picks the slide count: it follows the pictures and the style
                    let photos = store.project.cellCount, slides = store.project.slides
                    Label(String(localized: "Photos: \(photos) · Slides added for you: \(slides)"), systemImage: "rectangle.split.3x1")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                } else {
                    // nobody picks the cell count either: one cell per picture, and the layouts follow
                    let photos = store.project.cells.filter { $0.mediaId != nil }.count
                    Label(
                        photos == 0 ? String(localized: "Add photos and up to \(maxVideos) videos, the layouts fit how many you add")
                            : String(localized: "Pictures: \(photos) · Up to \(maxCells) fit in a collage"),
                        systemImage: "info.circle"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                }
                Button { templatesOpen = true } label: {
                    Label(String(localized: "Templates"), systemImage: "sparkles.rectangle.stack")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .glassEffect(.regular.tint(Color.brand.opacity(0.55)).interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                if !carousel {
                    // makes the collage move through scenes, exported as a video
                    GlassIconButton(symbol: "sparkles", label: String(localized: "Animate"), size: 30) {
                        withAnimation(.smooth) { store.animateDesign() }
                    }
                    .accessibilityHint(String(localized: "Your pictures move through scenes, saved as a video"))
                }
                GlassIconButton(symbol: "shuffle", label: String(localized: "Try another arrangement"), size: 30) {
                    withAnimation(.smooth) { store.shuffleLayout() }
                }
            }
            .sheet(isPresented: $templatesOpen) { TemplateBrowserSheet() }
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(options) { l in
                            let on = carousel ? (carouselStyle(of: l.id) == store.project.carouselStyleInUse) : (l.id == store.project.layoutId)
                            Button {
                                // a random style keeps its current arrangement when you tap it again
                                withAnimation(.smooth) { store.setLayout(on ? store.project.layoutId : l.id) }
                            } label: {
                                LayoutThumb(layout: l, isOn: on, slides: carousel ? carouselStyle(of: l.id).map { autoSlides(count: store.project.cellCount, style: $0, format: store.project.format) } : nil)
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
                    Label(String(localized: "Drag the borders between pictures to resize them"), systemImage: "arrow.left.and.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    if store.project.hasCustomSizes {
                        ChipButton(title: String(localized: "Reset sizes"), symbol: "arrow.uturn.backward") {
                            withAnimation(.smooth) { store.project.cellSizes = nil }
                        }
                        .transition(.opacity)
                        .accessibilityHint(String(localized: "Puts every cell back to the layout's own size"))
                    }
                }
                .frame(minHeight: 28)
            }
        }
        .sensoryFeedback(.selection, trigger: store.project.layoutId)
    }
}

// MARK: - Style

/// The Style tab's groups: one shows at a time, under a row of tabs.
enum StyleSection: String, PanelSection {
    case size, spacing, background, frame
    var id: String { rawValue }
    var title: String {
        switch self {
        case .size: String(localized: "Size")
        case .spacing: String(localized: "Spacing")
        case .background: String(localized: "Background")
        case .frame: String(localized: "Frame")
        }
    }
    var symbol: String {
        switch self {
        case .size: "aspectratio"
        case .spacing: "square.split.2x2"
        case .background: "paintpalette"
        case .frame: "photo.artframe"
        }
    }
    /// One line under the tabs that says what the group changes.
    var hint: String {
        switch self {
        case .size: String(localized: "The shape of the picture you'll post")
        case .spacing: String(localized: "Space between pictures, and how round their corners are")
        case .background: String(localized: "What shows behind and between your pictures")
        case .frame: String(localized: "A frame around every photo and video in the layout")
        }
    }
}

struct StylePanel: View {
    @Environment(CollageStore.self) private var store

    /// Space between the rows inside a group: roomy, so each control reads on its own.
    static let rowSpacing: CGFloat = 12
    static let hintHeight: CGFloat = 16

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 12) {
            SectionTabs(selection: $store.styleSection)
                .frame(height: panelTabsHeight)
            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                Text(store.styleSection.hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: Self.hintHeight)
                switch store.styleSection {
                case .size: sizeSection
                case .spacing: spacingSection
                case .background: BackdropPicker()
                case .frame: frameSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .transition(.opacity)
        }
        .animation(.smooth(duration: 0.25), value: store.styleSection)
    }

    /// Height of the whole panel for the open group, so the card fits it without scrolling.
    static func height(for store: CollageStore) -> CGFloat {
        let p = store.project
        let content: CGFloat
        switch store.styleSection {
        case .size: content = formatCardHeight + (p.format == .story ? rowSpacing + 31 : 0)
        case .spacing: content = 2 * sliderRowHeight + rowSpacing
        case .background: content = 32 + 6 + (p.backdrop.kind == .pattern ? 26 + 4 + 44 : 44)
        case .frame: content = 34 + (p.frame.usesColor ? rowSpacing + sliderRowHeight : 0) + (p.frame.hasEdge ? rowSpacing + sliderRowHeight : 0)
        }
        return panelTabsHeight + 12 + hintHeight + rowSpacing + content
    }
}

extension StylePanel {
    static let formatCardHeight: CGFloat = 70
    static let sliderRowHeight: CGFloat = 32

    // MARK: Size

    @ViewBuilder
    var sizeSection: some View {
        @Bindable var store = store
        let formats = store.isCarousel ? FormatId.carouselFormats : FormatId.allCases
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(formats) { f in
                    let on = f == store.project.format
                    Button {
                        withAnimation(.smooth) { store.project.format = f }
                        if store.isCarousel { store.carouselFormatChosen = true }
                    } label: {
                        formatCard(f, on: on)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(f.label)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        if store.project.format == .story {
            Toggle(isOn: $store.project.safeZone) {
                Label(String(localized: "Show the area Instagram covers"), systemImage: store.project.safeZone ? "eye.slash" : "eye")
                    .font(.footnote)
            }
        }
    }

    private func formatCard(_ f: FormatId, on: Bool) -> some View {
        HStack(spacing: 10) {
            // the shape itself, drawn to its ratio
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(on ? Color.white : Color.white.opacity(0.6), lineWidth: 1.6)
                .frame(width: 30 * f.width / f.height * (f == .story ? 1.0 : 0.85), height: f == .story ? 30 : 30 * 0.85)
                .frame(width: 30, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(f.name).font(.footnote.weight(.semibold))
                Text(f.short).font(.caption2.monospacedDigit()).foregroundStyle(on ? .primary : .secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .foregroundStyle(on ? Color.white : Color.white.opacity(0.75))
        .frame(maxWidth: .infinity)
        .frame(height: Self.formatCardHeight)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .glassEffect(on ? .regular.tint(Color.brand.opacity(0.7)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 16))
    }

    // MARK: Spacing

    @ViewBuilder
    var spacingSection: some View {
        @Bindable var store = store
        labeledSlider(String(localized: "Gap"), symbol: "arrow.left.and.right", value: $store.project.gap, range: 0...48)
        labeledSlider(String(localized: "Corners"), symbol: "square.on.circle", value: $store.project.radius, range: 0...80)
    }

    // MARK: Frame

    /// The style, then its colour and thickness.
    @ViewBuilder
    var frameSection: some View {
        @Bindable var store = store
        let frame = store.project.frame
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(PhotoFrame.allCases) { f in
                        ChipButton(title: f.title, symbol: f.symbol, isOn: f == frame) {
                            withAnimation(.smooth) { store.selectFrame(f) }
                        }
                        .accessibilityAddTraits(f == frame ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .scrollClipDisabled()
        .frame(height: 34)
        if frame.usesColor {
            HStack(spacing: 10) {
                rowLabel(frame == .neon ? String(localized: "Light") : String(localized: "Color"), symbol: "paintbrush")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(frameSwatches, id: \.self) { c in
                            let on = store.project.frameColor.lowercased() == c
                            Button { store.project.frameColor = c } label: {
                                Circle().fill(Color(hex: c))
                                    .frame(width: 22, height: 22)
                                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                                    .overlay(Circle().strokeBorder(Color.brand, lineWidth: on ? 3 : 0).padding(-4))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "Frame color \(c)"))
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(5)
                }
                ColorPicker(String(localized: "Custom frame color"), selection: Binding(
                    get: { Color(hex: store.project.frameColor) },
                    set: { store.project.frameColor = $0.hexString }
                ), supportsOpacity: false)
                .labelsHidden()
            }
            .frame(height: Self.sliderRowHeight)
        }
        if frame.hasEdge {
            labeledSlider(String(localized: "Thickness"), symbol: "lineweight", value: $store.project.frameWidth, range: 6...60)
        }
    }

    // MARK: Rows

    private func rowLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(width: 96, alignment: .leading)
    }

    /// Name on the left, the slider, then its value: one line per setting.
    func labeledSlider(_ title: String, symbol: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 10) {
            rowLabel(title, symbol: symbol)
            Slider(value: value, in: range)
                .accessibilityLabel(title)
            Text(String(localized: "\(Int(value.wrappedValue.rounded()))"))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)
        }
        .frame(height: Self.sliderRowHeight)
    }
}

private extension FormatId {
    /// "Story", "Post", "Square": the label without its ratio.
    var name: String { label.replacingOccurrences(of: " " + short, with: "") }
}

// MARK: - Audio

struct AudioPanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        let lanes = placedLanes(store.project)
        VStack(alignment: .leading, spacing: 6) {
            if lanes.isEmpty {
                HintRow(symbol: "waveform.slash", text: String(localized: "Add a video to control its sound and add background music."))
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
        let name = laneName(i)
        return HStack(spacing: 8) {
            Text(name)
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(Color.lane(i), in: Circle())
                .foregroundStyle(.black.opacity(0.8))
            if item?.hasAudio == true {
                Image(systemName: lane.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .frame(width: 22)
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { lane.volume },
                    set: { v in store.setLane(lane.mediaId) { $0.volume = v } }
                ), in: 0...1)
                .accessibilityLabel(String(localized: "Volume of video \(name)"))
            } else {
                Text(String(localized: "No sound in this video")).font(.footnote).foregroundStyle(.secondary)
                Spacer()
            }
            ChipButton(title: String(localized: "Loop"), symbol: "repeat", isOn: lane.loop) {
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
                    .accessibilityLabel(String(localized: "Remove music"))
            }
            HStack(spacing: 8) {
                Text(String(localized: "Volume")).font(.footnote).foregroundStyle(.secondary).frame(width: 50, alignment: .leading)
                Slider(value: Binding(
                    get: { music.volume },
                    set: { v in store.project.music?.volume = v }
                ), in: 0...1)
                .accessibilityLabel(String(localized: "Music volume"))
            }
            Toggle(String(localized: "Fade out at the end"), isOn: Binding(
                get: { music.fadeOut },
                set: { v in store.project.music?.fadeOut = v }
            ))
            .font(.footnote)
        } else {
            ChipButton(title: String(localized: "Add background music"), symbol: "music.note.list") { store.openMusicImporter() }
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
                    Label(String(localized: "Tap another cell in the preview to swap."), systemImage: "arrow.left.arrow.right")
                        .font(.footnote)
                    Spacer()
                    ChipButton(title: String(localized: "Cancel"), symbol: "xmark") { withAnimation { store.swapFrom = nil } }
                }
            } else if !filled {
                HStack(spacing: 8) {
                    ChipButton(title: String(localized: "Add photo or video"), symbol: "photo.badge.plus") { store.openAdd(cell: sel) }
                    Spacer(minLength: 0)
                    doneButton
                }
            } else {
                VStack(spacing: 8) {
                    GlassEffectContainer(spacing: 6) {
                        HStack(spacing: 6) {
                            CompactTool(title: String(localized: "Change"), symbol: "photo.badge.plus") { store.openAdd(cell: sel) }
                            CompactTool(title: String(localized: "Swap"), symbol: "arrow.left.arrow.right") { withAnimation { store.swapFrom = sel } }
                            CompactTool(title: String(localized: "Resize"), symbol: "arrow.up.left.and.arrow.down.right", isOn: store.resizeOpen || cell.fit) {
                                withAnimation(.smooth) { store.adjustOpen = false; store.resizeOpen.toggle() }
                            }
                            if let id = cell.mediaId, store.item(id)?.kind == .photo {
                                CompactTool(title: String(localized: "Look"), symbol: "camera.filters", isOn: store.adjustOpen || !cell.look.isOriginal) {
                                    withAnimation(.smooth) { store.resizeOpen = false; store.adjustOpen.toggle() }
                                }
                            }
                            CompactTool(title: String(localized: "Rotate"), symbol: "rotate.right") { withAnimation(.smooth) { store.rotateCell(sel) } }
                            CompactTool(title: String(localized: "Flip"), symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right", isOn: cell.flip) {
                                withAnimation(.smooth) { store.flipCell(sel) }
                            }
                            CompactTool(title: String(localized: "Crop"), symbol: "crop") { store.cropCell = sel }
                            // this picture's own frame; Style → Frame sets every picture at once
                            CompactMenuTool(title: String(localized: "Frame"), symbol: "photo.artframe", isOn: cell.frame != nil) {
                                Button {
                                    withAnimation(.smooth) { store.setCellFrame(sel, nil) }
                                } label: {
                                    Label(String(localized: "Same as all (\(store.project.frame.title))"), systemImage: cell.frame == nil ? "checkmark" : "square.stack")
                                }
                                Divider()
                                ForEach(PhotoFrame.allCases) { f in
                                    Button {
                                        withAnimation(.smooth) { store.setCellFrame(sel, f) }
                                    } label: {
                                        Label(f.title, systemImage: cell.frame == f ? "checkmark" : f.symbol)
                                    }
                                }
                            }
                            CompactTool(title: String(localized: "Delete"), symbol: "xmark", role: .destructive) { store.clearCell(sel) }
                        }
                    }
                    if store.adjustOpen, let id = cell.mediaId, let item = store.item(id), item.kind == .photo {
                        PhotoLookTools(sel: sel, cell: cell, item: item) { withAnimation(.smooth) { store.adjustOpen = false } }
                    } else if store.resizeOpen {
                        resizeTools(sel, cell)
                    } else {
                    if let id = cell.mediaId, store.item(id)?.kind == .video {
                        HStack(spacing: 6) {
                            ChipButton(title: String(localized: "Edit timeline"), symbol: "film.stack") { store.openVideo(.timeline) }
                            ChipButton(title: String(localized: "Sound"), symbol: "speaker.wave.2") { store.openVideo(.sound) }
                            Spacer(minLength: 0)
                        }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "minus.magnifyingglass").font(.footnote).foregroundStyle(.secondary)
                        Slider(value: Binding(
                            get: { cell.zoom },
                            set: { v in store.setCellView(sel) { $0.zoom = v } }
                        ), in: 1...4)
                        .accessibilityLabel(String(localized: "Zoom"))
                        Image(systemName: "plus.magnifyingglass").font(.footnote).foregroundStyle(.secondary)
                        GlassIconButton(symbol: "arrow.counterclockwise", label: String(localized: "Reset zoom, position, rotation and flip"), size: 30) {
                            withAnimation(.smooth) { store.resetCell(sel) }
                        }
                        doneButton
                    }
                    }
                }
            }
        } else {
            HintRow(symbol: "hand.tap", text: String(localized: "Tap a picture in the preview to replace, swap, rotate, flip, crop and zoom it."))
        }
    }

    /// Resize: fill the cell (cropping), or fit the whole picture in it; a fitted picture's sides are blurred or a colour.
    @ViewBuilder
    private func resizeTools(_ sel: Int, _ cell: CellState) -> some View {
        HStack(spacing: 8) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ChipButton(title: String(localized: "Fill cell"), symbol: "rectangle.fill", isOn: !cell.fit) {
                        withAnimation(.smooth) { store.setCellView(sel) { $0.fit = false } }
                    }
                    .accessibilityHint(String(localized: "Fills the cell; the edges of the picture may be cut off"))
                    ChipButton(title: String(localized: "Fit whole picture"), symbol: "rectangle.portrait.inset.filled", isOn: cell.fit) {
                        withAnimation(.smooth) { store.setCellView(sel) { $0.fit = true; $0.zoom = 1; $0.panX = 0; $0.panY = 0 } }
                    }
                    .accessibilityHint(String(localized: "Shows the whole picture, with blurred or colored sides"))
                }
            }
            Spacer(minLength: 0)
            Button { withAnimation(.smooth) { store.resizeOpen = false } } label: {
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).frame(width: 30, height: 30)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .controlSize(.small)
            .accessibilityLabel(String(localized: "Done resizing"))
        }
        if cell.fit {
            HStack(spacing: 10) {
                Text(String(localized: "Sides")).font(.footnote).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        let blurOn = cell.fitBars == fitBlur
                        Button { store.setCellView(sel) { $0.fitBars = fitBlur } } label: {
                            Group {
                                if let id = cell.mediaId, let item = store.item(id) {
                                    Image(uiImage: item.thumbnail).resizable().scaledToFill().blur(radius: 3)
                                } else {
                                    Color.gray
                                }
                            }
                            .frame(width: 26, height: 26)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                            .overlay(Circle().strokeBorder(Color.brand, lineWidth: blurOn ? 3 : 0).padding(-4))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "Blurred picture"))
                        .accessibilityAddTraits(blurOn ? .isSelected : [])
                        ForEach(fitBarSwatches, id: \.self) { c in
                            let on = cell.fitBars.lowercased() == c
                            Button { store.setCellView(sel) { $0.fitBars = c } } label: {
                                Circle().fill(Color(hex: c))
                                    .frame(width: 26, height: 26)
                                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                                    .overlay(Circle().strokeBorder(Color.brand, lineWidth: on ? 3 : 0).padding(-4))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "Sides color \(c)"))
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(5)
                }
                ColorPicker(String(localized: "Custom sides color"), selection: Binding(
                    get: { Color(hex: cell.fitBars == fitBlur ? "#ffffff" : cell.fitBars) },
                    set: { c in store.setCellView(sel) { $0.fitBars = c.hexString } }
                ), supportsOpacity: false)
                .labelsHidden()
            }
        }
    }

    private var doneButton: some View {
        Button { store.selectCell(nil) } label: {
            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).frame(width: 30, height: 30)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .accessibilityLabel(String(localized: "Done"))
    }
}

// MARK: - Photo on top

/// The groups a photo on top's tools are sorted into. Only one group shows at a time, so the card stays short and calm.
enum OverlaySection: String, PanelSection {
    case photo, frame, size, layer
    var id: String { rawValue }
    var title: String {
        switch self {
        case .photo: String(localized: "Photo")
        case .frame: String(localized: "Frame")
        case .size: String(localized: "Size")
        case .layer: String(localized: "Layer")
        }
    }
    var symbol: String {
        switch self {
        case .photo: "photo"
        case .frame: "square.dashed"
        case .size: "arrow.up.left.and.arrow.down.right"
        case .layer: "square.3.layers.3d"
        }
    }
}

/// Opens by itself while a photo laid on top is selected. Its tools are grouped: the picture itself (change, crop,
/// rotate, flip, zoom), its frame, its size and tilt, and its place in the pile.
struct OverlayPanel: View {
    @Environment(CollageStore.self) private var store
    @State private var section: OverlaySection = .photo

    var body: some View {
        if let o = store.overlay(store.selectedOverlay) {
            SectionedPanel(section: $section, done: { store.selectOverlay(nil) }) { s in
                switch s {
                case .photo: photoTools(o)
                case .frame: frameTools(o)
                case .size: sizeTools(o)
                case .layer: layerTools(o)
                }
            }
        } else {
            HintRow(symbol: "hand.draw", text: String(localized: "Hold a photo in the tray and drag it onto the design to lay it on top."))
        }
    }

    /// The picture itself, edited exactly like a picture in a cell.
    private func photoTools(_ o: PhotoOverlay) -> some View {
        VStack(spacing: 8) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    CompactTool(title: String(localized: "Change"), symbol: "photo.badge.plus") { store.openAdd(overlay: o.id) }
                    CompactTool(title: String(localized: "Crop"), symbol: "crop") { store.cropOverlay = o.id }
                    CompactTool(title: String(localized: "Rotate"), symbol: "rotate.right") { withAnimation(.smooth) { store.rotateOverlay(o.id) } }
                    CompactTool(title: String(localized: "Flip"), symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right", isOn: o.flip) {
                        withAnimation(.smooth) { store.flipOverlay(o.id) }
                    }
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "minus.magnifyingglass").font(.footnote).foregroundStyle(.secondary)
                Slider(value: Binding(get: { o.zoom }, set: { v in store.updateOverlay(o.id) { $0.zoom = v } }), in: 1...4)
                    .accessibilityLabel(String(localized: "Zoom"))
                Image(systemName: "plus.magnifyingglass").font(.footnote).foregroundStyle(.secondary)
                GlassIconButton(symbol: "arrow.counterclockwise", label: String(localized: "Reset zoom, position, rotation and flip"), size: 30) {
                    withAnimation(.smooth) { store.resetOverlayView(o.id) }
                }
            }
        }
    }

    private func frameTools(_ o: PhotoOverlay) -> some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(PhotoFrame.allCases) { f in
                            ChipButton(title: f.title, symbol: f.symbol, isOn: f == o.frame) {
                                withAnimation(.smooth) {
                                    store.updateOverlay(o.id) {
                                        if let c = f.startColor, $0.frame != f { $0.frameColor = c }
                                        else if f.startColor == nil, let old = $0.frame.startColor, $0.frameColor == old { $0.frameColor = "#ffffff" }
                                        $0.frame = f
                                    }
                                }
                            }
                            .accessibilityAddTraits(f == o.frame ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .scrollClipDisabled()
            if o.frame.usesColor {
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
                        .accessibilityLabel(String(localized: "Frame color \(c)"))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                    ColorPicker(String(localized: "Custom frame color"), selection: Binding(
                        get: { Color(hex: o.frameColor) },
                        set: { v in store.updateOverlay(o.id) { $0.frameColor = v.hexString } }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    Spacer(minLength: 0)
                }
                .padding(.leading, 4)
            } else {
                Text(o.frame == .none ? String(localized: "Pick a frame to give this photo an edge.") : String(localized: "This frame has no color to pick."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
            }
        }
    }

    private func sizeTools(_ o: PhotoOverlay) -> some View {
        VStack(spacing: 6) {
            labeledSlider(String(localized: "Size"), symbol: "arrow.up.left.and.arrow.down.right",
                          value: Binding(get: { o.w }, set: { v in store.updateOverlay(o.id) { $0.w = v } }),
                          range: overlayWidthRange)
            labeledSlider(String(localized: "Tilt"), symbol: "rotate.right",
                          value: Binding(
                              get: { clamp(o.tilt, -45, 45) },
                              // level holds on a little, so a straight photo is easy to get back
                              set: { v in store.updateOverlay(o.id) { $0.tilt = abs(v) < 1.5 ? 0 : v } }
                          ),
                          range: -45...45)
        }
    }

    private func labeledSlider(_ title: String, symbol: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 66, alignment: .leading)
            Slider(value: value, in: range)
                .accessibilityLabel(title)
        }
    }

    private func layerTools(_ o: PhotoOverlay) -> some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                CompactTool(title: String(localized: "Forward"), symbol: "square.2.layers.3d.top.filled") {
                    withAnimation(.smooth) { store.restackOverlay(o.id, up: true) }
                }
                CompactTool(title: String(localized: "Back"), symbol: "square.2.layers.3d.bottom.filled") {
                    withAnimation(.smooth) { store.restackOverlay(o.id, up: false) }
                }
                CompactTool(title: String(localized: "Duplicate"), symbol: "plus.square.on.square") {
                    withAnimation(.smooth) { store.duplicateOverlay(o.id) }
                }
                CompactTool(title: String(localized: "Delete"), symbol: "trash", role: .destructive) {
                    withAnimation(.smooth) { store.removeOverlay(o.id) }
                }
            }
        }
    }
}

/// Picture tools → Look: a filter (each swatch is this photo in that filter), then one fine adjustment at a time.
struct PhotoLookTools: View {
    @Environment(CollageStore.self) private var store
    let sel: Int
    let cell: CellState
    let item: MediaItem
    let done: () -> Void
    @State private var adjusting: Adjustment = .light

    enum Adjustment: String, CaseIterable, Identifiable {
        case light, contrast, colour, warmth
        var id: String { rawValue }
        var title: String {
            switch self {
            case .light: String(localized: "Light")
            case .contrast: String(localized: "Contrast")
            case .colour: String(localized: "Color")
            case .warmth: String(localized: "Warmth")
            }
        }
        var keyPath: WritableKeyPath<PhotoLook, Double> {
            switch self {
            case .light: \.brightness
            case .contrast: \.contrast
            case .colour: \.saturation
            case .warmth: \.warmth
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PhotoFilter.allCases) { f in
                        let on = cell.look.filter == f
                        Button {
                            withAnimation(.smooth(duration: 0.2)) { store.setCellLook(sel) { $0.filter = f } }
                        } label: {
                            VStack(spacing: 3) {
                                Image(uiImage: PhotoLookRenderer.apply(item.thumbnail, PhotoLook(filter: f), key: "thumb-\(item.id)"))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.brand, lineWidth: on ? 2.5 : 0).padding(-3))
                                Text(f.title)
                                    .font(.system(size: 9.5, weight: on ? .semibold : .regular))
                                    .foregroundStyle(on ? .primary : .secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 50)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "\(f.title) filter"))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 3)
                .padding(.top, 3)
            }
            .frame(height: 56)
            Picker(String(localized: "Adjust"), selection: $adjusting) {
                ForEach(Adjustment.allCases) { a in Text(a.title).tag(a) }
            }
            .pickerStyle(.segmented)
            .frame(height: 30)
            HStack(spacing: 8) {
                Slider(value: Binding(
                    get: { cell.look[keyPath: adjusting.keyPath] },
                    set: { v in store.setCellLook(sel) { $0[keyPath: adjusting.keyPath] = abs(v) < 0.04 ? 0 : v } }
                ), in: -1...1)
                .accessibilityLabel(adjusting.title)
                Text(String(localized: "\(Int((cell.look[keyPath: adjusting.keyPath] * 100).rounded()))"))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
                GlassIconButton(symbol: "arrow.counterclockwise", label: String(localized: "Back to the original photo"), size: 30) {
                    withAnimation(.smooth) { store.setCellLook(sel) { $0 = PhotoLook() } }
                }
                GlassIconButton(symbol: "checkmark", label: String(localized: "Done"), size: 30, action: done)
            }
            .frame(height: 30)
        }
        .sensoryFeedback(.selection, trigger: cell.look.filter)
    }
}
