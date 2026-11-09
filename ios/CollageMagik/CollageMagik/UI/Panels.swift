import SwiftUI

// MARK: - Media

struct MediaPanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        let placed = Set(store.project.cells.compactMap(\.mediaId))
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(store.items.count) of \(maxCells)  ·  \(store.videoCount) of \(maxVideos) videos")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if store.importing { ProgressView().controlSize(.small) }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        addTile
                        ForEach(store.items) { m in
                            thumb(m, used: placed.contains(m.id))
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .scrollClipDisabled()
        }
    }

    private var addTile: some View {
        Menu {
            Button { store.openAdd() } label: { Label("Photo Library", systemImage: "photo.on.rectangle") }
            Button { store.openFiles() } label: { Label("Files", systemImage: "folder") }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus").font(.title2.weight(.semibold))
                Text("Add").font(.caption.weight(.medium))
            }
            .frame(width: 72, height: 72)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .glassEffect(.regular.tint(Color.brand.opacity(0.55)).interactive(), in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(store.importing || store.items.count >= maxCells)
        .accessibilityLabel("Add photos or videos")
    }

    private func thumb(_ m: MediaItem, used: Bool) -> some View {
        Button {
            store.placeMedia(m.id, cell: store.selectedCell)
        } label: {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: m.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(used ? Color.brand : .white.opacity(0.15), lineWidth: used ? 2.5 : 1)
                    }
                HStack(spacing: 3) {
                    if m.kind == .video {
                        Image(systemName: "film").font(.system(size: 9, weight: .bold))
                        Text(formatTime(m.duration)).font(.system(size: 10, weight: .semibold).monospacedDigit())
                    } else if !used {
                        Text("Not used").font(.system(size: 9, weight: .semibold))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.55), in: Capsule())
                .opacity(m.kind == .video || !used ? 1 : 0)
                .padding(5)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { store.placeMedia(m.id, cell: store.selectedCell) } label: { Label("Use in selected cell", systemImage: "square.and.arrow.down") }
            Button(role: .destructive) { withAnimation(.smooth) { store.removeMedia(m.id) } } label: { Label("Remove", systemImage: "trash") }
        }
        .accessibilityLabel("\(m.kind == .video ? "Video" : "Photo") \(m.name). \(used ? "In the collage" : "Tap to add to the selected cell")")
    }
}

// MARK: - Layout

struct LayoutThumb: View {
    let layout: CollageLayout
    let isOn: Bool

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(Array(layout.rects.enumerated()), id: \.offset) { _, r in
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(isOn ? Color.white : Color.white.opacity(0.55))
                            .frame(width: max(2, geo.size.width * (r.w - 0.045)), height: max(2, geo.size.height * (r.h - 0.03)))
                            .offset(x: geo.size.width * (r.x + 0.0225), y: geo.size.height * (r.y + 0.015))
                    }
                }
            }
            .frame(width: 38, height: 58)
            Text(layout.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .frame(width: 62)
                .foregroundStyle(isOn ? .primary : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .glassEffect(isOn ? .regular.tint(Color.brand.opacity(0.7)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 16))
    }
}

