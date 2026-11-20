import SwiftUI

/// The three places to start from, in the system tab bar.
enum HomeSection: Hashable {
    case collage, carousel, templates, library
}

/// The app's first screen: Collage, Carousel and Templates. Each kind lists its own drafts and a few templates; the
/// editor opens over it, full screen, and the back button returns here (the design is kept in Drafts).
struct HomeView: View {
    @Environment(CollageStore.self) private var store
    @Environment(\.splashDone) private var splashDone
    @State private var section: HomeSection = .collage
    @State private var launched = false
    /// The Templates tab opens filtered to the kind it was reached from.
    @State private var templateMode: EditMode?

    var body: some View {
        @Bindable var store = store
        TabView(selection: $section) {
            SwiftUI.Tab("Collage", systemImage: "square.grid.2x2", value: .collage) {
                KindHome(mode: .collage) { templateMode = .collage; section = .templates }
            }
            SwiftUI.Tab("Carousel", systemImage: "rectangle.split.3x1", value: .carousel) {
                KindHome(mode: .carousel) { templateMode = .carousel; section = .templates }
            }
            SwiftUI.Tab("Templates", systemImage: "sparkles.rectangle.stack", value: .templates) {
                TemplatesHome(mode: $templateMode)
            }
            SwiftUI.Tab("Library", systemImage: "photo.stack", value: .library) {
                LibraryHome()
            }
        }
        .fullScreenCover(isPresented: $store.editorOpen) {
            RootView()
        }
        // About, help and the Pro page open here while the editor is closed (the editor hosts its own)
        .sheet(isPresented: Binding(get: { store.aboutOpen && !store.editorOpen }, set: { store.aboutOpen = $0 })) { AboutSheet() }
        .sheet(isPresented: Binding(get: { store.helpOpen && !store.editorOpen }, set: { store.helpOpen = $0 })) { HelpSheet() }
        .proPaywallHost(active: !store.editorOpen)
        // The consent and tracking questions wait until the splash has gone, so they never pop up over the animation.
        .onChange(of: splashDone, initial: true) { _, done in
            guard done, !launched else { return }
            launched = true
            ProStore.shared.start()
            ProStore.shared.appDidLaunch()
            GoogleAdsManager.shared.appDidLaunch()
            UpdateChecker.shared.checkIfDue()
        }
        .task {
            store.refreshDrafts()
            #if DEBUG
            // the debug harness drives the editor
            let env = ProcessInfo.processInfo.environment
            if env.keys.contains(where: { $0.hasPrefix("CM_") && $0 != "CM_PRO" && $0 != "CM_PAYWALL" && $0 != "CM_PRO_MOCK" }) {
                store.editorOpen = true
            }
            #endif
        }
    }
}

/// Starts a new design and opens the editor, then the photo picker (a moment later, once the editor is up).
@MainActor
func startDesign(_ store: CollageStore, mode: EditMode, template: DesignTemplate? = nil) {
    store.newCollage(mode: mode)
    if let template { store.applyTemplate(template) }
    store.editorOpen = true
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(0.55))
        store.openAdd()
    }
}

/// Home for one kind: a big "New" card, templates for this kind, and its drafts.
private struct KindHome: View {
    @Environment(CollageStore.self) private var store
    let mode: EditMode
    let seeAllTemplates: () -> Void

