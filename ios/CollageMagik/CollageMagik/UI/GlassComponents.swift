import SwiftUI

// MARK: - App themes

/// The colour field behind every screen (editor, splash, Pro page, crop, Choose part). People pick one under
/// More → Theme; the choice is kept on the device. All are dark so photos read the same whichever is chosen.
enum AppTheme: String, CaseIterable, Identifiable {
    case magic, blackGlass, midnight, ocean, aurora, forest, sunset, rose, ember

    static let storageKey = "appTheme"
    static let fallback: AppTheme = .magic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .magic: "Magic"
        case .blackGlass: "Black Glass"
        case .midnight: "Midnight"
        case .ocean: "Ocean"
        case .aurora: "Aurora"
        case .forest: "Forest"
        case .sunset: "Sunset"
        case .rose: "Rose"
        case .ember: "Ember"
        }
    }

    /// The 3 × 3 mesh colours, row by row from the top-left.
    var colors: [Color] {
        func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        switch self {
        case .magic: return [
            c(0.10, 0.05, 0.25), c(0.32, 0.14, 0.62), c(0.07, 0.10, 0.30),
            c(0.45, 0.10, 0.45), c(0.12, 0.06, 0.22), c(0.10, 0.30, 0.55),
            c(0.06, 0.04, 0.14), c(0.55, 0.15, 0.40), c(0.05, 0.08, 0.22),
        ]
        case .blackGlass: return [
            c(0.10, 0.10, 0.10), c(0.17, 0.17, 0.19), c(0.07, 0.07, 0.07),
            c(0.05, 0.05, 0.05), c(0.11, 0.11, 0.13), c(0.04, 0.04, 0.04),
            c(0.02, 0.02, 0.02), c(0.06, 0.06, 0.06), c(0.02, 0.02, 0.02),
        ]
        case .midnight: return [
            c(0.03, 0.05, 0.16), c(0.10, 0.16, 0.42), c(0.04, 0.06, 0.20),
            c(0.08, 0.10, 0.30), c(0.03, 0.04, 0.12), c(0.16, 0.22, 0.55),
            c(0.02, 0.03, 0.09), c(0.08, 0.12, 0.34), c(0.02, 0.03, 0.10),
        ]
        case .ocean: return [
            c(0.02, 0.12, 0.22), c(0.04, 0.36, 0.55), c(0.03, 0.14, 0.26),
            c(0.02, 0.30, 0.38), c(0.02, 0.09, 0.16), c(0.10, 0.42, 0.62),
            c(0.01, 0.06, 0.12), c(0.04, 0.28, 0.40), c(0.02, 0.07, 0.14),
        ]
        case .aurora: return [
            c(0.03, 0.12, 0.14), c(0.06, 0.45, 0.38), c(0.08, 0.06, 0.24),
            c(0.10, 0.32, 0.30), c(0.03, 0.08, 0.12), c(0.30, 0.16, 0.55),
            c(0.02, 0.05, 0.08), c(0.05, 0.38, 0.30), c(0.06, 0.04, 0.16),
        ]
        case .forest: return [
            c(0.05, 0.12, 0.07), c(0.14, 0.34, 0.16), c(0.06, 0.10, 0.06),
            c(0.10, 0.26, 0.12), c(0.04, 0.08, 0.05), c(0.22, 0.36, 0.14),
            c(0.02, 0.05, 0.03), c(0.12, 0.28, 0.14), c(0.03, 0.06, 0.04),
        ]
        case .sunset: return [
            c(0.20, 0.06, 0.18), c(0.60, 0.22, 0.20), c(0.18, 0.05, 0.14),
            c(0.48, 0.12, 0.30), c(0.14, 0.04, 0.12), c(0.66, 0.34, 0.16),
            c(0.08, 0.03, 0.10), c(0.42, 0.10, 0.26), c(0.10, 0.03, 0.08),
        ]
        case .rose: return [
            c(0.20, 0.05, 0.12), c(0.55, 0.16, 0.36), c(0.16, 0.05, 0.12),
            c(0.40, 0.10, 0.26), c(0.12, 0.04, 0.09), c(0.62, 0.26, 0.44),
            c(0.07, 0.02, 0.06), c(0.36, 0.10, 0.24), c(0.08, 0.03, 0.07),
        ]
        case .ember: return [
            c(0.16, 0.05, 0.02), c(0.55, 0.20, 0.04), c(0.12, 0.04, 0.02),
            c(0.40, 0.10, 0.04), c(0.10, 0.03, 0.02), c(0.62, 0.32, 0.06),
            c(0.06, 0.02, 0.01), c(0.36, 0.10, 0.03), c(0.07, 0.02, 0.02),
        ]
        }
    }

    /// A little darker overall, so captions and controls stay easy to read on the brighter themes.
    var dim: Double { self == .blackGlass ? 0 : 0.18 }
}

/// A soft, slowly drifting colour field in the chosen theme. Liquid Glass bends and refracts what is behind it, so the
/// background gives it something to show.
struct AuroraBackground: View {
    var paused = false
    @AppStorage(AppTheme.storageKey) private var themeId = AppTheme.fallback.rawValue

