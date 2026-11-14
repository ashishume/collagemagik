import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct Toast: Identifiable, Equatable {
    let id: Int
    let text: String
}

/// A movie or picture handed over by the photo picker, copied into the app's own folder.
struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { m in SentTransferredFile(m.url) } importing: { received in
            PickedMovie(url: try MediaLoader.copyIntoApp(received.file))
        }
    }
}

struct PickedImage: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .image) { m in SentTransferredFile(m.url) } importing: { received in
            PickedImage(url: try MediaLoader.copyIntoApp(received.file))
        }
    }
}

@MainActor
@Observable
final class CollageStore {
    var items: [MediaItem] = []
    var project = Project()
    var selectedCell: Int?
    var selectedClip: String?
    var swapFrom: Int?
    /// The caption being styled or moved (shown with a frame in the preview).
    var selectedCaption: String?
    /// The caption whose words are being typed (opens the caption editor).
    var editingCaption: String?
    /// The photo on top being moved or styled (opens the On top panel).
    var selectedOverlay: String?
    var tab: Tab = .media
    var returnTab: Tab = .media
    var videoSection: VideoSection = .timeline
    /// Carousel preview: the slide position at the left edge of the visible area (0 = first slide), and how many slides fit on screen.
    var aboutOpen = false
    var carouselOffset: Double = 0
    var viewportSlides: Double = 1.28
    var importing = false
    /// What the import loader shows ("Adding 2 of 5", progress bar). nil when nothing is being added.
    var importProgress: ImportProgress?
    private var importTask: Task<Void, Never>?
    var toast: Toast?
    var exportOpen = false
    var helpOpen = false
    var previewOpen = false
    var cropCell: Int?
    /// The photo on top open in the crop screen.
    var cropOverlay: String?
    /// The video clip open in the "Choose part" editor.
    var partClip: ClipRef?
    /// The media tray is full: shows an alert that says how to make room. `trayFullSkipped` = how many picked items were not added.
    var showTrayFull = false
    var trayFullSkipped = 0

    // Pickers
    var showPhotoPicker = false
    var showFileImporter = false
    /// The Files importer is shared: it picks music when this is true, photos and videos otherwise.
    var importerIsMusic = false
    /// Cell the next picked media goes into (nil = first free cell).
    var pickTarget: Int?
    /// Photo on top whose picture the next picked photo replaces.
    var pickOverlay: String?
    var pickedItems: [PhotosPickerItem] = []

    let playback = PlaybackEngine()
    private var toastSeq = 0

    // Drafts: the design in progress is saved as you go, so closing the app (or iOS closing it) loses nothing.
    /// The draft this design is saved as.
    private(set) var draftId = newId()
    private var draftCreated = Date()
    /// Every saved draft, newest first (for My Library).
    private(set) var drafts: [DraftSummary] = []
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// What was last written, so opening a draft (or an edit that changes nothing) doesn't save it again.
    @ObservationIgnored private var lastSaved: (project: Project, items: [String])?

    init() {
        playback.store = self
        drafts = DraftDisk.list()
    }

    var totalDuration: Double { CollageMagik.totalDuration(project) }
    var currentLayout: CollageLayout { layout(for: project) }
    /// Most pictures this kind of project holds: 9 in a collage, 10 in a carousel.
    var cellLimit: Int { project.mode == .carousel ? maxCarouselPhotos : maxCells }
    var maxCarouselOffset: Double { max(0, Double(project.slides) - viewportSlides) }
    var isCarousel: Bool { project.mode == .carousel }
    func item(_ id: String) -> MediaItem? { items.first { $0.id == id } }
    var videoCount: Int { items.filter { $0.kind == .video }.count }
    var hasPlacedVideo: Bool { !placedLanes(project).isEmpty }
    var trayIsFull: Bool { items.count >= maxTrayItems }
    /// What the "tray is full" alert says, including where to remove pictures from.
    var trayFullMessage: String {
        let skipped = trayFullSkipped > 0
            ? "\(trayFullSkipped) \(trayFullSkipped == 1 ? "item wasn't" : "items weren't") added. "
            : ""
        return skipped + "Your media tray holds up to \(maxTrayItems) pictures and videos, and it's full. To add more, remove some first: press and hold a picture in the tray at the bottom, then tap Remove."
    }
    var placedMediaCount: Int { project.cells.prefix(project.cellCount).compactMap(\.mediaId).count }

    // MARK: Messages

    func notify(_ text: String) {
        toastSeq += 1
        let id = toastSeq
        withAnimation(.smooth) { toast = Toast(id: id, text: text) }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        Task {
            try? await Task.sleep(for: .seconds(5))
            if toast?.id == id { withAnimation(.smooth) { toast = nil } }
        }
    }

    // MARK: Importing

    /// Nothing can be added while the tray is full: say so (and where to remove from) instead of opening a picker.
    private func refuseIfTrayFull() -> Bool {
        guard trayIsFull else { return false }
        trayFullSkipped = 0
        showTrayFull = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        return true
    }

    func openAdd(cell: Int? = nil, overlay: String? = nil) {
        guard !refuseIfTrayFull() else { return }
        pickTarget = cell
        pickOverlay = overlay
        showPhotoPicker = true
    }

