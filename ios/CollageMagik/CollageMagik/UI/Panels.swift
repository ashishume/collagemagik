import SwiftUI

// MARK: - Media

struct MediaPanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        let placed = Set(store.project.cells.compactMap(\.mediaId))
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(store.items.count) of \(maxCells)  ·  \(store.videoCount) of \(maxVideos) videos")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
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
            VStack(spacing: 2) {
                Image(systemName: "plus").font(.title3.weight(.semibold))
                Text("Add").font(.caption2.weight(.medium))
            }
            .frame(width: 58, height: 58)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .glassEffect(.regular.tint(Color.brand.opacity(0.55)).interactive(), in: .rect(cornerRadius: 14))
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
                        Text("Not used").font(.system(size: 9, weight: .semibold))
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
        VStack(spacing: 2) {
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
            .frame(width: 28, height: 44)
            Text(layout.name)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
                .frame(width: 52)
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
        let options = layouts(for: store.project.cellCount)
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("Cells").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer(spacing: 6) {
                        HStack(spacing: 6) {
                            ForEach(1...maxCells, id: \.self) { n in
                                let on = store.project.cellCount == n
                                Button { withAnimation(.smooth) { store.setCellCount(n) } } label: {
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
                GlassIconButton(symbol: "shuffle", label: "Try another layout", size: 30) {
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
        VStack(spacing: 6) {
            Picker("Format", selection: $store.project.format) {
                ForEach(FormatId.allCases) { f in Text(f.label).tag(f) }
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
