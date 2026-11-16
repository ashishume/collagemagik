import SwiftUI

/// The Text tab's sticker groups: tap an emoji or shape to lay it on the design.
struct StickerGrid: View {
    @Environment(CollageStore.self) private var store
    let group: StickerGroup

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: [GridItem(.fixed(42), spacing: 6), GridItem(.fixed(42), spacing: 6)], spacing: 6) {
                ForEach(group.items, id: \.self) { item in
                    Button {
                        withAnimation(.smooth) { store.addSticker(item, kind: group.kind) }
                    } label: {
                        Group {
                            if group.kind == .emoji {
                                Text(item).font(.system(size: 28))
                            } else {
                                Image(systemName: item).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                            }
                        }
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(group.kind == .emoji ? "Add \(item)" : "Add shape \(item)")
                }
            }
            .padding(.horizontal, 2)
        }
        .id(group) // a new group starts at its first item
    }
}

/// Tabs on the Text tab while nothing is selected: captions, then the sticker groups.
enum TextHomeSection: String, PanelSection {
    case text, faces, love, fun, shapes
    var id: String { rawValue }
    var stickerGroup: StickerGroup? { StickerGroup(rawValue: rawValue) }
    var title: String { stickerGroup?.title ?? "Text" }
    var symbol: String { stickerGroup?.symbol ?? "textformat" }
}

/// The selected sticker's tools: size and tilt, colour, layer.
struct StickerTools: View {
    @Environment(CollageStore.self) private var store
    @State private var section: StickerSection = .size

    var body: some View {
        if let st = store.sticker(store.selectedSticker) {
            SectionedPanel(section: $section, done: { withAnimation(.smooth) { store.selectSticker(nil) } }) { s in
                switch s {
                case .size: sizeTools(st)
                case .colour: colourTools(st)
                case .layer: layerTools(st)
                }
            }
        }
    }

    // MARK: Selected sticker

    private func sizeTools(_ st: Sticker) -> some View {
        VStack(spacing: 6) {
            slider("Size", symbol: "arrow.up.left.and.arrow.down.right",
                   value: Binding(get: { st.w }, set: { v in store.updateSticker(st.id) { $0.w = v } }),
                   range: stickerSizeRange)
            slider("Tilt", symbol: "rotate.right",
                   value: Binding(
                       get: { clamp(st.tilt, -180, 180) },
                       set: { v in store.updateSticker(st.id) { $0.tilt = abs(v) < 2 ? 0 : v } }
                   ),
                   range: -180...180)
        }
    }

    @ViewBuilder
    private func colourTools(_ st: Sticker) -> some View {
        if st.kind == .shape {
            HStack(spacing: 9) {
                ForEach(stickerSwatches, id: \.self) { c in
                    let on = st.color.lowercased() == c
                    Button { store.updateSticker(st.id) { $0.color = c } } label: {
                        Circle().fill(Color(hex: c))
                            .frame(width: 24, height: 24)
                            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                            .overlay(Circle().strokeBorder(Color.brand, lineWidth: on ? 3 : 0).padding(-4))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Colour \(c)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
                ColorPicker("Custom colour", selection: Binding(
                    get: { Color(hex: st.color) },
                    set: { v in store.updateSticker(st.id) { $0.color = v.hexString } }
                ), supportsOpacity: false)
                .labelsHidden()
                Spacer(minLength: 0)
            }
            .padding(.leading, 4)
        } else {
            Text("Emoji keep their own colours. Shapes can take any colour.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
        }
    }

    private func layerTools(_ st: Sticker) -> some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                CompactTool(title: "Flip", symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right", isOn: st.flip) {
                    withAnimation(.smooth) { store.updateSticker(st.id) { $0.flip.toggle() } }
                }
                CompactTool(title: "Forward", symbol: "square.2.layers.3d.top.filled") {
                    withAnimation(.smooth) { store.restackSticker(st.id, up: true) }
                }
                CompactTool(title: "Copy", symbol: "plus.square.on.square") {
                    withAnimation(.smooth) { store.duplicateSticker(st.id) }
                }
                CompactTool(title: "Delete", symbol: "trash", role: .destructive) {
                    withAnimation(.smooth) { store.removeSticker(st.id) }
                }
            }
        }
    }

    private func slider(_ title: String, symbol: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 66, alignment: .leading)
            Slider(value: value, in: range)
                .accessibilityLabel(title)
        }
    }
}

enum StickerSection: String, PanelSection {
    case size, colour, layer
    var id: String { rawValue }
    var title: String {
        switch self {
        case .size: "Size"
        case .colour: "Colour"
        case .layer: "Layer"
        }
    }
    var symbol: String {
        switch self {
        case .size: "arrow.up.left.and.arrow.down.right"
        case .colour: "paintpalette"
        case .layer: "square.3.layers.3d"
        }
    }
}

// MARK: - Background picker (Style tab)

/// Colour / Gradient / Blur / Pattern, then the choices for that kind.
struct BackdropPicker: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        let b = store.project.backdrop
        VStack(spacing: 6) {
            Picker("Background", selection: Binding(
                get: { b.kind },
                set: { k in withAnimation(.smooth) { setKind(k) } }
            )) {
                ForEach(BackdropKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            switch b.kind {
            case .color, .pattern:
                VStack(spacing: 4) {
                    if b.kind == .pattern { patternRow(b) }
                    colourRow
                }
            case .gradient:
                gradientRow(b)
            case .blur:
                blurRow(b)
            }
        }
    }

    private func setKind(_ k: BackdropKind) {
        store.project.backdrop.kind = k
        if k == .blur && BackdropRenderer.blurSource(store.project) == nil {
            store.notify("Add a photo first: the blur is made from one of your pictures.")
        }
    }

    private var colourRow: some View {
        HStack(spacing: 10) {
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
    }

    private func gradientRow(_ b: Backdrop) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(gradientPresets.indices, id: \.self) { i in
                    let g = gradientPresets[i]
                    let on = b.gradient == i
                    Button { store.project.backdrop.gradient = i } label: {
                        swatch(on: on) {
                            if g.angle == nil {
                                RadialGradient(colors: g.colors.map { Color(hex: $0) }, center: .center, startRadius: 0, endRadius: 26)
                            } else {
                                LinearGradient(colors: g.colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Gradient \(g.name)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(5)
        }
    }

    private func patternRow(_ b: Backdrop) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(BackdropPattern.allCases) { p in
                    let on = b.pattern == p.rawValue
                    Button { store.project.backdrop.pattern = p.rawValue } label: {
                        Text(p.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(on ? .white : .white.opacity(0.75))
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(on ? Color.brand : .white.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
        }
    }

    /// Which picture is blurred: any picture in the tray.
    @ViewBuilder
    private func blurRow(_ b: Backdrop) -> some View {
        let source = BackdropRenderer.blurSource(store.project)
        if store.items.isEmpty {
            Text("Add a photo first: the blur is made from one of your pictures.")
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 44)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.items) { item in
                        let on = source == item.id
                        Button { store.project.backdrop.blurMediaId = item.id } label: {
                            swatch(on: on) {
                                Image(uiImage: item.thumbnail).resizable().scaledToFill().blur(radius: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Blur \(item.name)")
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(5)
            }
        }
    }

    private func swatch<C: View>(on: Bool, @ViewBuilder content: () -> C) -> some View {
        content()
            .frame(width: 34, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.brand, lineWidth: on ? 3 : 0).padding(-4))
    }
}
