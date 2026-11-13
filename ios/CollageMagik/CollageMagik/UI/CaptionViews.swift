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
                            .accessibilityLabel("\(f.label) lettering")
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
                        .accessibilityLabel("Caption colour \(c)")
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(5)
            }
            ColorPicker("Custom caption colour", selection: Binding(
                get: { Color(hex: selection) },
                set: { pick($0.hexString) }
            ), supportsOpacity: false)
            .labelsHidden()
        }
    }
}

/// Shadow, Label, Plate or Outline.
struct CaptionLookPicker: View {
    let selection: CaptionLook
    let pick: (CaptionLook) -> Void

    var body: some View {
        Picker("Caption background", selection: Binding(get: { selection }, set: pick)) {
            ForEach(CaptionLook.allCases) { l in Text(l.title).tag(l) }
        }
        .pickerStyle(.segmented)
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
                            GlassIconButton(symbol: o.symbol, label: "Decoration: \(o.title)", isOn: caption.ornament == o, size: 30) {
                                update { $0.ornament = o }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            Menu {
                Picker("Two sizes", selection: Binding(get: { caption.mix }, set: { m in update { $0.mix = m } })) {
                    ForEach(CaptionMix.allCases) { m in Text(m.title).tag(m) }
                }
                Picker("Small lines lettering", selection: Binding(get: { caption.accentFont }, set: { f in update { $0.accentFont = f } })) {
                    ForEach(CaptionFont.allCases) { f in Text(f.label).tag(f) }
                }
                .pickerStyle(.menu)
            } label: {
                Label("Mix: \(caption.mix.short)", systemImage: "textformat.size")
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .glassEffect(caption.mix == .none ? .regular.interactive() : .regular.tint(Color.brand.opacity(0.7)).interactive(), in: .capsule)
            }
            .accessibilityHint("Makes the first or last line small, in its own lettering. Put each part on its own line.")
        }
    }
}

// MARK: - Text tab

struct TextPanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        if let c = store.caption(store.selectedCaption) {
            styling(c)
        } else {
            overview
        }
    }

    /// Nothing selected: add a caption, or pick one that is already there.
    private var overview: some View {
        let captions = store.project.captions.filter { !$0.text.isEmpty }
        return VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button { store.addCaption() } label: {
                        Label("Add caption", systemImage: "plus").font(.footnote.weight(.semibold))
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
                        .accessibilityLabel("Caption: \(c.text)")
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
            HintRow(
                symbol: "hand.draw",
                text: captions.isEmpty
                    ? "Write on your \(store.isCarousel ? "carousel" : "collage") in \(CaptionFont.allCases.count) lettering styles."
                    : "Tap a caption to style it. Drag, pinch or twist to place it."
            )
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    private func styling(_ c: Caption) -> some View {
        VStack(spacing: 7) {
            CaptionFontStrip(selection: c.font) { f in store.updateCaption(c.id) { $0.font = f } }
            CaptionColorStrip(selection: c.color) { hex in store.updateCaption(c.id) { $0.color = hex } }
            CaptionExtrasRow(caption: c) { patch in store.updateCaption(c.id, patch) }
            HStack(spacing: 8) {
                CaptionLookPicker(selection: c.look) { l in store.updateCaption(c.id) { $0.look = l } }
                GlassIconButton(symbol: c.align.symbol, label: "Line up the words: \(c.align.rawValue)", size: 30) {
                    store.updateCaption(c.id) { $0.align = $0.align.next }
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "textformat.size.smaller").font(.footnote).foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { c.size },
                    set: { v in store.updateCaption(c.id) { $0.size = v } }
                ), in: captionSizeRange)
                .accessibilityLabel("Caption size")
                Image(systemName: "textformat.size.larger").font(.footnote).foregroundStyle(.secondary)
                GlassIconButton(symbol: "pencil", label: "Change the words", size: 30) { store.editingCaption = c.id }
                GlassIconButton(symbol: "plus.square.on.square", label: "Duplicate caption", size: 30) {
                    withAnimation(.smooth) { store.duplicateCaption(c.id) }
                }
                Button(role: .destructive) {
                    withAnimation(.smooth) { store.removeCaption(c.id) }
                } label: {
                    Image(systemName: "trash").font(.system(size: 12.5, weight: .semibold)).frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .tint(.red)
                .accessibilityLabel("Delete caption")
                Button { store.selectCaption(nil) } label: {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).frame(width: 30, height: 30)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .accessibilityLabel("Done")
            }
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
                    GlassIconButton(symbol: c.align.symbol, label: "Line up the words: \(c.align.rawValue)", size: 40) {
                        store.updateCaption(id) { $0.align = $0.align.next }
                    }
                    Spacer()
                    Text("\(c.text.count)/\(maxCaptionLength)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .opacity(c.text.count > maxCaptionLength - 30 ? 1 : 0)
                    Button("Done") { store.finishEditingCaption() }
                        .font(.headline)
                        .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 0)

                TextField("Type your caption", text: Binding(
                    get: { c.text },
                    set: { v in store.updateCaption(id) { $0.text = v } }
                ), axis: .vertical)
                .font(c.font.font(size: 32))
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
