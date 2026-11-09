import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(CollageStore.self) private var store
    @State private var confirmNew = false

    /// Replacing a picture takes one item; adding to the collage (or filling an empty cell) takes as many as there is room for.
    private var pickLimit: Int {
        if let t = store.pickTarget, store.project.cells.indices.contains(t), store.project.cells[t].mediaId != nil { return 1 }
        return max(1, maxCells - store.items.count)
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ZStack(alignment: .top) {
                AuroraBackground(paused: store.playback.isPlaying).ignoresSafeArea()

                VStack(spacing: 6) {
                    StageView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if store.hasPlacedVideo && store.tab != .timeline {
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
                        Button { store.helpOpen = true } label: { Label("How it works", systemImage: "questionmark.circle") }
                        Button(role: .destructive) { confirmNew = true } label: { Label("New collage", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.playback.pause()
                        store.previewOpen = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .disabled(store.placedMediaCount == 0)
                    .accessibilityLabel("Full screen preview")
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
            matching: .any(of: [.images, .videos])
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
            allowedContentTypes: store.importerIsMusic ? [.audio] : [.image, .movie, .video],
            allowsMultipleSelection: !store.importerIsMusic
        ) { result in
            guard case .success(let urls) = result else { return }
            Task {
                if store.importerIsMusic, let u = urls.first { await store.importMusic(u) } else { await store.importFiles(urls) }
            }
        }
        .sheet(isPresented: $store.exportOpen) { ExportSheet() }
        .sheet(isPresented: $store.helpOpen) { HelpSheet() }
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
        case .layout: return 106 + pad
        case .style: return (store.project.format == .story ? 156 : 124) + pad
        case .timeline:
            let n = placedLanes(store.project).count
            return n == 0 ? 44 + pad : timelineContentHeight(lanes: n) + pad + 6
        case .audio:
            let n = placedLanes(store.project).count
            if n == 0 { return 44 + pad }
            return CGFloat(n) * 36 + (store.project.music == nil ? 34 : 3 * 36) + pad + 4
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
                case .timeline: TimelinePanel()
                case .audio: AudioPanel()
                case .picture: PicturePanel()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(10)
        }
        .scrollBounceBehavior(.basedOnSize)
        // the timeline owns every drag inside it; the card must not scroll under the finger
        .scrollDisabled(store.tab == .timeline)
        .frame(height: height)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .animation(.smooth(duration: 0.3), value: store.tab)
    }
}