    var body: some View {
        let drafts = store.drafts.filter { $0.mode == mode }
        ZStack {
            AuroraBackground().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeader(title: mode == .collage ? "Collage" : "Carousel",
                               subtitle: mode == .collage ? "Photos and videos in one design" : "Pictures that flow across Instagram slides")

                    newCard

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Start from a template", action: ("See all", seeAllTemplates))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 14) {
                                ForEach(templates(for: mode).prefix(8)) { t in
                                    TemplateCard(template: t, height: 150) { startDesign(store, mode: mode, template: t) }
                                        .frame(width: mode == .carousel ? 220 : 140)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle(drafts.isEmpty ? "Your \(mode == .collage ? "collages" : "carousels")" : "Recent")
                        if drafts.isEmpty {
                            Text("Designs you make are saved here as you go, so you can come back to them any time.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: mode == .carousel ? 260 : 150), spacing: 14)], spacing: 14) {
                                ForEach(drafts) { d in DraftTile(draft: d) }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var newCard: some View {
        Button { startDesign(store, mode: mode) } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.brand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode == .collage ? "New collage" : "New carousel")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(mode == .collage ? "Up to \(maxCells) photos and \(maxVideos) videos, with music" : "2 to \(maxCarouselPhotos) photos, slides added for you")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding(14)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityLabel(mode == .collage ? "New collage" : "New carousel")
    }

    private func sectionTitle(_ title: String, action: (String, () -> Void)? = nil) -> some View {
        HStack {
            Text(title).font(.title3.weight(.semibold))
            Spacer()
            if let action {
                Button(action.0, action: action.1).font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
    }
}

/// The Templates tab: every template, filtered by kind and category.
private struct TemplatesHome: View {
    @Environment(CollageStore.self) private var store
    @Binding var mode: EditMode?
    @State private var category: TemplateCategory?

    var body: some View {
        ZStack {
            AuroraBackground().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HomeHeader(title: "Templates", subtitle: "Pick a look, then add your photos")
                    Picker("Kind", selection: $mode) {
                        Text("All").tag(EditMode?.none)
                        Text("Collage").tag(EditMode?.some(.collage))
                        Text("Carousel").tag(EditMode?.some(.carousel))
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    TemplateCategoryChips(mode: mode, category: $category)
                    TemplateGrid(list: templates(for: mode, category: category)) { t in
                        startDesign(store, mode: t.mode, template: t)
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: mode) {
            if let c = category, templates(for: mode, category: c).isEmpty { category = nil }
        }
    }
}

/// The Collage Magic mark (logo and name) with the Settings menu, then the tab's big title and a line under it.
private struct HomeHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                BrandMark()
                Spacer()
                SettingsMenu()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.largeTitle.weight(.bold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }
}

/// The app's logo and name, top left on Home.
struct BrandMark: View {
    var body: some View {
        HStack(spacing: 8) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color.brand.opacity(0.5), radius: 6)
            Text("Collage Magic")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, Color(red: 0.85, green: 0.78, blue: 1)], startPoint: .leading, endPoint: .trailing))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Collage Magic")
        .accessibilityAddTraits(.isHeader)
    }
}

/// Settings (a gear, not three dots): theme, help, about, rating and Pro.
private struct SettingsMenu: View {
    @Environment(CollageStore.self) private var store
    @State private var themeOpen = false

    var body: some View {
        Menu {
            Button { themeOpen = true } label: { Label("Theme", systemImage: "paintpalette") }
            Button { store.helpOpen = true } label: { Label("How it works", systemImage: "questionmark.circle") }
            Button { store.aboutOpen = true } label: { Label("About & Privacy", systemImage: "hand.raised") }
            Link(destination: AppLinks.writeReview) { Label("Rate Collage Magic", systemImage: "star") }
            Divider()
            Button { ProStore.shared.openPaywall() } label: {
                Label(ProStore.shared.isPro ? "Collage Magic Pro" : "Remove ads (Pro)", systemImage: "sparkles")
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .accessibilityLabel("Settings")
        .sheet(isPresented: $themeOpen) { ThemePicker() }
    }
}

/// The Library tab: Collage and Carousel tabs at the top, each with its drafts and its exports.
private struct LibraryHome: View {
    @State private var kind: EditMode = .collage

    var body: some View {
        ZStack {
            AuroraBackground().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HomeHeader(title: "Library", subtitle: "Your drafts and exports, on this iPhone only")
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 0) {
                        ForEach(Array([EditMode.collage, .carousel].enumerated()), id: \.element) { i, k in
                            let on = kind == k
                            Button {
                                kind = k
                            } label: {
                                Label(k == .collage ? "Collages" : "Carousels", systemImage: k == .collage ? "square.grid.2x2" : "rectangle.split.3x1")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(on ? Color.white : Color.white.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .contentShape(Capsule())
                                    .slidingTab(i)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .slidingTabs(selected: kind == .collage ? 0 : 1) { kind = $0 == 0 ? .collage : .carousel }
                    .padding(3)
                    .glassEffect(.regular, in: .capsule)
                }
                .padding(.horizontal, 16)
                .sensoryFeedback(.selection, trigger: kind)

                LibrarySheet(kind: kind, embedded: true)
                    .id(kind)
            }
            .padding(.top, 12)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }
}

/// A saved draft: its thumbnail and what is in it. Tap to keep editing; touch and hold to delete.
private struct DraftTile: View {
    @Environment(CollageStore.self) private var store
    let draft: DraftSummary
    @State private var confirmDelete = false

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.06))
                    if let img = UIImage(contentsOfFile: draft.thumbURL.path) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(10)
                    }
                }
                .frame(height: 170)
                Text(draft.summary).font(.footnote.weight(.semibold)).lineLimit(1)
                Text(draft.updatedAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open", systemImage: "pencil") { open() }
            Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
        }
        .confirmationDialog("Delete this draft?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { store.deleteDraft(draft.id) }
        } message: {
            Text("The design is removed from this iPhone. Exports in My Library are not affected.")
        }
        .accessibilityLabel("Draft, \(draft.summary)")
    }

    private func open() {
        store.editorOpen = true
        guard draft.id != store.draftId || !store.hasContent else { return }
        Task { await store.openDraft(draft.id) }
    }
}
