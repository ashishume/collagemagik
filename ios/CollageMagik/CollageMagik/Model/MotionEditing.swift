import UIKit

/// Editing a motion design's scenes. The scene being edited is the one at the playhead, so the preview always shows
/// what the controls change; picking a scene moves the playhead to the moment it has fully come in.
extension CollageStore {
    var motionScenes: [MotionScene] { project.isMotion ? project.motion?.scenes ?? [] : [] }

    /// The scene at the playhead.
    var currentScene: Int {
        guard project.isMotion, let m = project.motion else { return 0 }
        return m.sceneIndex(at: playback.playhead)
    }

    /// Makes a still collage move: the first picture on its own, then the collage. Videos repeat to fill it.
    func animateDesign() {
        guard !isCarousel else { return }
        project.motion = Motion.starter(count: project.cellCount, layoutId: project.layoutId)
        project.cellSizes = nil
        for i in project.lanes.indices { project.lanes[i].loop = true }
        selectedCell = nil
        swapFrom = nil
        playback.seek(to: 0)
        playback.projectChanged()
        if !UIAccessibility.isReduceMotionEnabled { playback.play() }
    }

    /// Back to a still collage, laid out like the scene on screen when it has every picture, otherwise in the first
    /// layout for that many.
    func makeStill() {
        guard let m = project.motion else { return }
        let scene = m.scenes.indices.contains(currentScene) ? m.scenes[currentScene] : nil
        project.motion = nil
        if let scene, scene.slots == Array(0..<project.cellCount) {
            project.layoutId = scene.layoutId
        } else if layout(byId: project.layoutId).count != project.cellCount {
            project.layoutId = defaultLayout(for: project.cellCount).id
        }
        playback.seek(to: 0)
        playback.projectChanged()
    }

    /// Shows scene `k` at the moment it has fully come in (paused, ready to edit).
    func selectScene(_ k: Int) {
        guard let m = project.motion, m.scenes.indices.contains(k) else { return }
        playback.seek(to: m.settledTime(of: k))
    }

    /// Changes the motion, then keeps the playhead on scene `focus` (the one just edited, added or moved).
    private func editMotion(focus: Int? = nil, _ change: (inout Motion) -> Void) {
        guard var m = project.motion else { return }
        let keep = focus ?? currentScene
        change(&m)
        project.motion = m.withinLimit()
        playback.projectChanged()
        selectScene(min(keep, (project.motion?.scenes.count ?? 1) - 1))
    }

    /// A copy of the scene on screen right after it, coming in with a fade.
    func addScene() {
        let k = currentScene
        guard motionScenes.count < maxScenes, motionScenes.indices.contains(k) else { return }
        editMotion(focus: k + 1) { m in
            var copy = m.scenes[k]
            copy.transition = .fade
            copy.entrance = .none
            m.scenes.insert(copy, at: k + 1)
        }
    }

    func deleteScene() {
        let k = currentScene
        guard motionScenes.count > 1, motionScenes.indices.contains(k) else { return }
        editMotion(focus: max(0, k - 1)) { m in m.scenes.remove(at: k) }
    }

    /// Moves the scene on screen one place earlier (-1) or later (+1).
    func moveScene(by d: Int) {
        let k = currentScene, to = k + d
        guard motionScenes.indices.contains(k), motionScenes.indices.contains(to) else { return }
        editMotion(focus: to) { m in m.scenes.swapAt(k, to) }
    }

    func updateScene(_ change: (inout MotionScene) -> Void) {
        let k = currentScene
        guard motionScenes.indices.contains(k) else { return }
        editMotion(focus: k) { m in change(&m.scenes[k]) }
    }

    func setSceneLength(_ v: Double) {
        updateScene { $0.length = clamp((v * 10).rounded() / 10, minSceneLength, maxSceneLength) }
    }

    /// Puts picture slot `slot` in or out of the scene on screen (a scene always keeps one picture). It is added at
    /// the end; the layout changes to one with the right number of places.
    func toggleSceneSlot(_ slot: Int) {
        updateScene { s in
            if let i = s.slots.firstIndex(of: slot) {
                guard s.slots.count > 1 else { return }
                var slots = s.slots
                slots.remove(at: i)
                s = s.showing(slots)
            } else {
                guard s.slots.count < maxCells else { return }
                s = s.showing(s.slots + [slot])
            }
        }
    }

    /// Every scene slower (k > 1) or faster.
    func scaleMotion(_ k: Double) {
        editMotion { m in m = m.scaled(k) }
    }

    /// Keeps the scenes in step when the number of slots changes (pictures added or removed).
    func fitMotion(previousCount: Int) {
        guard project.isMotion, let m = project.motion else { return }
        project.motion = m.fitted(to: project.cellCount, previous: previousCount)
        if project.motion != nil { for i in project.lanes.indices { project.lanes[i].loop = true } }
    }
}