    var body: some View {
        let theme = AppTheme(rawValue: themeId) ?? .fallback
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: paused)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let a = Float(sin(t / 5.0) * 0.07)
            let b = Float(cos(t / 6.5) * 0.07)
            ThemeMesh(theme: theme, a: a, b: b)
        }
        .animation(.easeInOut(duration: 0.5), value: themeId)
    }
}

/// The theme's mesh, drifted by `a` and `b` (0 = still, as in the swatches).
struct ThemeMesh: View {
    let theme: AppTheme
    var a: Float = 0
    var b: Float = 0

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5 + a, 0], [1, 0],
                [0, 0.5 + b], [0.5 + b, 0.5 - a], [1, 0.5 - b],
                [0, 1], [0.5 - a, 1], [1, 1],
            ],
            colors: theme.colors
        )
        .overlay(Color.black.opacity(theme.dim))
    }
}

/// More → Theme: a row of swatches; the app behind changes as soon as one is tapped.
struct ThemePicker: View {
    @AppStorage(AppTheme.storageKey) private var themeId = AppTheme.fallback.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Theme").font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.glassProminent)
                    .tint(Color.brand)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                ForEach(AppTheme.allCases) { theme in
                    let on = themeId == theme.rawValue
                    Button {
                        withAnimation(.easeInOut(duration: 0.4)) { themeId = theme.rawValue }
                    } label: {
                        VStack(spacing: 6) {
                            ThemeMesh(theme: theme)
                                .frame(height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.15), lineWidth: 1))
                                .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(Color.brand, lineWidth: on ? 3 : 0).padding(-4))
                                .overlay(alignment: .bottomTrailing) {
                                    if on {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white, Color.brand)
                                            .padding(6)
                                    }
                                }
                            Text(theme.title)
                                .font(.footnote.weight(on ? .semibold : .regular))
                                .foregroundStyle(on ? .primary : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(theme.title) theme")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .padding(20)
        .presentationDetents([.height(420)])
        .presentationBackground(.ultraThinMaterial)
        // no dimming behind the sheet, so the new theme shows on the app straight away
        .presentationBackgroundInteraction(.enabled)
        .sensoryFeedback(.selection, trigger: themeId)
    }
}

/// A small glass button with an icon and a label.
struct ChipButton: View {
    let title: String
    let symbol: String
    var isOn = false
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .buttonStyle(.glass)
        .tint(isOn ? Color.brand : nil)
        .controlSize(.small)
    }
}

/// A compact glass tile: icon over a tiny caption. Several fit in one row.
struct CompactTool: View {
    let title: String
    let symbol: String
    var isOn = false
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 15, weight: .medium)).frame(height: 18)
                Text(title).font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.65)
            }
            // the whole tile is room for the title: seven tools fit in a row without cutting words off
            .padding(.horizontal, 2)
            .foregroundStyle(role == .destructive ? Color.red : (isOn ? Color.white : Color.primary))
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .glassEffect(isOn ? .regular.tint(Color.brand.opacity(0.7)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// A compact tool tile that opens a menu (same look as `CompactTool`).
struct CompactMenuTool<Items: View>: View {
    let title: String
    let symbol: String
    var isOn = false
    @ViewBuilder let items: Items

    var body: some View {
        Menu {
            items
        } label: {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 15, weight: .medium)).frame(height: 18)
                Text(title).font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.65)
            }
            .padding(.horizontal, 2)
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .glassEffect(isOn ? .regular.tint(Color.brand.opacity(0.7)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// A one-line hint that replaces the big "unavailable" placeholders, so empty panels stay short.
struct HintRow: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A round glass icon button.
struct GlassIconButton: View {
    let symbol: String
    let label: String
    var isOn = false
    var size: CGFloat = 32
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .tint(isOn ? Color.brand : nil)
        .accessibilityLabel(label)
    }
}

/// A labelled slider row.
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil
    var format: (Double) -> String = { "\(Int($0.rounded()))" }
    var onEditing: ((Bool) -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 84, alignment: .leading)
            Group {
                if let step {
                    Slider(value: $value, in: range, step: step, onEditingChanged: { onEditing?($0) })
                } else {
                    Slider(value: $value, in: range, onEditingChanged: { onEditing?($0) })
                }
            }
            Text(format(value))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .trailing)
        }
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .padding(.horizontal, 16)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

/// A failed Save to Photos. When the cause is a refused permission it offers a button straight to this app's Settings page.
struct SaveFailureNote: View {
    let error: Error
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 8) {
            Text(error.localizedDescription)
                .font(.footnote)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
            if error is PhotosAccessDenied {
                Button("Open Settings", systemImage: "gearshape") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.glass)
            }
        }
    }
}

