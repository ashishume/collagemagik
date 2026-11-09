import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(CollageStore.self) private var store
    @State private var confirmNew = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ZStack(alignment: .top) {
                AuroraBackground(paused: store.playback.isPlaying).ignoresSafeArea()

                VStack(spacing: 10) {
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
            maxSelectionCount: store.pickTarget != nil ? 1 : max(1, maxCells - store.items.count),
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
        switch store.tab {
        case .media: 132
        case .layout: 190
        case .style: 226
        case .timeline: 214
        case .audio: 240
        case .picture: 214
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
            .padding(14)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: height)
        .glassEffect(.regular, in: .rect(cornerRadius: 30))
        .animation(.smooth(duration: 0.3), value: store.tab)
    }
}
