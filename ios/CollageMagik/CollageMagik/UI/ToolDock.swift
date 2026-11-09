import SwiftUI

/// The tab bar for the editor. The selected tool is a piece of glass that slides (morphs) to the next one.
struct ToolDock: View {
    @Environment(CollageStore.self) private var store
    @Namespace private var glass

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(Tab.allCases) { tab in
                    let selected = store.tab == tab
                    Button {
                        withAnimation(.bouncy(duration: 0.45)) { store.tab = tab }
                    } label: {
                        VStack(spacing: 1) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 16, weight: .medium))
                                .symbolVariant(selected ? .fill : .none)
                                .frame(height: 19)
                            Text(tab.label)
                                .font(.system(size: 9.5, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(selected ? Color.white : Color.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .contentShape(Capsule())
                        .background {
                            if selected {
                                Capsule()
                                    .fill(.clear)
                                    .glassEffect(.regular.tint(Color.brand.opacity(0.75)).interactive(), in: .capsule)
                                    .glassEffectID("selected", in: glass)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.label)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(3)
            .glassEffect(.regular, in: .capsule)
        }
        .sensoryFeedback(.selection, trigger: store.tab)
    }
}