/// The loader shown while picked photos and videos are added: "Adding 2 of 5", a progress bar, and Cancel.
/// It sits over a dimmed screen, so nothing else can change the collage halfway through an import.
struct ImportProgressOverlay: View {
    let progress: ImportProgress
    let cancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small).tint(.white)
                    Text(progress.title)
                        .font(.headline)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Spacer(minLength: 8)
                    Text("\(Int((progress.fraction * 100).rounded()))%")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                ProgressView(value: progress.fraction)
                    .tint(Color.brand)
                    .animation(.smooth(duration: 0.25), value: progress.fraction)
                HStack {
                    Text(progress.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Button("Cancel", role: .cancel, action: cancel)
                        .buttonStyle(.glass)
                        .controlSize(.small)
                }
            }
            .padding(18)
            .frame(maxWidth: 340)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .padding(.horizontal, 24)
            .animation(.smooth, value: progress.current)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(progress.title), \(Int((progress.fraction * 100).rounded())) percent")
        }
    }
}

// MARK: - Grouped tool panels

/// A group of tools inside a selection panel (photo on top, caption): only one group shows at a time.
protocol PanelSection: CaseIterable, Identifiable, Hashable where AllCases: RandomAccessCollection {
    var title: String { get }
    var symbol: String { get }
}

/// Height of the tools under the group tabs: the same for every group, so the card doesn't jump when switching.
let panelSectionHeight: CGFloat = 94
/// Height of the group tabs row.
let panelTabsHeight: CGFloat = 34

/// The row of group tabs at the top of a selection panel. The chosen tab is glass that slides to the next one.
struct SectionTabs<S: PanelSection>: View {
    @Binding var selection: S
    @Namespace private var glass

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            // roomy glass around each title when the row has space for it; with many tabs (Text), a tighter fit
            ViewThatFits(in: .horizontal) {
                tabs(padding: 12)
                tabs(padding: 4)
            }
            .padding(2)
            .glassEffect(.regular, in: .capsule)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    /// Each tab is as wide as its title needs, so a long one ("Background") still has room inside the glass.
    private func tabs(padding: CGFloat) -> some View {
        TitleWidthRow {
            ForEach(S.allCases) { s in
                let on = s == selection
                Button {
                    withAnimation(.bouncy(duration: 0.4)) { selection = s }
                } label: {
                    Label(s.title, systemImage: s.symbol)
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, padding)
                        .foregroundStyle(on ? Color.white : Color.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .contentShape(Capsule())
                        .slidingBubbleSlot(on, in: glass)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(s.title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .slidingBubble(in: glass)
    }
}

// MARK: - Sliding selection bubble

/// One glass bubble behind a row of tabs that slides (and stretches) from the old tab to the new one, like the system
/// tab bar, instead of a separate bubble fading out under one tab and in under the next. The selected tab marks its
/// place with `slidingBubbleSlot`; the row draws the bubble there with `slidingBubble`.
extension View {
    func slidingBubbleSlot(_ selected: Bool, in ns: Namespace.ID) -> some View {
        background {
            if selected { Color.clear.matchedGeometryEffect(id: "bubble", in: ns) }
        }
    }

    func slidingBubble(in ns: Namespace.ID) -> some View {
        background {
            Capsule()
                .fill(.clear)
                .glassEffect(.regular.tint(Color.brand.opacity(0.75)).interactive(), in: .capsule)
                .matchedGeometryEffect(id: "bubble", in: ns, isSource: false)
                .allowsHitTesting(false)
        }
    }
}

/// One row of tabs: each gets the width it needs, then any room left over is shared equally.
/// When the row is too narrow, every tab gives up the same amount, which comes out of its padding first.
struct TitleWidthRow: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        return CGSize(
            width: proposal.width ?? ideals.reduce(0) { $0 + $1.width },
            height: ideals.map(\.height).max() ?? 0
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let ideals = subviews.map { $0.sizeThatFits(.unspecified).width }
        let total = ideals.reduce(0, +)
        let extra = (bounds.width - total) / CGFloat(subviews.count)
        var x = bounds.minX
        for (i, s) in subviews.enumerated() {
            let w = ideals[i] + extra
            s.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: w, height: bounds.height))
            x += w
        }
    }
}

/// The round check that closes a selection panel.
struct PanelDoneButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).frame(width: 30, height: 30)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .accessibilityLabel("Done")
    }
}

/// Group tabs and a Done button over one group of tools, at a fixed height.
struct SectionedPanel<S: PanelSection, Content: View>: View {
    @Binding var section: S
    let done: () -> Void
    @ViewBuilder let content: (S) -> Content

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                SectionTabs(selection: $section)
                PanelDoneButton(action: done)
            }
            content(section)
                .frame(maxWidth: .infinity)
                .frame(height: panelSectionHeight)
                .transition(.opacity)
        }
        .animation(.smooth(duration: 0.25), value: section)
    }
}

/// Stands in for the tab bar while one picture, photo or caption is being edited, so its tools get the room.
/// Tap it (or swipe it up) to bring the tabs back.
struct DockHandle: View {
    let show: () -> Void

    var body: some View {
        Button(action: show) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up").font(.system(size: 11, weight: .bold))
                Image(systemName: "square.grid.2x2").font(.system(size: 12, weight: .semibold))
                Text("Tabs").font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 16)
            .frame(height: 28)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 12).onEnded { v in if v.translation.height < -8 { show() } })
        .accessibilityLabel("Show tabs")
        .accessibilityHint("Shows Media, Layout, Style and Text")
    }
}
