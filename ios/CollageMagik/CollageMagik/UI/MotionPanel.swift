import SwiftUI

// MARK: - Names

extension MotionTransition {
    var title: String {
        switch self {
        case .cut: String(localized: "Cut")
        case .fade: String(localized: "Fade")
        case .slideLeft: String(localized: "Slide")
        case .slideUp: String(localized: "Slide up")
        case .zoom: String(localized: "Zoom")
        }
    }
    var symbol: String {
        switch self {
        case .cut: "scissors"
        case .fade: "circle.lefthalf.filled"
        case .slideLeft: "arrow.left.square"
        case .slideUp: "arrow.up.square"
        case .zoom: "plus.magnifyingglass"
        }
    }
}

extension PhotoMove {
    var title: String {
        switch self {
        case .none: String(localized: "Still")
        case .zoomIn: String(localized: "Zoom in")
        case .zoomOut: String(localized: "Zoom out")
        case .drift: String(localized: "Drift")
        }
    }
    var symbol: String {
        switch self {
        case .none: "pause.circle"
        case .zoomIn: "arrow.up.left.and.arrow.down.right"
        case .zoomOut: "arrow.down.right.and.arrow.up.left"
        case .drift: "arrow.left.and.right"
        }
    }
}

extension MotionEntrance {
    var title: String {
        switch self {
        case .none: String(localized: "Together")
        case .pop: String(localized: "Pop")
        case .drop: String(localized: "Drop")
        case .rise: String(localized: "Rise")
        }
    }
    var symbol: String {
        switch self {
        case .none: "square.grid.2x2"
        case .pop: "sparkle"
        case .drop: "arrow.down.to.line"
        case .rise: "arrow.up.to.line"
        }
    }
}

/// The groups of tools for the scene on screen.
enum SceneSection: String, PanelSection {
    case layout, pictures, transition, timing
    var id: String { rawValue }
    var title: String {
        switch self {
        case .layout: String(localized: "Layout")
        case .pictures: String(localized: "Pictures")
        case .transition: String(localized: "Transition")
        case .timing: String(localized: "Timing")
        }
    }
    var symbol: String {
        switch self {
        case .layout: "square.grid.2x2"
        case .pictures: "photo.on.rectangle"
        case .transition: "wand.and.rays"
        case .timing: "timer"
        }
    }
}

// MARK: - Panel

/// The Layout tab of a motion design: its scenes in a row (tap one to see and edit it, + adds one), what to do with
/// the scene on screen, and its layout, pictures, transition and timing.
struct MotionPanel: View {
    @Environment(CollageStore.self) private var store
    @State private var section: SceneSection = .layout
    @State private var templatesOpen = false

    static let stripHeight: CGFloat = 58
    static let actionsHeight: CGFloat = 30
    static var height: CGFloat { stripHeight + actionsHeight + panelTabsHeight + panelSectionHeight + 3 * 6 }

