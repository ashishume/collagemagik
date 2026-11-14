import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(CollageStore.self) private var store
    @Environment(LibraryStore.self) private var library
    @Environment(\.scenePhase) private var scenePhase
    /// "New collage" / "New carousel" waiting for the user to confirm (their current work would be cleared).
    @State private var pendingNew: EditMode?
    @State private var libraryOpen = false
    /// Carousel needs photos only: asks before the videos are dropped.
    @State private var confirmCarousel = false
    /// The one-time ads notice, shown after the first finished export.
    @Bindable private var ads = AdManager.shared

    /// Replacing a picture takes one item; adding to the collage (or filling an empty cell) takes as many as there is room for.
    private var pickLimit: Int {
        if store.pickOverlay != nil { return 1 }
        if let t = store.pickTarget, store.project.cells.indices.contains(t), store.project.cells[t].mediaId != nil { return 1 }
        return max(1, maxTrayItems - store.items.count)
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ZStack(alignment: .top) {
                AuroraBackground(paused: store.playback.isPlaying).ignoresSafeArea()

                VStack(spacing: 6) {
                    TopBar(
                        openLibrary: { store.playback.pause(); libraryOpen = true },
                        requestNew: { mode in
                            if store.items.isEmpty { withAnimation(.smooth) { store.newCollage(mode: mode) } } else { pendingNew = mode }
                        },
                        requestMode: { mode in
                            if mode == .carousel && store.videoCount > 0 { confirmCarousel = true } else { store.setMode(mode) }
                        }
                    )
                    StageView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if store.isCarousel {
                        SlideBar()
                    } else if store.hasPlacedVideo && store.tab != .video {
                        // always there while the collage has a video: play, scrub, and the way into the timeline
                        TransportBar()
                    }
                    PanelCard()
                    AdBannerSlot()
                    ToolDock()
                }
                .padding(.horizontal, 12)
                .padding(.top, 2)
                .padding(.bottom, 4)
                // the caption keyboard opens over the editor; it must not squeeze the preview behind it
                .ignoresSafeArea(.keyboard, edges: .bottom)

                if let progress = store.importProgress {
                    ImportProgressOverlay(progress: progress) { store.cancelImport() }
                        .transition(.opacity)
                        .zIndex(1)
                }

                if let toast = store.toast {
                    ToastView(text: toast.text)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 52)
                        .zIndex(2)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .photosPicker(
            isPresented: $store.showPhotoPicker,
            selection: $store.pickedItems,
            maxSelectionCount: pickLimit,
            selectionBehavior: .ordered,
            matching: store.isCarousel || store.pickOverlay != nil ? .images : .any(of: [.images, .videos])
        )
        .onChange(of: store.pickedItems) { _, picked in
            guard !picked.isEmpty else { return }
            store.startPickedImport(picked)
            store.pickedItems = []
        }
        .fileImporter(
            isPresented: $store.showFileImporter,
            allowedContentTypes: store.importerIsMusic ? [.audio] : (store.isCarousel || store.pickOverlay != nil ? [.image] : [.image, .movie, .video]),
            allowsMultipleSelection: !store.importerIsMusic && store.pickOverlay == nil
        ) { result in
            guard case .success(let urls) = result else { return }
            if store.importerIsMusic, let u = urls.first {
                Task { await store.importMusic(u) }
            } else {
                store.startFileImport(urls)
            }
        }
        .alert("Your media tray is full", isPresented: $store.showTrayFull) {
            Button("Show my tray") { withAnimation(.smooth) { store.tab = .media } }
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.trayFullMessage)
        }
        .sheet(isPresented: $store.exportOpen) { ExportSheet() }
        .sheet(isPresented: $store.helpOpen) { HelpSheet() }
        .sheet(isPresented: $libraryOpen) { LibrarySheet() }
        .sheet(isPresented: $store.aboutOpen) { AboutSheet() }
        .sheet(isPresented: $ads.showNotice) { AdNoticeSheet() }
        .onAppear {
            ProStore.shared.start()
            ProStore.shared.appDidLaunch()
            AdManager.shared.appDidLaunch()
            GoogleAdsManager.shared.appDidLaunch()
        }
        // the Pro page opens here only when no other sheet is up (those host it themselves)
        .proPaywallHost(active: !store.exportOpen && !store.aboutOpen)
        .fullScreenCover(isPresented: $store.previewOpen) { FullScreenPreview() }
        .fullScreenCover(item: Binding(
            get: { store.cropCell.map(CropTarget.cell) ?? store.cropOverlay.map(CropTarget.overlay) },
            set: { if $0 == nil { store.cropCell = nil; store.cropOverlay = nil } }
        )) { target in
            CropEditor(target: target)
        }
        .fullScreenCover(item: $store.partClip) { ref in
            ChoosePartEditor(ref: ref)
        }
        .fullScreenCover(item: Binding(
            get: { store.editingCaption.map(CaptionTarget.init) },
            set: { if $0 == nil { store.finishEditingCaption() } }
        )) { target in
            CaptionEditor(id: target.id)
        }
        .onChange(of: store.project) {
            store.playback.projectChanged()
            store.scheduleDraftSave()
        }
        .onChange(of: store.items.map(\.id)) { store.scheduleDraftSave() }
        // leaving the app: save at once, iOS may close it in the background
        .onChange(of: scenePhase) { _, phase in if phase != .active { store.saveDraftNow() } }
        .task { await store.restoreLastDraft() }
        // a selection lasts only while its own tools are showing: a dock tab edits the whole design
        .onChange(of: store.tab) { _, tab in
            if tab != .text { store.selectedCaption = nil }
            store.dockTabChanged(tab)
        }
        #if DEBUG
        .task { await DebugHarness.run(store) }
        #endif
        .confirmationDialog("Switch to Carousel?", isPresented: $confirmCarousel, titleVisibility: .visible) {
            Button("Remove videos and switch", role: .destructive) { withAnimation(.smooth) { store.setMode(.carousel) } }
            Button("Keep my collage", role: .cancel) {}
        } message: {
            Text("Carousels use photos only, so the videos in this collage will be removed.")
        }
        .confirmationDialog(
            pendingNew == .carousel ? "Start a new carousel?" : "Start a new collage?",
            isPresented: Binding(get: { pendingNew != nil }, set: { if !$0 { pendingNew = nil } }),
            titleVisibility: .visible,
            presenting: pendingNew
        ) { mode in
            Button(mode == .carousel ? "New carousel" : "New collage") {
                withAnimation(.smooth) { store.newCollage(mode: mode) }
            }
            Button("Keep editing", role: .cancel) {}
        } message: { _ in
            Text("Your current design is kept in My Library, under Drafts.")
        }
    }
}