struct LayoutPanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        let options = layouts(for: store.project.cellCount)
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("Cells").font(.footnote.weight(.medium)).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer(spacing: 6) {
                        HStack(spacing: 6) {
                            ForEach(1...maxCells, id: \.self) { n in
                                let on = store.project.cellCount == n
                                Button { withAnimation(.smooth) { store.setCellCount(n) } } label: {
                                    Text("\(n)")
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                        .frame(width: 34, height: 34)
                                        .glassEffect(on ? .regular.tint(Color.brand.opacity(0.8)).interactive() : .regular.interactive(), in: .circle)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(n) cells")
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                }
                GlassIconButton(symbol: "shuffle", label: "Try another layout", size: 36) {
                    withAnimation(.smooth) { store.shuffleLayout() }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(options) { l in
                            Button { withAnimation(.smooth) { store.setLayout(l.id) } } label: {
                                LayoutThumb(layout: l, isOn: l.id == store.project.layoutId)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(l.name)
                            .accessibilityAddTraits(l.id == store.project.layoutId ? .isSelected : [])
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
        .sensoryFeedback(.selection, trigger: store.project.layoutId)
    }
}

// MARK: - Style

struct StylePanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 10) {
            Picker("Format", selection: $store.project.format) {
                ForEach(FormatId.allCases) { f in Text(f.label).tag(f) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 18) {
                compactSlider("Gap", value: $store.project.gap, range: 0...48)
                compactSlider("Corners", value: $store.project.radius, range: 0...80)
            }

            HStack(spacing: 10) {
                Text("Colour")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(backgroundSwatches, id: \.self) { c in
                            let on = store.project.bg.lowercased() == c
                            Button { store.project.bg = c } label: {
                                Circle().fill(Color(hex: c))
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                                    .overlay(Circle().strokeBorder(Color.brand, lineWidth: on ? 3 : 0).padding(-4))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Background \(c)")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(6)
                }
                ColorPicker("Custom colour", selection: Binding(
                    get: { Color(hex: store.project.bg) },
                    set: { store.project.bg = $0.hexString }
                ), supportsOpacity: false)
                .labelsHidden()
            }

            if store.project.format == .story {
                Toggle(isOn: $store.project.safeZone) {
                    Label("Show the area Instagram covers", systemImage: store.project.safeZone ? "eye.slash" : "eye")
                        .font(.subheadline)
                }
            }
        }
    }
}

extension StylePanel {
    func compactSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 10) {
            if lanes.isEmpty {
                ContentUnavailableView {
                    Label("No video yet", systemImage: "waveform.slash")
                } description: {
                    Text("Add a video to control its sound and to add background music.")
                }
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
        return HStack(spacing: 10) {
            Text(name)
                .font(.footnote.weight(.bold))
                .frame(width: 26, height: 26)
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
                Text("No sound in this video").font(.subheadline).foregroundStyle(.secondary)
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
            HStack(spacing: 10) {
                Image(systemName: "music.note").foregroundStyle(Color.musicGreen).frame(width: 26)
                Text(music.name).font(.subheadline.weight(.medium)).lineLimit(1)
                Spacer()
                Button(role: .destructive) { store.removeMusic() } label: { Image(systemName: "trash") }
                    .buttonStyle(.glass).buttonBorderShape(.circle)
                    .accessibilityLabel("Remove music")
            }
            HStack(spacing: 10) {
                Text("Volume").font(.subheadline).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
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
            .font(.subheadline)
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
                    Label("Tap another cell in the preview to swap with it.", systemImage: "arrow.left.arrow.right")
                        .font(.subheadline)
                    Spacer()
                    ChipButton(title: "Cancel", symbol: "xmark") { withAnimation { store.swapFrom = nil } }
                }
            } else {
                VStack(spacing: 10) {
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            ChipButton(title: filled ? "Replace" : "Add photo or video", symbol: "photo.badge.plus") {
                                store.openAdd(cell: sel)
                            }
                            if filled {
                                ChipButton(title: "Swap", symbol: "arrow.left.arrow.right") {
                                    withAnimation { store.swapFrom = sel }
                                }
                                ChipButton(title: "Remove", symbol: "xmark", role: .destructive) { store.clearCell(sel) }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    if filled {
                        GlassEffectContainer(spacing: 8) {
                            HStack(spacing: 8) {
                                ChipButton(title: "Rotate", symbol: "rotate.right") { withAnimation(.smooth) { store.rotateCell(sel) } }
                                ChipButton(title: "Flip", symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right", isOn: cell.flip) {
                                    withAnimation(.smooth) { store.flipCell(sel) }
                                }
                                ChipButton(title: "Crop", symbol: "crop") { store.cropCell = sel }
                                Spacer(minLength: 0)
                            }
                        }
                        HStack(spacing: 10) {
                            Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
                            Slider(value: Binding(
                                get: { cell.zoom },
                                set: { v in store.setCellView(sel) { $0.zoom = v } }
                            ), in: 1...4)
                            .accessibilityLabel("Zoom")
                            Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
                            GlassIconButton(symbol: "arrow.counterclockwise", label: "Reset zoom, position, rotation and flip", size: 34) {
                                withAnimation(.smooth) { store.resetCell(sel) }
                            }
                        }
                    }
                    Button { store.selectCell(nil) } label: {
                        Label("Done", systemImage: "checkmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        } else {
            ContentUnavailableView {
                Label("Pick a picture", systemImage: "hand.tap")
            } description: {
                Text("Tap a picture in the preview to replace, swap, rotate, flip, crop and zoom it.")
            }
        }
    }
}