    var body: some View {
        let scenes = store.motionScenes
        let k = min(store.currentScene, max(0, scenes.count - 1))
        VStack(spacing: 6) {
            strip(scenes, current: k)
                .frame(height: Self.stripHeight)
            actions(scenes, current: k)
                .frame(height: Self.actionsHeight)
            SectionTabs(selection: $section)
                .frame(height: panelTabsHeight)
            Group {
                if scenes.indices.contains(k) {
                    switch section {
                    case .layout: layoutTools(scenes[k])
                    case .pictures: pictureTools(scenes[k])
                    case .transition: transitionTools(scenes[k], first: k == 0)
                    case .timing: timingTools(scenes[k])
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: panelSectionHeight, maxHeight: panelSectionHeight, alignment: .top)
        }
        .sheet(isPresented: $templatesOpen) { TemplateBrowserSheet() }
        .sensoryFeedback(.selection, trigger: k)
    }

    // MARK: Scenes

    private func strip(_ scenes: [MotionScene], current k: Int) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(scenes.enumerated()), id: \.offset) { i, s in
                        Button { store.selectScene(i) } label: { sceneChip(s, index: i, isOn: i == k) }
                            .buttonStyle(.plain)
                            .id(i)
                            .accessibilityLabel(String(localized: "Scene \(i + 1), \(String(format: "%.1f", s.length)) seconds"))
                            .accessibilityAddTraits(i == k ? .isSelected : [])
                    }
                    Button { withAnimation(.smooth) { store.addScene() } } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 44, height: 50)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(scenes.count >= maxScenes || store.totalDuration >= maxDuration - minSceneLength)
                    .accessibilityLabel(String(localized: "Add a scene"))
                    .accessibilityHint(String(localized: "Adds a copy of this scene after it"))
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
            .onChange(of: k) { withAnimation(.smooth) { proxy.scrollTo(k, anchor: .center) } }
        }
    }

    private func sceneChip(_ s: MotionScene, index i: Int, isOn: Bool) -> some View {
        let rects = layout(byId: s.layoutId).rects
        return VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(Array(rects.enumerated()), id: \.offset) { _, r in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(isOn ? Color.white : Color.white.opacity(0.5))
                            .frame(width: max(2, geo.size.width * (r.w - 0.06)), height: max(2, geo.size.height * (r.h - 0.04)))
                            .rotationEffect(.degrees(r.tilt))
                            .offset(x: geo.size.width * (r.x + 0.03), y: geo.size.height * (r.y + 0.02))
                    }
                }
            }
            .frame(width: 22, height: 32)
            Text("\(i + 1) · \(String(format: "%.1f", s.length))s")
                .font(.system(size: 9, weight: .semibold).monospacedDigit())
                .foregroundStyle(isOn ? .primary : .secondary)
                .lineLimit(1)
        }
        .frame(width: 52, height: 50)
        .glassEffect(isOn ? .regular.tint(Color.brand.opacity(0.7)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 12))
    }

    private func actions(_ scenes: [MotionScene], current k: Int) -> some View {
        HStack(spacing: 6) {
            Text(String(localized: "Scene \(k + 1) of \(scenes.count)"))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            GlassIconButton(symbol: "chevron.left", label: String(localized: "Move scene earlier"), size: 30) {
                withAnimation(.smooth) { store.moveScene(by: -1) }
            }
            .disabled(k == 0)
            GlassIconButton(symbol: "chevron.right", label: String(localized: "Move scene later"), size: 30) {
                withAnimation(.smooth) { store.moveScene(by: 1) }
            }
            .disabled(k >= scenes.count - 1)
            GlassIconButton(symbol: "trash", label: String(localized: "Delete scene"), size: 30) {
                withAnimation(.smooth) { store.deleteScene() }
            }
            .disabled(scenes.count <= 1)
            Menu {
                Button { store.scaleMotion(1.25) } label: { Label(String(localized: "Slower"), systemImage: "tortoise") }
                Button { store.scaleMotion(0.8) } label: { Label(String(localized: "Faster"), systemImage: "hare") }
                Divider()
                Button { templatesOpen = true } label: { Label(String(localized: "Templates"), systemImage: "sparkles.rectangle.stack") }
                Button { withAnimation(.smooth) { store.makeStill() } } label: {
                    Label(String(localized: "Make it still"), systemImage: "square.grid.2x2")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .accessibilityLabel(String(localized: "More"))
        }
    }

    // MARK: The scene on screen

    private func layoutTools(_ s: MotionScene) -> some View {
        let options = layouts(for: s.slots.count)
        return VStack(alignment: .leading, spacing: 4) {
            hint(String(localized: "How the scene's pictures are laid out (pick its pictures in Pictures)"))
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(options) { l in
                            let on = l.id == s.layoutId
                            Button { withAnimation(.smooth) { store.updateScene { $0.layoutId = l.id } } } label: {
                                LayoutThumb(layout: l, isOn: on)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(l.name)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private func pictureTools(_ s: MotionScene) -> some View {
        let cells = store.project.cells.prefix(store.project.cellCount)
        return VStack(alignment: .leading, spacing: 4) {
            hint(String(localized: "Tap pictures to show or hide them in this scene; numbers are their places"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { slot, cell in
                        let place = s.slots.firstIndex(of: slot)
                        Button { withAnimation(.smooth) { store.toggleSceneSlot(slot) } } label: {
                            slotThumb(cell, place: place)
                        }
                        .buttonStyle(.plain)
                        .disabled(place != nil && s.slots.count <= 1)
                        .accessibilityLabel(place.map { String(localized: "Picture \(slot + 1), in place \($0 + 1)") }
                                            ?? String(localized: "Picture \(slot + 1), not in this scene"))
                    }
                }
                .padding(.top, 7)
                .padding(.trailing, 6)
            }
            .scrollClipDisabled()
        }
    }

    private func slotThumb(_ cell: CellState, place: Int?) -> some View {
        let item = cell.mediaId.flatMap { store.item($0) }
        return ZStack(alignment: .topTrailing) {
            Group {
                if let item {
                    Image(uiImage: item.thumbnail).resizable().scaledToFill()
                } else {
                    Color.white.opacity(0.08).overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                }
            }
            .frame(width: 50, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .opacity(place == nil ? 0.35 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(place == nil ? Color.white.opacity(0.25) : Color.brand, lineWidth: place == nil ? 1 : 2.5)
            )
            if let place {
                Text("\(place + 1)")
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.brand, in: Circle())
                    .offset(x: 5, y: -5)
            }
            if item?.kind == .video {
                Image(systemName: "video.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(.black.opacity(0.5), in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(4)
            }
        }
        .frame(width: 50, height: 62)
    }

    private func transitionTools(_ s: MotionScene, first: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if first {
                hint(String(localized: "The first scene starts the video, so it has no transition in"))
            } else {
                chipRow(MotionTransition.allCases, selected: s.transition, title: \.title, symbol: \.symbol) { t in
                    store.updateScene { $0.transition = t }
                }
            }
            hint(String(localized: "New pictures arrive"))
            chipRow(MotionEntrance.allCases, selected: s.entrance, title: \.title, symbol: \.symbol) { e in
                store.updateScene { $0.entrance = e }
            }
        }
    }

    private func timingTools(_ s: MotionScene) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "timer").font(.caption).foregroundStyle(.secondary)
                Slider(
                    value: Binding(get: { s.length }, set: { store.setSceneLength($0) }),
                    in: minSceneLength...maxSceneLength,
                    step: 0.1
                )
                .accessibilityLabel(String(localized: "Scene length"))
                Text(String(format: "%.1f s", s.length))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }
            hint(String(localized: "Photos move while the scene plays (videos play as they are)"))
            chipRow(PhotoMove.allCases, selected: s.move, title: \.title, symbol: \.symbol) { m in
                store.updateScene { $0.move = m }
            }
        }
    }

    // MARK: Pieces

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private func chipRow<T: Hashable>(_ all: [T], selected: T, title: KeyPath<T, String>, symbol: KeyPath<T, String>,
                                      pick: @escaping (T) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(all, id: \.self) { v in
                    ChipButton(title: v[keyPath: title], symbol: v[keyPath: symbol], isOn: v == selected) {
                        withAnimation(.smooth) { pick(v) }
                    }
                    .accessibilityAddTraits(v == selected ? .isSelected : [])
                }
            }
        }
        .scrollClipDisabled()
    }
}
