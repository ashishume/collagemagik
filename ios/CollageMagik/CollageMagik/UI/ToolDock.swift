import SwiftUI

/// The tab bar for the editor. One glass bubble marks the selected tool and slides to the next one, like the system tab
/// bar: tap a tool and it glides there, or press and drag across the bar and it follows the finger (a little lifted),
/// settling on the tool it is let go over.
struct ToolDock: View {
    @Environment(CollageStore.self) private var store
    @State private var width: Double = 0
    /// Where the bubble is while being dragged, in tool slots (0 = first tool); nil when not dragging.
    @State private var dragPosition: Double?

    private static let inset: Double = 3
    private static let slide = Animation.spring(response: 0.38, dampingFraction: 0.78)

    var body: some View {
        let tabs = Tab.dock(for: store.project.mode)
        let slot = max(1, (width - 2 * Self.inset) / Double(max(tabs.count, 1)))
        let selectedIndex = tabs.firstIndex(of: store.tab)
        let position = dragPosition ?? selectedIndex.map(Double.init)
        // while dragging, the tool under the bubble lights up before it is chosen
        let lit = position.map { Int($0.rounded()) }

        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.element) { i, tab in
                    let on = lit == i
                    Button {
                        select(tab)
                    } label: {
                        VStack(spacing: 1) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 16, weight: .medium))
                                .symbolVariant(on ? .fill : .none)
                                .frame(height: 19)
                            Text(tab.label)
                                .font(.system(size: 9.5, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(on ? Color.white : Color.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.label)
                    .accessibilityAddTraits(store.tab == tab ? .isSelected : [])
                }
            }
            .background(alignment: .leading) {
                if let position {
                    Capsule()
                        .fill(.clear)
                        .glassEffect(.regular.tint(Color.brand.opacity(0.75)).interactive(), in: .capsule)
                        .frame(width: slot)
                        .scaleEffect(dragPosition == nil ? 1 : 1.12)
                        .offset(x: position * slot)
                        .allowsHitTesting(false)
                }
            }
            .padding(Self.inset)
            .glassEffect(.regular, in: .capsule)
            .onGeometryChange(for: Double.self) { $0.size.width } action: { width = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { g in
                        let p = min(max(0, (g.location.x - Self.inset) / slot - 0.5), Double(tabs.count - 1))
                        if dragPosition == nil {
                            withAnimation(Self.slide) { dragPosition = p }
                        } else {
                            withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.86)) { dragPosition = p }
                        }
                    }
                    .onEnded { _ in
                        guard let p = dragPosition else { return }
                        let i = min(max(0, Int(p.rounded())), tabs.count - 1)
                        withAnimation(Self.slide) {
                            store.tab = tabs[i]
                            dragPosition = nil
                        }
                    }
            )
        }
        .sensoryFeedback(.selection, trigger: store.tab)
        // a tick for each tool the bubble passes while dragged (not when it is picked up or let go)
        .sensoryFeedback(.selection, trigger: dragPosition.map { Int($0.rounded()) }) { old, new in old != nil && new != nil }
    }

    private func select(_ tab: Tab) {
        withAnimation(Self.slide) { store.tab = tab }
    }
}
