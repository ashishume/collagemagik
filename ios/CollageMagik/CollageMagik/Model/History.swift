import SwiftUI

/// Undo and redo for the design.
///
/// Every edit changes `project`, often dozens of times a second while a finger drags. A step is recorded once the
/// design has been still for a moment, so one drag, pinch or slider move is one undo. Media in the tray is not part of
/// the history: undo never brings back a photo that was removed from the tray (any reference to one is dropped).
extension CollageStore {
    private static let maxSteps = 60
    private static let settle: Duration = .milliseconds(450)

    var canUndo: Bool { undoCount > 0 || project != committed }
    var canRedo: Bool { redoCount > 0 }

    /// Call after every change to `project`.
    func projectChangedForHistory() {
        guard project != committed else { return }
        historyTask?.cancel()
        historyTask = Task { [weak self] in
            try? await Task.sleep(for: Self.settle)
            guard !Task.isCancelled else { return }
            self?.commitStep()
        }
    }

    /// Records the change in progress as one step.
    private func commitStep() {
        historyTask?.cancel()
        historyTask = nil
        guard project != committed else { return }
        undoStack.append(committed)
        if undoStack.count > Self.maxSteps { undoStack.removeFirst(undoStack.count - Self.maxSteps) }
        redoStack.removeAll()
        committed = project
        syncHistoryCounts()
    }

    func undo() {
        commitStep()
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(project)
        restore(previous)
    }

    func redo() {
        commitStep()
        guard let next = redoStack.popLast() else { return }
        undoStack.append(project)
        restore(next)
    }

    /// Forgets the history (a new or reopened design starts a fresh one).
    func resetHistory() {
        historyTask?.cancel()
        historyTask = nil
        undoStack.removeAll()
        redoStack.removeAll()
        committed = project
        syncHistoryCounts()
    }

    private func restore(_ p: Project) {
        var p = p
        // anything that points at media no longer in the tray leaves the design
        let ids = Set(items.map(\.id))
        for i in p.cells.indices where p.cells[i].mediaId.map({ !ids.contains($0) }) ?? false { p.cells[i] = CellState() }
        p.lanes.removeAll { !ids.contains($0.mediaId) }
        p.overlays.removeAll { !ids.contains($0.mediaId) }
        if let b = p.backdrop.blurMediaId, !ids.contains(b) { p.backdrop.blurMediaId = nil; p.backdrop.kind = .color }

        withAnimation(.smooth(duration: 0.25)) { project = p }
        committed = project
        // selections that no longer exist are dropped
        if let s = selectedCell, s >= project.cellCount { selectCell(nil) }
        if let s = selectedOverlay, overlay(s) == nil { selectOverlay(nil) }
        if let s = selectedCaption, caption(s) == nil { selectCaption(nil) }
        if let s = selectedSticker, sticker(s) == nil { selectSticker(nil) }
        if let s = selectedClip, s != musicClipId, !project.lanes.contains(where: { $0.clips.contains { $0.id == s } }) { selectedClip = nil }
        syncHistoryCounts()
        playback.projectChanged()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func syncHistoryCounts() {
        if undoCount != undoStack.count { undoCount = undoStack.count }
        if redoCount != redoStack.count { redoCount = redoStack.count }
    }
}