    func openFiles(cell: Int? = nil, overlay: String? = nil) {
        guard !refuseIfTrayFull() else { return }
        pickTarget = cell
        pickOverlay = overlay
        importerIsMusic = false
        showFileImporter = true
    }

    func openMusicImporter() {
        importerIsMusic = true
        showFileImporter = true
    }

    /// Photos picked in the system photo picker. Starts right away (the loader shows at once) and can be cancelled.
    func startPickedImport(_ picked: [PhotosPickerItem]) {
        guard !picked.isEmpty else { return }
        startImport(picked.map { .picker($0) })
    }

    /// Files chosen from the Files app.
    func startFileImport(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        startImport(urls.map { .external($0) })
    }

    private func startImport(_ sources: [ImportSource]) {
        importTask?.cancel()
        // Show the loader before the first await, so the app never looks stuck after the picker closes.
        importProgress = ImportProgress(total: sources.count)
        importing = true
        importTask = Task {
            await addSources(sources)
            importTask = nil
        }
    }

    /// Stops adding: what is already in the tray stays.
    func cancelImport() {
        importTask?.cancel()
    }

    /// Files already in the app's own folder (also used by the debug harness).
    func addFiles(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        await addSources(urls.map { .local($0) })
    }

    /// Adds photos and videos one by one, updating `importProgress` ("Adding 2 of 5") as each item is fetched and read.
    private func addSources(_ sources: [ImportSource]) async {
        guard !sources.isEmpty else { return }
        importing = true
        if importProgress == nil { importProgress = ImportProgress(total: sources.count) }
        defer {
            importing = false
            withAnimation(.smooth) { importProgress = nil }
        }
        let fresh = items.isEmpty
        // replacing a picture (in a cell or on top) leaves the layout and the open tool alone
        let replacing = pickOverlay != nil || (pickTarget.map { project.cells.indices.contains($0) && project.cells[$0].mediaId != nil } ?? false)
        var target = pickTarget
        var overlayTarget = pickOverlay
        var added = 0
        var leftInTray = 0
        var skippedForTray = 0
        var problems: [String] = []
        var cancelled = false
        pickTarget = nil
        pickOverlay = nil
        func skip(_ text: String) {
            problems.append(text)
            notify(text)
        }
        for (index, source) in sources.enumerated() {
            if Task.isCancelled { cancelled = true; break }
            let kindHint = source.kindHint
            let label = source.label
            let noun = kindHint == .video ? "video" : "photo"
            importProgress?.start(item: index + 1, detail: "\(source.fetchVerb) \(noun)…")
            #if DEBUG
            if let ms = ProcessInfo.processInfo.environment["CM_IMPORT_SLOW_MS"].flatMap(Int.init) { try? await Task.sleep(for: .milliseconds(ms)) }
            #endif

            // Rules that don't need the file: checked first, so nothing is downloaded only to be refused.
            if kindHint == nil {
                skip("\(label): only photos and videos can be added.")
                continue
            }
            if kindHint == .video && isCarousel {
                skip("Carousels use photos only. Switch to Collage to add videos.")
                continue
            }
            if items.count >= maxTrayItems {
                skippedForTray = sources.count - index
                break
            }
            if kindHint == .video && videoCount >= maxVideos {
                skip("Only \(maxVideos) videos per collage. Remove one to add another.")
                continue
            }

            // 1. Get the file into the app's folder (from Photos / iCloud this can take a while for videos).
            let url: URL
            do {
                url = try await source.resolve { [weak self] f in
                    guard let self, self.importProgress?.current == index + 1 else { return }
                    self.importProgress?.update(
                        fraction: f * 0.85,
                        detail: f < 1 ? "\(source.fetchVerb) \(noun)… \(Int((f * 100).rounded()))%" : "\(source.fetchVerb) \(noun)…"
                    )
                }
            } catch {
                if Task.isCancelled || (error as? CocoaError)?.code == .userCancelled { cancelled = true; break }
                skip("\(label) couldn't be read: \(error.localizedDescription)")
                continue
            }
            if Task.isCancelled { cancelled = true; break }

            // 2. Check it plays here and make its thumbnails.
            let kind = MediaLoader.kind(of: url)
            importProgress?.update(fraction: 0.88, detail: kind == .video ? "Preparing video…" : "Preparing photo…")
            if kind == nil {
                skip("\(url.lastPathComponent): only photos and videos can be added.")
                continue
            }
            if kind == .video && isCarousel {
                skip("Carousels use photos only. Switch to Collage to add videos.")
                continue
            }
            if kind == .video && videoCount >= maxVideos {
                skip("Only \(maxVideos) videos per collage. Remove one to add another.")
                continue
            }
            let name = source.name ?? url.deletingPathExtension().lastPathComponent
            let item: MediaItem
            do {
                item = try await MediaLoader.load(url: url, name: name)
            } catch {
                skip(error.localizedDescription)
                continue
            }
            if Task.isCancelled { cancelled = true; break }
            items.append(item)
            if item.kind == .video {
                project.lanes.append(newLane(mediaId: item.id, duration: item.duration, volume: project.lanes.isEmpty ? 1 : 0))
            }
            if let o = overlayTarget, item.kind == .photo, overlay(o) != nil {
                // "Change" on a photo on top: the new photo takes its place in the same print
                replaceOverlayMedia(o, with: item.id)
                overlayTarget = nil
                added += 1
                importProgress?.finishItem(added: added)
                continue
            }
            // The collage only has room for `cellLimit` pictures. The rest wait in the tray to be swapped in.
            if !placeMedia(item.id, cell: target, quiet: true) { leftInTray += 1 }
            target = nil
            added += 1
            importProgress?.finishItem(added: added)
        }
        if cancelled {
            notify(added == 0 ? "Adding stopped. Nothing was added." : "Adding stopped. \(added) of \(sources.count) added.")
        } else if !problems.isEmpty, skippedForTray == 0 {
            let first = problems.count == 1 ? problems[0] : "\(problems.count) items couldn't be added. \(problems[0])"
            notify("\(added) of \(sources.count) added. " + first)
        }
        if cancelled || !problems.isEmpty, skippedForTray == 0 {
            // the summary above already said what happened
        } else if skippedForTray > 0 {
            trayFullSkipped = skippedForTray
            showTrayFull = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } else if leftInTray > 0 {
            notify("The \(isCarousel ? "carousel" : "collage") is full (\(cellLimit)). \(leftInTray == 1 ? "1 picture is" : "\(leftInTray) pictures are") in your tray: tap a cell, then a tray picture, to swap it in.")
        }
        // The collage follows the selection: pick N photos / videos and you get an N-cell collage, with the
        // formats for N cells ready to choose from. (A single add to a collage already in progress leaves it alone.)
        if !replacing, added > 0, fresh || added >= 2 {
            let lastFilled = project.cells.lastIndex { $0.mediaId != nil } ?? 0
            setCellCount(lastFilled + 1)
            if isCarousel {
                // the slide count follows the pictures on its own; start in the style that suits that many
                project.layoutId = defaultLayoutId(for: project)
                carouselOffset = 0
            }
            if added >= 2 {
                selectedCell = nil
                swapFrom = nil
            }
        }
        // When the selection is done, land on the tool that matters most: the timeline if there is a video to cut,
        // otherwise the layouts for the new cell count.
        if !replacing, added > 0 {
            if hasPlacedVideo {
                openVideo(.timeline)
            } else if added >= 2 {
                withAnimation(.smooth) { tab = .layout }
            }
        }
        playback.projectChanged()
    }