/// The glass card that holds whichever tool is selected.
struct PanelCard: View {
    @Environment(CollageStore.self) private var store

    private var height: CGFloat {
        let pad: CGFloat = 20
        switch store.tab {
        case .media: return (store.items.isEmpty ? 96 : 116) + pad
        // collages with borders to drag get a row with the hint and "Reset sizes"
        case .layout:
            if store.isCarousel { return 100 + pad }
            return (store.project.resizableGrid?.dividers.isEmpty == false ? 138 : 106) + pad
        case .style:
            let frame: CGFloat = store.project.frame == .none ? 40 : store.project.frame.hasEdge ? 92 : 58
            return (store.project.format == .story ? 156 : 124) + frame + pad
        case .text: return (store.caption(store.selectedCaption) == nil ? 66 : 264) + pad
        case .video:
            let n = placedLanes(store.project).count
            if n == 0 { return 44 + pad }
            let picker: CGFloat = 40
            switch store.videoSection {
            case .timeline: return picker + timelineContentHeight(lanes: n) + pad + 6
            case .sound: return picker + CGFloat(n) * 36 + (store.project.music == nil ? 34 : 3 * 36) + pad + 4
            }
        case .overlay:
            guard let o = store.overlay(store.selectedOverlay) else { return 44 + pad }
            return (o.frame.hasEdge ? 254 : 222) + pad
        case .picture:
            guard let s = store.selectedCell, store.project.cells.indices.contains(s) else { return 44 + pad }
            if store.swapFrom != nil { return 36 + pad }
            guard let id = store.project.cells[s].mediaId else { return 40 + pad }
            return (store.item(id)?.kind == .video ? 150 : 108) + pad
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Group {
                switch store.tab {
                case .media: MediaPanel()
                case .layout: LayoutPanel()
                case .style: StylePanel()
                case .text: TextPanel()
                case .video: VideoPanel()
                case .picture: PicturePanel()
                case .overlay: OverlayPanel()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(10)
        }
        .scrollBounceBehavior(.basedOnSize)
        // the timeline owns every drag inside it; the card must not scroll under the finger
        .scrollDisabled(store.tab == .video && store.videoSection == .timeline)
        .frame(height: height)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .animation(.smooth(duration: 0.3), value: store.tab)
        .animation(.smooth(duration: 0.3), value: store.selectedCaption == nil)
    }
}
