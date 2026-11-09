import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(CollageStore.self) private var store
    @Environment(LibraryStore.self) private var library
    @State private var confirmNew = false
    @State private var libraryOpen = false
    @State private var aboutOpen = false
    /// Carousel needs photos only: asks before the videos are dropped.
    @State private var confirmCarousel = false

    /// Replacing a picture takes one item; adding to the collage (or filling an empty cell) takes as many as there is room for.
    private var pickLimit: Int {
        if let t = store.pickTarget, store.project.cells.indices.contains(t), store.project.cells[t].mediaId != nil { return 1 }
        return max(1, store.cellLimit - store.items.count)
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ZStack(alignment: .top) {
                AuroraBackground(paused: store.playback.isPlaying).ignoresSafeArea()

                VStack(spacing: 6) {
                    StageView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if store.isCarousel {
                        SlideBar()
                    } else if store.hasPlacedVideo && !(store.tab == .video && store.videoSection == .timeline) {
                        TransportBar()
                    }
                    PanelCard()
                    ToolDock()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

                if let toast = store.toast {
                    ToastView(text: toast.text)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 4)
                        .zIndex(1)
                }
            }
            .navigationTitle("CollageMagik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button { store.openAdd() } label: { Label("Add from Photos", systemImage: "photo.on.rectangle") }
                        Button { store.openFiles() } label: { Label("Add from Files", systemImage: "folder") }
                        Button { store.playback.pause(); store.previewOpen = true } label: {
                            Label("Full screen preview", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                        .disabled(store.placedMediaCount == 0)
                        Divider()
                        Button { store.playback.pause(); libraryOpen = true } label: {
                            Label(library.entries.isEmpty ? "My Library" : "My Library (\(library.entries.count))", systemImage: "photo.stack")
                        }
                        Button { store.helpOpen = true } label: { Label("How it works", systemImage: "questionmark.circle") }
                        Button { aboutOpen = true } label: { Label("About & Privacy", systemImage: "hand.raised") }
                        Divider()
                        Button(role: .destructive) { confirmNew = true } label: { Label("New collage", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More")
                }
                ToolbarItem(placement: .principal) {
                    ModeSwitch { mode in
                        if mode == .carousel && store.videoCount > 0 { confirmCarousel = true } else { store.setMode(mode) }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.playback.pause()
                        store.exportOpen = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(store.placedMediaCount == 0)
                }
            }
        }
        .photosPicker(
            isPresented: $store.showPhotoPicker,
            selection: $store.pickedItems,
            maxSelectionCount: pickLimit,
            selectionBehavior: .ordered,
            matching: store.isCarousel ? .images : .any(of: [.images, .videos])
        )
        .onChange(of: store.pickedItems) { _, picked in
            guard !picked.isEmpty else { return }
            Task {
                await store.importPicked(picked)
                store.pickedItems = []
            }
        }
        .fileImporter(
            isPresented: $store.showFileImporter,
            allowedContentTypes: store.importerIsMusic ? [.audio] : (store.isCarousel ? [.image] : [.image, .movie, .video]),
            allowsMultipleSelection: !store.importerIsMusic
        ) { result in
            guard case .success(let urls) = result else { return }
            Task {
                if store.importerIsMusic, let u = urls.first { await store.importMusic(u) } else { await store.importFiles(urls) }
            }
        }
        .sheet(isPresented: $store.exportOpen) { ExportSheet() }
        .sheet(isPresented: $store.helpOpen) { HelpSheet() }
        .sheet(isPresented: $libraryOpen) { LibrarySheet() }
        .sheet(isPresented: $aboutOpen) { AboutSheet() }
        .fullScreenCover(isPresented: $store.previewOpen) { FullScreenPreview() }
        .fullScreenCover(item: Binding(
            get: { store.cropCell.map(CropTarget.init) },
            set: { store.cropCell = $0?.id }
        )) { target in
            CropEditor(cellIndex: target.id)
        }
        .onChange(of: store.project) { store.playback.projectChanged() }
        #if DEBUG
        .task { await DebugHarness.run(store) }
        #endif
        .confirmationDialog("Switch to Carousel?", isPresented: $confirmCarousel, titleVisibility: .visible) {
            Button("Remove videos and switch", role: .destructive) { withAnimation(.smooth) { store.setMode(.carousel) } }
            Button("Keep my collage", role: .cancel) {}
        } message: {
            Text("Carousels use photos only, so the videos in this collage will be removed.")
        }
        .confirmationDialog("Start a new collage?", isPresented: $confirmNew, titleVisibility: .visible) {
            Button("New collage", role: .destructive) { withAnimation(.smooth) { store.newCollage() } }
        } message: {
            Text("Your current collage will be cleared.")
        }
    }
}

/// The glass card that holds whichever tool is selected.
struct PanelCard: View {
    @Environment(CollageStore.self) private var store

    private var height: CGFloat {
        let pad: CGFloat = 20
        switch store.tab {
        case .media: return 96 + pad
        case .layout: return (store.isCarousel ? 100 : 106) + pad
        case .style: return (store.project.format == .story ? 156 : 124) + pad
        case .video:
            let n = placedLanes(store.project).count
            if n == 0 { return 44 + pad }
            let picker: CGFloat = 40
            switch store.videoSection {
            case .timeline: return picker + timelineContentHeight(lanes: n) + pad + 6
            case .sound: return picker + CGFloat(n) * 36 + (store.project.music == nil ? 34 : 3 * 36) + pad + 4
            }
        case .picture:
            guard let s = store.selectedCell, store.project.cells.indices.contains(s) else { return 44 + pad }
            if store.swapFrom != nil { return 36 + pad }
            return store.project.cells[s].mediaId == nil ? 40 + pad : 108 + pad
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Group {
                switch store.tab {
                case .media: MediaPanel()
                case .layout: LayoutPanel()
                case .style: StylePanel()
                case .video: VideoPanel()
                case .picture: PicturePanel()
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
    }
}
