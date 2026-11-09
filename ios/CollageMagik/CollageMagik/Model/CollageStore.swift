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
    var tab: Tab = .media
    var returnTab: Tab = .media
    var importing = false
    var toast: Toast?
    var exportOpen = false
    var helpOpen = false
    var cropCell: Int?

    // Pickers
    var showPhotoPicker = false
    var showFileImporter = false
    /// The Files importer is shared: it picks music when this is true, photos and videos otherwise.
    var importerIsMusic = false
    /// Cell the next picked media goes into (nil = first free cell).
    var pickTarget: Int?
    var pickedItems: [PhotosPickerItem] = []

    let playback = PlaybackEngine()
    private var toastSeq = 0

    init() {
        playback.store = self
    }

    var totalDuration: Double { CollageMagik.totalDuration(project) }
    var currentLayout: CollageLayout { layout(byId: project.layoutId) }
    func item(_ id: String) -> MediaItem? { items.first { $0.id == id } }
    var videoCount: Int { items.filter { $0.kind == .video }.count }
    var hasPlacedVideo: Bool { !placedLanes(project).isEmpty }
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

    func openAdd(cell: Int? = nil) {
        pickTarget = cell
        showPhotoPicker = true
    }

    func openFiles(cell: Int? = nil) {
        pickTarget = cell
        importerIsMusic = false
        showFileImporter = true
    }

    func openMusicImporter() {
        importerIsMusic = true
        showFileImporter = true
    }

    /// Photos picked in the system photo picker.
    func importPicked(_ picked: [PhotosPickerItem]) async {
        guard !picked.isEmpty else { return }
        var urls: [URL] = []
        importing = true
        for p in picked {
            let isMovie = p.supportedContentTypes.contains { $0.conforms(to: .movie) }
            do {
                if isMovie, let m = try await p.loadTransferable(type: PickedMovie.self) {
                    urls.append(m.url)
                } else if let i = try await p.loadTransferable(type: PickedImage.self) {
                    urls.append(i.url)
                } else {
                    notify("One of the items couldn't be read.")
                }
            } catch {
                notify("One of the items couldn't be read: \(error.localizedDescription)")
            }
        }
        importing = false
        await addFiles(urls)
    }

    /// Files chosen from the Files app.
    func importFiles(_ urls: [URL]) async {
        var local: [URL] = []
        for u in urls {
            do { local.append(try MediaLoader.copyIntoApp(u)) } catch { notify("\(u.lastPathComponent): couldn't be read.") }
        }
        await addFiles(local)
    }

    func addFiles(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        importing = true
        defer { importing = false }
        let fresh = items.isEmpty
        var target = pickTarget
        pickTarget = nil
        for url in urls {
            let name = url.deletingPathExtension().lastPathComponent
            let kind = MediaLoader.kind(of: url)
            if kind == nil {
                notify("\(url.lastPathComponent): only photos and videos can be added.")
                continue
            }
            if items.count >= maxCells {
                notify("A collage holds up to \(maxCells) photos and videos.")
                break
            }
            if kind == .video && videoCount >= maxVideos {
                notify("Only \(maxVideos) videos per collage. Remove one to add another.")
                continue
            }
            let item: MediaItem
            do {
                item = try await MediaLoader.load(url: url, name: name)
            } catch {
                notify(error.localizedDescription)
                continue
            }
            items.append(item)
            if item.kind == .video {
                project.lanes.append(newLane(mediaId: item.id, duration: item.duration, volume: project.lanes.isEmpty ? 1 : 0))
            }
            placeMedia(item.id, cell: target)
            target = nil
        }
        if fresh, !items.isEmpty { setCellCount(items.count) }
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

    func placeMedia(_ mediaId: String, cell: Int? = nil) {
        var cells = project.cells.map { $0.mediaId == mediaId ? CellState() : $0 }
        var count = project.cellCount
        var idx = cell ?? cells.firstIndex { $0.mediaId == nil } ?? -1
        if idx == -1 {
            if count >= maxCells {
                notify("All cells are full. Tap a cell to replace its media.")
                return
            }
            count += 1
            cells.append(CellState())
            idx = count - 1
        }
        cells[idx] = CellState(mediaId: mediaId)
        if count != project.cellCount { project.layoutId = defaultLayout(for: count).id }
        project.cells = cells
        project.cellCount = count
        selectedCell = idx
    }

    func removeMedia(_ mediaId: String) {
        playback.dispose(mediaId)
        items.removeAll { $0.id == mediaId }
        project.cells = project.cells.map { $0.mediaId == mediaId ? CellState() : $0 }
        project.lanes.removeAll { $0.mediaId == mediaId }
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
        let count = min(max(n, 1), maxCells)
        var cells = project.cells
        if cells.count > count { cells = Array(cells.prefix(count)) }
        while cells.count < count { cells.append(CellState()) }
        let keep = layout(byId: project.layoutId).count == count
        project.cells = cells
        project.cellCount = count
        if !keep { project.layoutId = defaultLayout(for: count).id }
        if let s = selectedCell, s >= count { selectedCell = nil }
        swapFrom = nil
    }

    func setLayout(_ id: String) { project.layoutId = id }

    func shuffleLayout() {
        let options = layouts(for: project.cellCount).filter { $0.id != project.layoutId }
        if let pick = options.randomElement() { project.layoutId = pick.id }
    }

    // MARK: Selection

    func selectCell(_ i: Int?) {
        selectedCell = i
        if i == nil && tab == .picture {
            tab = returnTab
            swapFrom = nil
        }
    }

    func openPicture() {
        if tab != .picture { returnTab = tab }
        withAnimation(.smooth) { tab = .picture }
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

    func removeMusic() {
        project.music = nil
        if selectedClip == musicClipId { selectedClip = nil }
    }

    func newCollage() {
        playback.pause()
        playback.playhead = 0
        for i in items { playback.dispose(i.id) }
        items = []
        project = Project()
        selectedCell = nil
        selectedClip = nil
        swapFrom = nil
        tab = .media
        playback.projectChanged()
    }
}