    func importMusic(_ url: URL) async {
        let local: URL
        do { local = try MediaLoader.copyIntoApp(url) } catch {
            notify("\(url.lastPathComponent): couldn't be read.")
            return
        }
        let name = url.deletingPathExtension().lastPathComponent
        do {
            let duration = try await MediaLoader.loadMusic(url: local, name: name)
            let prev = project.music
            project.music = MusicTrack(
                url: local, name: name, duration: duration,
                volume: (prev?.volume ?? 0) > 0 ? prev!.volume : 0.7,
                start: 0, inPoint: 0, outPoint: min(duration, maxDuration),
                // a song shorter than the collage repeats by default
                loop: duration < totalDuration,
                fadeOut: prev?.fadeOut ?? true
            )
            selectedClip = musicClipId
        } catch {
            notify(error.localizedDescription)
        }
    }

    // MARK: Cells

    @discardableResult
    func placeMedia(_ mediaId: String, cell: Int? = nil, quiet: Bool = false) -> Bool {
        var cells = project.cells.map { $0.mediaId == mediaId ? CellState() : $0 }
        var count = project.cellCount
        var idx = cell ?? cells.firstIndex { $0.mediaId == nil } ?? -1
        if idx == -1 {
            if count >= cellLimit {
                if !quiet { notify("The \(isCarousel ? "carousel" : "collage") is full (\(cellLimit)). Tap a cell first, then tap a tray picture to swap it in.") }
                return false
            }
            count += 1
            cells.append(CellState())
            idx = count - 1
        }
        cells[idx] = CellState(mediaId: mediaId)
        project.cells = cells
        if count != project.cellCount {
            project.cellCount = count
            project.layoutId = defaultLayoutId(for: project)
        }
        project.cellCount = count
        clampCarouselOffset()
        selectedCell = idx
        return true
    }

    func removeMedia(_ mediaId: String) {
        playback.dispose(mediaId)
        items.removeAll { $0.id == mediaId }
        project.cells = project.cells.map { $0.mediaId == mediaId ? CellState() : $0 }
        project.lanes.removeAll { $0.mediaId == mediaId }
        project.overlays.removeAll { $0.mediaId == mediaId }
        if let s = selectedOverlay, overlay(s) == nil { selectOverlay(nil) }
        selectedClip = nil
    }

    func clearCell(_ cell: Int) {
        guard project.cells.indices.contains(cell) else { return }
        project.cells[cell] = CellState()
    }

