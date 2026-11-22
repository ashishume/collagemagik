import SwiftUI

struct CaptionTarget: Identifiable {
    let id: String
}

extension CaptionFont {
    func font(size: Double) -> Font { Font(uiFont(size: size) as CTFont) }
}

// MARK: - Pickers shared by the Text tab and the typing screen

/// The lettering styles, each shown in its own typeface.
struct CaptionFontStrip: View {
    let selection: CaptionFont
    let pick: (CaptionFont) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(CaptionFont.allCases) { f in
                            let on = f == selection
                            Button { pick(f) } label: {
                                VStack(spacing: 0) {
                                    Text("Aa")
                                        .font(f.font(size: 19))
                                        .lineLimit(1)
                                        .frame(height: 26)
                                    Text(f.label)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(on ? .primary : .secondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 58, height: 44)
                                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .glassEffect(on ? .regular.tint(Color.brand.opacity(0.7)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 13))
                            }
                            .buttonStyle(.plain)
                            .id(f)
                            .accessibilityLabel(String(localized: "\(f.label) lettering"))
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .scrollClipDisabled()
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct CaptionColorStrip: View {
    let selection: String
    let pick: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(captionSwatches, id: \.self) { c in
                        let on = selection.lowercased() == c
                        Button { pick(c) } label: {
                            Circle().fill(Color(hex: c))
                                .frame(width: 24, height: 24)
                                .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                                .overlay(Circle().strokeBorder(Color.brand, lineWidth: on ? 3 : 0).padding(-4))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "Caption color \(c)"))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(5)
            }
            ColorPicker(String(localized: "Custom caption color"), selection: Binding(
                get: { Color(hex: selection) },
                set: { pick($0.hexString) }
            ), supportsOpacity: false)
            .labelsHidden()
        }
    }
}

/// Bold, italic, underline, strikethrough and all caps, plus how the lines line up.
struct CaptionFormatRow: View {
    let caption: Caption
    var size: CGFloat = 30
    let update: ((inout Caption) -> Void) -> Void

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(CaptionFormat.allCases) { f in
                    let on = caption[keyPath: f.keyPath]
                    GlassIconButton(symbol: f.symbol, label: f.title, isOn: on, size: size) {
                        update { $0[keyPath: f.keyPath].toggle() }
                    }
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
                GlassIconButton(symbol: caption.align.symbol, label: String(localized: "Line up the words: \(caption.align.title)"), size: size) {
                    update { $0.align = $0.align.next }
                }
                Spacer(minLength: 0)
            }
        }
        .sensoryFeedback(.selection, trigger: [caption.bold, caption.italic, caption.underline, caption.strikethrough, caption.allCaps, caption.vertical])
    }
}

