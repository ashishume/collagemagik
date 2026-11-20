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
    @State private var themeOpen = false
    @Environment(LibraryStore.self) private var library
    let openLibrary: () -> Void
    let requestNew: (EditMode) -> Void
    let requestMode: (EditMode) -> Void

    var body: some View {
        HStack(spacing: 8) {
            BarGroup {
                // back to Home; the design stays in Drafts there
                Button {
                    store.playback.pause()
                    store.saveDraftNow()
                    store.editorOpen = false
                } label: {
                    BarIcon(symbol: "chevron.left")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Home")
            }
            // the two sides are equal-width columns, so the title is always exactly in the middle
            .frame(maxWidth: .infinity, alignment: .leading)

            // what is being made; the kind is chosen on Home
            Label(store.project.mode.label, systemImage: store.isCarousel ? "rectangle.split.3x1" : "square.grid.2x2")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .glassEffect(.regular, in: .capsule)
                .layoutPriority(1)

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
                    if let version = updates.availableVersion {
                        Link(destination: AppLinks.appStore) { Label("Update to \(version)", systemImage: "arrow.down.app") }
                        Divider()
                    }
                    Button { store.openAdd() } label: { Label("Add from Photos", systemImage: "photo.on.rectangle") }
                    Button { store.openFiles() } label: { Label("Add from Files", systemImage: "folder") }
                    Divider()
                    Button { themeOpen = true } label: { Label("Theme", systemImage: "paintpalette") }
                    Button { store.helpOpen = true } label: { Label("How it works", systemImage: "questionmark.circle") }
                    Button { store.aboutOpen = true } label: { Label("About & Privacy", systemImage: "hand.raised") }
                    Link(destination: AppLinks.writeReview) { Label("Rate Collage Magic", systemImage: "star") }
                    Divider()
                    Button { ProStore.shared.openPaywall() } label: {
                        Label(ProStore.shared.isPro ? "Collage Magic Pro" : "Remove ads (Pro)", systemImage: "sparkles")
                    }
                } label: {
                    // a menu icon rather than three dots: it holds adding photos, help, theme and Pro
                    BarIcon(symbol: "line.3.horizontal")
                        .overlay(alignment: .topTrailing) {
                            if updates.updateAvailable { UpdateDot().offset(x: -3, y: 3) }
                        }
                }
                .accessibilityLabel("Menu")
                .sheet(isPresented: $themeOpen) { ThemePicker() }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 40)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: updates.updateAvailable)
    }

    private var updates: UpdateChecker { .shared }
}

/// The small pink dot on "More" while an App Store update is waiting.
private struct UpdateDot: View {
    var body: some View {
        Circle().fill(Color.laneA).frame(width: 9, height: 9)
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

/// A slim strip under the top bar when the App Store has a newer version. Not a popup: the editor keeps working,
/// "Update" opens the App Store page, and the cross hides the strip for that version (the dot on "More" stays).
struct UpdateBanner: View {
    @AppStorage("cm.update.dismissedVersion") private var dismissedVersion = ""
    @State private var glow = false
    private var updates: UpdateChecker { .shared }

    var body: some View {
        if let version = updates.availableVersion, version != dismissedVersion {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background {
                        Circle()
                            .fill(LinearGradient(colors: [Color.brand, Color.laneA], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: Color.laneA.opacity(glow ? 0.8 : 0.2), radius: glow ? 8 : 2)
                    }
                Text("A new version (\(version)) is ready")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 4)
                Link(destination: AppLinks.appStore) {
                    Text("Update")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Color.brand, in: Capsule())
                }
                Button {
                    withAnimation(.smooth) { dismissedVersion = version }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 26, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide")
            }
            .padding(.leading, 5)
            .padding(.trailing, 4)
            .padding(.vertical, 4)
            .glassEffect(.regular, in: .capsule)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { glow = true }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Update available, version \(version)")
        }
    }
}


/// Undo and redo, floating in a small glass pill at the top corner of the preview. Shown once there is something to undo.
struct UndoRedoPill: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        if store.canUndo || store.canRedo {
            HStack(spacing: 0) {
                button("arrow.uturn.backward", label: "Undo", enabled: store.canUndo) { store.undo() }
                button("arrow.uturn.forward", label: "Redo", enabled: store.canRedo) { store.redo() }
            }
            .padding(2)
            .glassEffect(.regular.interactive(), in: .capsule)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }

    private func button(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }
}