    func swapCells(_ a: Int, _ b: Int) {
        guard project.cells.indices.contains(a), project.cells.indices.contains(b) else { return }
        project.cells.swapAt(a, b)
        selectedCell = b
        swapFrom = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func setCellView(_ cell: Int, _ patch: (inout CellState) -> Void) {
        guard project.cells.indices.contains(cell) else { return }
        var c = project.cells[cell]
        patch(&c)
        c.zoom = clamp(c.zoom, 1, 4)
        c.panX = clamp(c.panX, -1, 1)
        c.panY = clamp(c.panY, -1, 1)
        let turns = Int((c.rotation / 90).rounded())
        c.rotation = Double(((turns * 90) % 360 + 360) % 360)
        c.angle = clamp(c.angle, -45, 45)
        project.cells[cell] = c
    }

    func applyView(_ cell: Int, _ v: MediaView) {
        setCellView(cell) {
            $0.zoom = v.zoom; $0.panX = v.panX; $0.panY = v.panY
            $0.rotation = v.rotation; $0.flip = v.flip; $0.angle = v.angle
        }
    }

    func resetCell(_ cell: Int) { applyView(cell, MediaView()) }

    func rotateCell(_ cell: Int, dir: Double = 1) {
        setCellView(cell) { $0.rotation += 90 * dir; $0.panX = 0; $0.panY = 0 }
    }

    func flipCell(_ cell: Int) {
        setCellView(cell) { $0.flip.toggle(); $0.panX = -$0.panX }
    }

    // MARK: Layout & style

    func setCellCount(_ n: Int) {
        let count = min(max(n, 1), cellLimit)
        var cells = project.cells
        if cells.count > count { cells = Array(cells.prefix(count)) }
        while cells.count < count { cells.append(CellState()) }
        // keep the chosen layout if it still fits this many pictures
        let keep: Bool
        if isCarousel {
            keep = carouselStyle(of: project.layoutId).map { carouselStyles(for: count).contains($0) } ?? false
        } else {
            keep = layout(byId: project.layoutId).count == count
        }
        project.cells = cells
        project.cellCount = count
        if !keep { project.layoutId = defaultLayoutId(for: project) }
        if let s = selectedCell, s >= count { selectedCell = nil }
        swapFrom = nil
        clampCarouselOffset()
    }

    func setLayout(_ id: String) {
        project.layoutId = id
        clampCarouselOffset()
    }

    /// The slide count is automatic, so it can shrink when the style or the pictures change: keep the preview inside it.
    func clampCarouselOffset() {
        guard isCarousel else { return }
        carouselOffset = min(carouselOffset, maxCarouselOffset)
    }

    /// Scrolls the carousel preview so slide `index` is at the left edge (or as far as it can go).
    func focusSlide(_ index: Int) {
        withAnimation(.smooth(duration: 0.35)) { carouselOffset = min(Double(index), maxCarouselOffset) }
    }

    /// After a swipe: `v` is how fast the view was moving, in slides per second (positive = towards later slides). Settle on a whole slide (the last stop is wherever the final slide ends flush with the right edge).
    func settleCarousel(velocitySlidesPerSecond v: Double = 0) {
        let stops = (0...Int(maxCarouselOffset.rounded(.down))).map(Double.init) + (maxCarouselOffset.truncatingRemainder(dividingBy: 1) > 0.01 ? [maxCarouselOffset] : [])
        let aim = carouselOffset + v * 0.12
        let target = stops.min { abs($0 - aim) < abs($1 - aim) } ?? 0
        withAnimation(.smooth(duration: 0.3)) { carouselOffset = target }
    }

    /// Slide the visible area is mostly showing (1-based).
    var visibleSlide: Int { min(project.slides, Int(carouselOffset.rounded()) + 1) }

    /// Switches between Collage and Carousel. Pictures carry over (in order); videos can't, they are removed.
    func setMode(_ mode: EditMode) {
        guard mode != project.mode else { return }
        playback.pause()
        playback.playhead = 0
        if mode == .carousel {
            for v in items where v.kind == .video { removeMedia(v.id) }
            if project.format == .story { project.format = .post }
        }
        project.mode = mode
        let ids = items.map(\.id)
        // The cells take the first pictures that fit; any others stay in the tray, not deleted.
        let n = ids.isEmpty ? (mode == .carousel ? initialCarouselCells : initialCellCount) : min(ids.count, cellLimit)
        project.cellCount = n
        project.cells = (0..<n).map { CellState(mediaId: ids.indices.contains($0) ? ids[$0] : nil) }
        project.layoutId = defaultLayoutId(for: project)
        selectedCell = nil
        selectedClip = nil
        swapFrom = nil
        selectedCaption = nil
        if tab == .overlay { tab = .layout }
        selectedOverlay = nil
        // captions stay; any that were further right than the design now reaches move back onto it
        for c in project.captions { updateCaption(c.id) { _ in } }
        for o in project.overlays { updateOverlay(o.id) { _ in } }
        carouselOffset = 0
        if tab == .picture || (tab == .video && mode == .carousel) { tab = .layout }
        playback.projectChanged()
    }

    /// "Try another": a random style has a new arrangement dealt; any other style jumps to a different one.
    func shuffleLayout() {
        if isCarousel, project.carouselStyleInUse.isRandom {
            let current = carouselSeed(of: project.layoutId)
            var seed = Int.random(in: 1...9999)
            while seed == current { seed = Int.random(in: 1...9999) }
            project.layoutId = carouselLayoutId(project.carouselStyleInUse, seed: seed)
        } else {
            let options = layoutOptions(for: project).filter { $0.id != project.layoutId }
            if let pick = options.randomElement() { project.layoutId = pick.id }
        }
        clampCarouselOffset()
    }

    // MARK: Selection

    func selectCell(_ i: Int?) {
        selectedCell = i
        if i != nil { selectedCaption = nil; if selectedOverlay != nil { selectOverlay(nil) } }
        if i == nil && tab == .picture {
            tab = returnTab
            swapFrom = nil
        }
    }

    func openPicture() {
        if tab.inDock { returnTab = tab }
        withAnimation(.smooth) { tab = .picture }
    }

    /// Clears every selection (picture, photo on top, caption) and leaves the panels that belong to it.
    func deselectAll() {
        if selectedCaption != nil { selectCaption(nil) }
        if selectedOverlay != nil { selectOverlay(nil) }
        if selectedCell != nil || swapFrom != nil { swapFrom = nil; selectCell(nil) }
    }

    /// A dock tab was chosen. Its panel edits the whole design, so nothing stays selected (otherwise a selected photo
    /// would look as if it were being edited). The Media tray keeps the selection: tapping a tray photo replaces it.
    func dockTabChanged(_ t: Tab) {
        guard t.inDock else { return }
        if t != .text { selectedCaption = nil }
        if t != .media {
            selectedCell = nil
            swapFrom = nil
            selectedOverlay = nil
        }
    }

    // MARK: Video tools

    /// Opens the video timeline (or sound) panel. It is not in the dock: it opens from the bar under the preview, or
    /// from a selected video.
    func openVideo(_ section: VideoSection = .timeline) {
        guard hasPlacedVideo else { return }
        if tab.inDock { returnTab = tab }
        videoSection = section
        withAnimation(.smooth) { tab = .video }
    }

    /// Leaves the video panel: back to the selected picture's options, or to the tab that was open.
    func closeVideo() {
        withAnimation(.smooth) { tab = selectedCell != nil ? .picture : returnTab }
    }

    // MARK: Photos on top

    func overlay(_ id: String?) -> PhotoOverlay? { id.flatMap { id in project.overlays.first { $0.id == id } } }

    /// Selects a photo on top and opens its panel (nil closes it and goes back to the tab that was open).
    func selectOverlay(_ id: String?) {
        selectedOverlay = id
        if id != nil {
            selectedCell = nil
            swapFrom = nil
            selectedCaption = nil
            if tab.inDock { returnTab = tab }
            withAnimation(.smooth) { tab = .overlay }
        } else if tab == .overlay {
            withAnimation(.smooth) { tab = returnTab }
        }
    }

    /// Lays a photo from the tray on top of the design, centred at (cx, cy) (cx in slide widths, cy 0...1).
    /// It takes the frame of the last photo on top, so a set of prints matches, and a little tilt, like a print dropped on a table.
    @discardableResult
    func addOverlay(_ mediaId: String, cx: Double? = nil, cy: Double? = nil) -> Bool {
        guard let item = item(mediaId) else { return false }
        guard item.kind == .photo else {
            notify("Only photos can go on top. Videos play in the layout's cells.")
            return false
        }
        guard project.overlays.count < maxOverlays else {
            notify("Up to \(maxOverlays) photos fit on top of one design. Remove one to add another.")
            return false
        }
        let n = project.overlays.count
        let like = project.overlays.last
        var o = PhotoOverlay(
            mediaId: mediaId,
            cx: cx ?? (isCarousel ? Double(visibleSlide - 1) + 0.5 : 0.5) + Double(n % 3) * 0.06,
            cy: cy ?? 0.5 + Double(n % 3) * 0.05,
            w: like?.w ?? 0.46,
            tilt: [-5, 4, -2, 6, -4, 3][n % 6]
        )
        o.frame = like?.frame ?? .border
        o.frameColor = like?.frameColor ?? "#ffffff"
        project.overlays.append(o)
        updateOverlay(o.id) { _ in }
        selectOverlay(o.id)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return true
    }

    func updateOverlay(_ id: String, _ patch: (inout PhotoOverlay) -> Void) {
        guard let i = project.overlays.firstIndex(where: { $0.id == id }) else { return }
        var o = project.overlays[i]
        patch(&o)
        o.cx = clamp(o.cx, 0, Double(project.slides))
        o.cy = clamp(o.cy, 0, 1)
        o.w = clamp(o.w, overlayWidthRange.lowerBound, overlayWidthRange.upperBound)
        o.tilt = clamp(o.tilt, -180, 180)
        o.zoom = clamp(o.zoom, 1, 4)
        o.panX = clamp(o.panX, -1, 1)
        o.panY = clamp(o.panY, -1, 1)
        let turns = Int((o.rotation / 90).rounded())
        o.rotation = Double(((turns * 90) % 360 + 360) % 360)
        o.angle = clamp(o.angle, -45, 45)
        project.overlays[i] = o
    }

    /// Turns the photo on top a quarter turn; the print turns with it, keeping its width.
    func rotateOverlay(_ id: String, dir: Double = 1) {
        updateOverlay(id) { $0.rotation += 90 * dir; $0.panX = 0; $0.panY = 0 }
    }

    func flipOverlay(_ id: String) {
        updateOverlay(id) { $0.flip.toggle(); $0.panX = -$0.panX }
    }

    func applyOverlayView(_ id: String, _ v: MediaView) {
        updateOverlay(id) { $0.apply(v) }
    }

    /// Zoom, position, rotation, flip and straighten back to the photo as it was laid down.
    func resetOverlayView(_ id: String) { applyOverlayView(id, MediaView()) }

    /// Puts another photo in the same print (same place, size, tilt and frame).
    func replaceOverlayMedia(_ id: String, with mediaId: String) {
        guard let item = item(mediaId) else { return }
        guard item.kind == .photo else {
            notify("Only photos can go on top. Videos play in the layout's cells.")
            return
        }
        updateOverlay(id) { $0.mediaId = mediaId; $0.apply(MediaView()) }
    }

    func removeOverlay(_ id: String) {
        project.overlays.removeAll { $0.id == id }
        if selectedOverlay == id { selectOverlay(nil) }
    }

    func duplicateOverlay(_ id: String) {
        guard let src = overlay(id) else { return }
        guard project.overlays.count < maxOverlays else {
            notify("Up to \(maxOverlays) photos fit on top of one design. Remove one to add another.")
            return
        }
        var o = src
        o.id = UUID().uuidString
        o.cx += 0.06
        o.cy += 0.04
        o.tilt = -src.tilt
        project.overlays.append(o)
        updateOverlay(o.id) { _ in }
        selectOverlay(o.id)
    }

    /// Moves a photo on top one step up (towards the viewer) or down in the pile.
    func restackOverlay(_ id: String, up: Bool) {
        guard let i = project.overlays.firstIndex(where: { $0.id == id }) else { return }
        let j = up ? i + 1 : i - 1
        guard project.overlays.indices.contains(j) else { return }
        project.overlays.swapAt(i, j)
    }

    // MARK: Captions

    func caption(_ id: String?) -> Caption? { id.flatMap { id in project.captions.first { $0.id == id } } }

    func selectCaption(_ id: String?) {
        if id != nil {
            if selectedCell != nil { selectCell(nil) }
            swapFrom = nil
            if tab != .text { withAnimation(.smooth) { tab = .text } }
        }
        if id != nil, selectedOverlay != nil { selectOverlay(nil) }
        if id != selectedCaption {
            selectedCaption = id
            if id != nil { UISelectionFeedbackGenerator().selectionChanged() }
        }
    }

    /// Adds an empty caption in the middle of the slide on screen and opens the keyboard. It copies the look of the
    /// caption that was selected (or the last one), so a set of captions matches without restyling each.
    func addCaption() {
        guard project.captions.count < maxCaptions else {
            notify("Up to \(maxCaptions) captions fit on one design. Remove one to add another.")
            return
        }
        var c = Caption()
        if let like = caption(selectedCaption) ?? project.captions.last {
            c.font = like.font; c.color = like.color; c.look = like.look; c.align = like.align; c.size = like.size; c.accentFont = like.accentFont
        }
        c.x = isCarousel ? Double(visibleSlide - 1) + 0.5 : 0.5
        // each new caption starts a little lower than the last, so they don't land on top of each other
        let taken = project.captions.filter { abs($0.x - c.x) < 0.05 }.map(\.y)
        var y = 0.5
        while taken.contains(where: { abs($0 - y) < 0.04 }) && y < 0.86 { y += 0.09 }
        c.y = y
        project.captions.append(c)
        selectCaption(c.id)
        editingCaption = c.id
    }

    func updateCaption(_ id: String, _ patch: (inout Caption) -> Void) {
        guard let i = project.captions.firstIndex(where: { $0.id == id }) else { return }
        var c = project.captions[i]
        patch(&c)
        if c.text.count > maxCaptionLength { c.text = String(c.text.prefix(maxCaptionLength)) }
        c.size = clamp(c.size, captionSizeRange.lowerBound, captionSizeRange.upperBound)
        c.x = clamp(c.x, 0, Double(max(1, project.slides)))
        c.y = clamp(c.y, 0, 1)
        // keep the angle in -180...180
        c.rotation = (c.rotation + 540).truncatingRemainder(dividingBy: 360) - 180
        project.captions[i] = c
    }

    func removeCaption(_ id: String) {
        project.captions.removeAll { $0.id == id }
        if selectedCaption == id { selectedCaption = nil }
        if editingCaption == id { editingCaption = nil }
    }

    func duplicateCaption(_ id: String) {
        guard let src = caption(id) else { return }
        guard project.captions.count < maxCaptions else {
            notify("Up to \(maxCaptions) captions fit on one design. Remove one to add another.")
            return
        }
        var c = src
        c.id = UUID().uuidString
        c.y = src.y < 0.85 ? src.y + 0.08 : src.y - 0.08
        project.captions.append(c)
        selectCaption(c.id)
    }

    /// The keyboard was closed: a caption left without words is thrown away.
    func finishEditingCaption() {
        guard let id = editingCaption else { return }
        editingCaption = nil
        updateCaption(id) { $0.text = $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
        if caption(id)?.text.isEmpty ?? true { removeCaption(id) }
    }

    // MARK: Timeline editing

    func setLane(_ mediaId: String, _ patch: (inout Lane) -> Void) {
        guard let i = project.lanes.firstIndex(where: { $0.mediaId == mediaId }) else { return }
        patch(&project.lanes[i])
    }

    func updateClip(mediaId: String, clipId: String, _ fn: (Clip) -> Clip) {
        guard let li = project.lanes.firstIndex(where: { $0.mediaId == mediaId }),
              let ci = project.lanes[li].clips.firstIndex(where: { $0.id == clipId }) else { return }
        project.lanes[li].clips[ci] = fn(project.lanes[li].clips[ci])
    }

    func splitAtPlayhead() {
        let playhead = playback.playhead
        if selectedClip == musicClipId {
            notify("Split works on video clips. Trim the music with its ends instead.")
            return
        }
        var target: (lane: Int, clip: Clip)?
        for (li, lane) in project.lanes.enumerated() {
            for clip in lane.clips {
                let under = playhead > clip.start && playhead < clip.end
                if clip.id == selectedClip && under { target = (li, clip) }
                else if target == nil && selectedClip == nil && under { target = (li, clip) }
            }
        }
        guard let t = target else {
            notify("Move the playhead over a clip to cut it there.")
            return
        }
        guard let parts = splitClip(t.clip, playhead) else {
            notify("Move the playhead a little further from the clip edge.")
            return
        }
        project.lanes[t.lane].clips = project.lanes[t.lane].clips.flatMap { $0.id == t.clip.id ? [parts.0, parts.1] : [$0] }
        selectedClip = parts.1.id
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    func deleteSelectedClip() {
        guard let sel = selectedClip else {
            notify("Tap a clip on the timeline first.")
            return
        }
        if sel == musicClipId {
            removeMusic()
            return
        }
        guard let li = project.lanes.firstIndex(where: { $0.clips.contains { $0.id == sel } }) else { return }
        if project.lanes[li].clips.count <= 1 {
            notify("A video needs at least one clip. Use Remove on its cell to take it out.")
            return
        }
        project.lanes[li].clips.removeAll { $0.id == sel }
        selectedClip = nil
    }

    /// The selected video clip, or the one under the playhead, or the only one there is.
    func targetClip() -> ClipRef? {
        let lanes = placedLanes(project)
        if let sel = selectedClip, let lane = lanes.first(where: { $0.clips.contains { $0.id == sel } }) {
            return ClipRef(mediaId: lane.mediaId, clipId: sel)
        }
        let t = playback.playhead
        for lane in lanes { if let c = lane.clips.first(where: { t >= $0.start && t < $0.end }) { return ClipRef(mediaId: lane.mediaId, clipId: c.id) } }
        let all = lanes.flatMap { l in l.clips.map { ClipRef(mediaId: l.mediaId, clipId: $0.id) } }
        return all.count == 1 ? all[0] : nil
    }

    func clip(_ ref: ClipRef) -> Clip? {
        project.lanes.first { $0.mediaId == ref.mediaId }?.clips.first { $0.id == ref.clipId }
    }

    /// Opens the editor that picks which part of the video a clip plays.
    func openChoosePart() {
        guard let ref = targetClip() else {
            notify(selectedClip == musicClipId ? "Choose part works on video clips. Drag the music's ends to trim it." : "Tap a clip on the timeline first.")
            return
        }
        playback.pause()
        selectedClip = ref.clipId
        partClip = ref
    }

    func duplicateSelectedClip() {
        guard let ref = targetClip(), let c = clip(ref) else {
            notify("Tap a clip on the timeline first.")
            return
        }
        guard let copy = duplicateClip(c) else {
            notify("There's no room left in the \(Int(maxDuration))-second collage for a copy.")
            return
        }
        setLane(ref.mediaId) { $0.clips.append(copy) }
        selectedClip = copy.id
        playback.seek(to: copy.start)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    /// Plays the whole video again (or its first 60 seconds), from where the clip starts.
    func resetSelectedClip() {
        guard let ref = targetClip(), let item = item(ref.mediaId) else {
            notify("Tap a clip on the timeline first.")
            return
        }
        updateClip(mediaId: ref.mediaId, clipId: ref.clipId) { choosePart($0, inPoint: 0, outPoint: item.duration, mediaDuration: item.duration) }
        selectedClip = ref.clipId
    }

    func removeMusic() {
        project.music = nil
        if selectedClip == musicClipId { selectedClip = nil }
    }

    /// Starts over, as a collage or a carousel. With no mode given the current mode is kept. The design in progress
    /// stays in Drafts (unless `keepDraft` is false, when it has just been deleted).
    func newCollage(mode newMode: EditMode? = nil, keepDraft: Bool = true) {
        if keepDraft { saveDraftNow() } else { saveTask?.cancel() }
        draftId = newId()
        draftCreated = Date()
        lastSaved = nil
        playback.pause()
        playback.playhead = 0
        for i in items { playback.dispose(i.id) }
        items = []
        // without a mode given, a new carousel stays a carousel
        let mode = newMode ?? project.mode
        project = Project()
        if mode == .carousel {
            project.mode = .carousel
            project.format = .post
            project.cellCount = initialCarouselCells
            project.cells = Array(repeating: CellState(), count: initialCarouselCells)
            project.layoutId = defaultLayoutId(for: project)
        }
        carouselOffset = 0
        selectedCell = nil
        selectedClip = nil
        swapFrom = nil
        selectedCaption = nil
        editingCaption = nil
        selectedOverlay = nil
        tab = .media
        playback.projectChanged()
    }
}

// MARK: - Drafts

extension CollageStore {
    /// True when there is something worth keeping.
    var hasContent: Bool {
        !items.isEmpty || project.captions.contains { !$0.text.isEmpty } || project.music != nil
    }

    /// Saves a moment after the last change (edits come in bursts: a drag is dozens of changes).
    func scheduleDraftSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, let self else { return }
            if self.importing { self.scheduleDraftSave(); return }
            self.saveDraftNow()
        }
    }

    /// Saves the design now (the files are written in the background). An empty design removes its draft.
    func saveDraftNow() {
        saveTask?.cancel()
        let id = draftId
        guard hasContent else {
            if lastSaved != nil || drafts.contains(where: { $0.id == id }) {
                lastSaved = nil
                DraftDisk.queue.async {
                    DraftDisk.remove(id)
                    Task { @MainActor [weak self] in self?.refreshDrafts() }
                }
            }
            return
        }
        let ids = items.map(\.id)
        if let last = lastSaved, last.project == project, last.items == ids { return }
        lastSaved = (project, ids)
        let project = project
        let created = draftCreated
        let media = items.map { DraftDisk.Media(id: $0.id, isVideo: $0.kind == .video, url: $0.url, name: $0.name) }
        let thumb = DraftDisk.thumbnail(project: project, items: items)
        DraftDisk.queue.async {
            try? DraftDisk.write(id: id, createdAt: created, project: project, items: media, thumb: thumb)
            Task { @MainActor [weak self] in self?.refreshDrafts() }
        }
    }

    func refreshDrafts() {
        DraftDisk.queue.async {
            let list = DraftDisk.list()
            Task { @MainActor [weak self] in self?.drafts = list }
        }
    }

    /// On launch: carries on with the last design, if there is one.
    func restoreLastDraft() async {
        #if DEBUG
        // the debug harness sets up its own design
        let env = ProcessInfo.processInfo.environment
        if env["CM_AUTOLOAD"] != nil || env["CM_DEMO"] != nil || env["CM_IMPORT"] != nil { return }
        #endif
        guard !hasContent, let latest = DraftDisk.list().first else { return }
        await openDraft(latest.id)
    }

    /// Opens a saved draft in place of the current design (which is saved first).
    func openDraft(_ id: String) async {
        if id == draftId && hasContent { return }
        saveDraftNow()
        let file: DraftFile
        do { file = try DraftDisk.read(id) } catch {
            notify("This draft couldn't be opened.")
            return
        }
        let mediaDir = DraftDisk.media(id)
        playback.pause()
        for i in items { playback.dispose(i.id) }
        importProgress = ImportProgress(total: file.items.count, heading: "Opening your draft")
        importing = true
        var loaded: [MediaItem] = []
        for (i, d) in file.items.enumerated() {
            importProgress?.start(item: i + 1, detail: d.isVideo ? "Reading video…" : "Reading photo…")
            if let item = try? await MediaLoader.load(url: mediaDir.appendingPathComponent(d.file), name: d.name, id: d.id) {
                loaded.append(item)
            }
            importProgress?.finishItem(added: loaded.count)
        }
        var p = file.project
        // anything whose file couldn't be read leaves the design
        let ids = Set(loaded.map(\.id))
        for i in p.cells.indices where p.cells[i].mediaId.map({ !ids.contains($0) }) ?? false { p.cells[i].mediaId = nil }
        p.lanes.removeAll { !ids.contains($0.mediaId) }
        p.overlays.removeAll { !ids.contains($0.mediaId) }
        if let mf = file.musicFile, FileManager.default.fileExists(atPath: mediaDir.appendingPathComponent(mf).path) {
            p.music?.url = mediaDir.appendingPathComponent(mf)
        } else {
            p.music = nil
        }
        items = loaded
        project = p
        draftId = file.id
        draftCreated = file.createdAt
        lastSaved = (p, loaded.map(\.id))
        selectedCell = nil
        selectedClip = nil
        swapFrom = nil
        selectedCaption = nil
        editingCaption = nil
        selectedOverlay = nil
        carouselOffset = 0
        playback.playhead = 0
        tab = .media
        importing = false
        withAnimation(.smooth) { importProgress = nil }
        playback.projectChanged()
        if loaded.count < file.items.count {
            let missing = file.items.count - loaded.count
            notify("\(missing) \(missing == 1 ? "item" : "items") in this draft couldn't be read and \(missing == 1 ? "was" : "were") left out.")
        }
    }

    /// Deletes a draft. Deleting the one that is open starts a new design.
    func deleteDraft(_ id: String) {
        if id == draftId { newCollage(keepDraft: false) }
        drafts.removeAll { $0.id == id }
        DraftDisk.queue.async {
            DraftDisk.remove(id)
            Task { @MainActor [weak self] in self?.refreshDrafts() }
        }
    }
}