/// Shadow, Label, Plate, Outline, Neon, Sticker or Gradient: a row of chips that scrolls sideways.
struct CaptionLookPicker: View {
    let selection: CaptionLook
    let pick: (CaptionLook) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(CaptionLook.allCases) { l in
                        ChipButton(title: l.title, symbol: l.symbol, isOn: l == selection) {
                            withAnimation(.smooth(duration: 0.2)) { pick(l) }
                        }
                        .accessibilityAddTraits(l == selection ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .scrollClipDisabled()
        .frame(height: 32)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Decorations (heart, divider, sparkles, swash) and the "two sizes" mix, in one row.
struct CaptionExtrasRow: View {
    let caption: Caption
    let update: ((inout Caption) -> Void) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(CaptionOrnament.allCases) { o in
                            GlassIconButton(symbol: o.symbol, label: String(localized: "Decoration: \(o.title)"), isOn: caption.ornament == o, size: 30) {
                                update { $0.ornament = o }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            Menu {
                Picker(String(localized: "Two sizes"), selection: Binding(get: { caption.mix }, set: { m in update { $0.mix = m } })) {
                    ForEach(CaptionMix.allCases) { m in Text(m.title).tag(m) }
                }
                Picker(String(localized: "Small lines lettering"), selection: Binding(get: { caption.accentFont }, set: { f in update { $0.accentFont = f } })) {
                    ForEach(CaptionFont.allCases) { f in Text(f.label).tag(f) }
                }
                .pickerStyle(.menu)
            } label: {
                Label(String(localized: "Mix: \(caption.mix.short)"), systemImage: "textformat.size")
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .glassEffect(caption.mix == .none ? .regular.interactive() : .regular.tint(Color.brand.opacity(0.7)).interactive(), in: .capsule)
            }
            .accessibilityHint(String(localized: "Makes the first or last line small, in its own lettering. Put each part on its own line."))
        }
    }
}

// MARK: - Text tab

struct TextPanel: View {
    @Environment(CollageStore.self) private var store
    @State private var section: CaptionSection = .font

    /// Kept across selections, so after placing a sticker the same group is still open.
    @AppStorage("cm.text.home") private var home: TextHomeSection = .text

    var body: some View {
        if let c = store.caption(store.selectedCaption) {
            styling(c)
        } else if store.sticker(store.selectedSticker) != nil {
            StickerTools()
        } else {
            // nothing selected: captions and the sticker groups, one tab each
            VStack(spacing: 8) {
                SectionTabs(selection: $home)
                    .frame(height: panelTabsHeight)
                Group {
                    if let group = home.stickerGroup {
                        StickerGrid(group: group)
                    } else {
                        overview.frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .frame(height: panelSectionHeight)
            }
            .animation(.smooth(duration: 0.25), value: home)
        }
    }

    /// Nothing selected: add a caption, or pick one that is already there.
    private var overview: some View {
        let captions = store.project.captions.filter { !$0.text.isEmpty }
        return VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button { store.addCaption() } label: {
                        Label(String(localized: "Add caption"), systemImage: "plus").font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                    ForEach(captions) { c in
                        Button { store.selectCaption(c.id) } label: {
                            Text(c.text.replacingOccurrences(of: "\n", with: " "))
                                .font(c.font.font(size: 14))
                                .lineLimit(1)
                                .frame(maxWidth: 120)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .accessibilityLabel(String(localized: "Caption: \(c.text)"))
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
            HintRow(
                symbol: "hand.draw",
                text: captions.isEmpty
                    ? String(localized: "Write on your design in \(CaptionFont.allCases.count) lettering styles.")
                    : String(localized: "Tap a caption to style it. Drag, pinch or twist to place it.")
            )
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    private func styling(_ c: Caption) -> some View {
        SectionedPanel(section: $section, done: { store.selectCaption(nil) }) { s in
            switch s {
            case .font:
                VStack(spacing: 8) {
                    CaptionFontStrip(selection: c.font) { f in store.updateCaption(c.id) { $0.font = f } }
                    HStack(spacing: 8) {
                        Image(systemName: "textformat.size.smaller").font(.footnote).foregroundStyle(.secondary)
                        Slider(value: Binding(
                            get: { c.size },
                            set: { v in store.updateCaption(c.id) { $0.size = v } }
                        ), in: captionSizeRange)
                        .accessibilityLabel(String(localized: "Caption size"))
                        Image(systemName: "textformat.size.larger").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            case .colour:
                VStack(spacing: 10) {
                    CaptionColorStrip(selection: c.color) { hex in store.updateCaption(c.id) { $0.color = hex } }
                    CaptionLookPicker(selection: c.look) { l in store.updateCaption(c.id) { $0.look = l } }
                }
            case .style:
                VStack(spacing: 10) {
                    CaptionFormatRow(caption: c) { patch in store.updateCaption(c.id, patch) }
                    CaptionExtrasRow(caption: c) { patch in store.updateCaption(c.id, patch) }
                }
            case .edit:
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        CompactTool(title: String(localized: "Edit words"), symbol: "pencil") { store.editingCaption = c.id }
                        CompactTool(title: String(localized: "Duplicate"), symbol: "plus.square.on.square") {
                            withAnimation(.smooth) { store.duplicateCaption(c.id) }
                        }
                        CompactTool(title: String(localized: "Delete"), symbol: "trash", role: .destructive) {
                            withAnimation(.smooth) { store.removeCaption(c.id) }
                        }
                    }
                }
            }
        }
    }
}

/// The groups a selected caption's tools are sorted into.
enum CaptionSection: String, PanelSection {
    case font, colour, style, edit
    var id: String { rawValue }
    var title: String {
        switch self {
        case .font: String(localized: "Font")
        case .colour: String(localized: "Color")
        case .style: String(localized: "Style")
        case .edit: String(localized: "Edit")
        }
    }
    var symbol: String {
        switch self {
        case .font: "textformat"
        case .colour: "paintpalette"
        case .style: "bold.italic.underline"
        case .edit: "pencil"
        }
    }
}

// MARK: - Typing screen

/// Typing a caption: the words sit in the middle of the screen in their own lettering, over the blurred collage,
/// with the styles just above the keyboard.
struct CaptionEditor: View {
    let id: String
    @Environment(CollageStore.self) private var store
    @FocusState private var focused: Bool

    var body: some View {
        let c = store.caption(id) ?? Caption(id: id)
        let base = UIColor(hex: c.color)
        let boxed = c.look == .label || c.look == .plate
        let letters: Color = c.look == .label ? (base.isLight ? Color(hex: "#101016") : .white) : Color(hex: c.color)
        let plate: Color = switch c.look {
        case .label: Color(hex: c.color)
        case .plate: base.isLight ? .black.opacity(0.5) : .white.opacity(0.72)
        // dark letters would vanish on the dimmed screen: give them a pale card to sit on
        default: base.brightness > 0.35 ? .clear : .white.opacity(0.6)
        }

        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { store.finishEditingCaption() }

            VStack(spacing: 10) {
                HStack {
                    CaptionFormatRow(caption: c, size: 32) { patch in store.updateCaption(id, patch) }
                    Spacer()
                    Text(String(localized: "\(c.text.count)/\(maxCaptionLength)"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .opacity(c.text.count > maxCaptionLength - 30 ? 1 : 0)
                    Button(String(localized: "Done")) { store.finishEditingCaption() }
                        .font(.headline)
                        .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 0)

                TextField(String(localized: "Type your caption"), text: Binding(
                    get: { c.text },
                    set: { v in store.updateCaption(id) { $0.text = v } }
                ), axis: .vertical)
                .font(c.font.font(size: 32))
                .bold(c.bold)
                .italic(c.italic)
                .underline(c.underline)
                .strikethrough(c.strikethrough)
                .textCase(c.allCaps ? .uppercase : nil)
                .multilineTextAlignment(c.align.swiftUI)
                .foregroundStyle(letters)
                .tint(letters)
                .lineLimit(1...6)
                .focused($focused)
                .autocorrectionDisabled(false)
                .padding(.horizontal, boxed ? 16 : 8)
                .padding(.vertical, boxed ? 9 : 6)
                .background(plate, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: !boxed && base.brightness > 0.35 ? .black.opacity(0.55) : .clear, radius: 5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 26)
                .animation(.smooth(duration: 0.2), value: c.look)

                Spacer(minLength: 0)

                VStack(spacing: 8) {
                    CaptionLookPicker(selection: c.look) { l in store.updateCaption(id) { $0.look = l } }
                    CaptionColorStrip(selection: c.color) { hex in store.updateCaption(id) { $0.color = hex } }
                    CaptionFontStrip(selection: c.font) { f in store.updateCaption(id) { $0.font = f } }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
            .padding(.top, 6)
        }
        .presentationBackground(.ultraThinMaterial)
        .onAppear { focused = true }
    }
}
