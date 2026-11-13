import SwiftUI

/// One round glass-sized icon, the same size everywhere in the top bar.
private struct BarIcon: View {
    let symbol: String
    var badge: Int = 0
    var prominent = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background {
                if prominent { Circle().fill(Color.brand) }
            }
            .contentShape(Circle())
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    Text("\(min(badge, 99))")
                        .font(.system(size: 9, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(Color.brand, in: Capsule())
                        .offset(x: 2, y: -2)
                }
            }
    }
}

/// A rounded glass pill that holds a few icons, so the bar reads as three calm groups instead of loose buttons.
private struct BarGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) { content }
            .padding(2)
            .glassEffect(.regular, in: .capsule)
    }
}

/// The editor's top bar: my library and "new" on the left, the Collage / Carousel switch in the middle,
/// full screen, export and the rest on the right. Everything is icon-only and one size.
struct TopBar: View {
    @Environment(CollageStore.self) private var store
    @Environment(LibraryStore.self) private var library
    let openLibrary: () -> Void
    let requestNew: (EditMode) -> Void
    let requestMode: (EditMode) -> Void

    var body: some View {
        HStack(spacing: 8) {
            BarGroup {
                Button(action: openLibrary) {
                    BarIcon(symbol: "photo.stack", badge: library.entries.count)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(library.entries.isEmpty ? "My Library" : "My Library, \(library.entries.count) saved")

                Menu {
                    Button { requestNew(.collage) } label: { Label("New collage", systemImage: "square.grid.2x2") }
                    Button { requestNew(.carousel) } label: { Label("New carousel", systemImage: "rectangle.split.3x1") }
                } label: {
                    BarIcon(symbol: "plus")
                }
                .accessibilityLabel("New")
            }

            Spacer(minLength: 0)

            ModeSwitch(request: requestMode)

            Spacer(minLength: 0)

            BarGroup {
                Button {
                    store.playback.pause()
                    store.previewOpen = true
                } label: {
                    BarIcon(symbol: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.plain)
                .disabled(store.placedMediaCount == 0)
                .opacity(store.placedMediaCount == 0 ? 0.4 : 1)
                .accessibilityLabel("Full screen preview")

                Button {
                    store.playback.pause()
                    store.exportOpen = true
                } label: {
                    BarIcon(symbol: "square.and.arrow.up", prominent: true)
                }
                .buttonStyle(.plain)
                .disabled(store.placedMediaCount == 0)
                .opacity(store.placedMediaCount == 0 ? 0.4 : 1)
                .accessibilityLabel("Export")

                Menu {
                    Button { store.openAdd() } label: { Label("Add from Photos", systemImage: "photo.on.rectangle") }
                    Button { store.openFiles() } label: { Label("Add from Files", systemImage: "folder") }
                    Divider()
                    Button { store.helpOpen = true } label: { Label("How it works", systemImage: "questionmark.circle") }
                    Button { store.aboutOpen = true } label: { Label("About & Privacy", systemImage: "hand.raised") }
                    Link(destination: AppLinks.writeReview) { Label("Rate Insta Collage", systemImage: "star") }
                    Divider()
                    Button { ProStore.shared.openPaywall() } label: {
                        Label(ProStore.shared.isPro ? "Insta Collage Pro" : "Remove ads (Pro)", systemImage: "sparkles")
                    }
                } label: {
                    BarIcon(symbol: "ellipsis")
                }
                .accessibilityLabel("More")
            }
        }
        .frame(height: 40)
    }
}
