import SwiftUI

/// The Collage | Carousel switch in the top bar. The selected side is a piece of glass that slides across.
struct ModeSwitch: View {
    @Environment(CollageStore.self) private var store
    @Namespace private var glass
    /// Asked to switch to a mode that would drop something (videos can't go into a carousel).
    let request: (EditMode) -> Void

    private func symbol(_ m: EditMode) -> String { m == .collage ? "square.grid.2x2" : "rectangle.split.3x1" }

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(EditMode.allCases) { mode in
                    let on = store.project.mode == mode
                    Button {
                        withAnimation(.bouncy(duration: 0.45)) { request(mode) }
                    } label: {
                        Label(mode.label, systemImage: symbol(mode))
                            .labelStyle(CompactModeLabel(showTitle: on))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(on ? Color.white : Color.white.opacity(0.7))
                            .lineLimit(1)
                            .padding(.horizontal, on ? 11 : 10)
                            .frame(height: 30)
                            .contentShape(Capsule())
                            .background {
                                if on {
                                    Capsule()
                                        .fill(.clear)
                                        .glassEffect(.regular.tint(Color.brand.opacity(0.75)).interactive(), in: .capsule)
                                        .glassEffectID("mode", in: glass)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode.label)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(2)
            .glassEffect(.regular, in: .capsule)
        }
        .sensoryFeedback(.selection, trigger: store.project.mode)
    }
}

/// Icon plus name for the selected mode, just the icon for the other one, so the switch stays small.
private struct CompactModeLabel: LabelStyle {
    let showTitle: Bool
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            if showTitle { configuration.title }
        }
    }
}

/// Numbered dots under the carousel preview, like the dots under an Instagram post. Tap one to jump to that slide.
struct SlideBar: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        let slides = store.project.slides
        let current = store.visibleSlide
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(1...slides, id: \.self) { k in
                    let on = k == current
                    Button { store.focusSlide(k - 1) } label: {
                        Text("\(k)")
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .frame(width: 24, height: 24)
                            .glassEffect(on ? .regular.tint(Color.brand.opacity(0.8)).interactive() : .regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Slide \(k)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity)
        }
        .sensoryFeedback(.selection, trigger: current)
    }
}

/// Timeline and Sound share one tab: both only matter when the collage has a video.
struct VideoPanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        @Bindable var store = store
        if placedLanes(store.project).isEmpty {
            HintRow(symbol: "film", text: "Add a video to cut it here, control its sound and add background music.")
        } else {
            VStack(spacing: 8) {
                Picker("Video tools", selection: $store.videoSection) {
                    ForEach(VideoSection.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                switch store.videoSection {
                case .timeline: TimelinePanel()
                case .sound: AudioPanel()
                }
            }
        }
    }
}
