import Foundation

// MARK: - Motion designs

/// How the pictures leaving the previous scene go and the ones new to this scene arrive. A picture that is in both
/// scenes always glides and resizes from its old place to its new one, whatever the transition.
enum MotionTransition: String, Codable, CaseIterable, Identifiable {
    case cut, fade, slideLeft, slideUp, zoom
    var id: String { rawValue }
}

/// Slow movement of the photos while a scene plays (videos move by themselves).
enum PhotoMove: String, Codable, CaseIterable, Identifiable {
    case none, zoomIn, zoomOut, drift
    var id: String { rawValue }
}

/// How the pictures new to a scene arrive one after another, instead of the scene's transition.
enum MotionEntrance: String, Codable, CaseIterable, Identifiable {
    case none, pop, drop, rise
    var id: String { rawValue }
}

/// One step of a motion design: a layout, which slot (cell) fills each of its places, and how long it lasts.
struct MotionScene: Codable, Equatable {
    var layoutId: String
    /// The slot shown in each place of the layout, in the layout's order.
    var slots: [Int]
    /// Seconds, the transition into the scene included.
    var length: Double
    /// How the scene comes in (ignored for the first scene).
    var transition: MotionTransition = .fade
    var move: PhotoMove = .none
    var entrance: MotionEntrance = .none

    /// Where `slot` sits in this scene, as fractions of the design.
    func rect(of slot: Int) -> (rect: LayoutRect, place: Int)? {
        guard let j = slots.firstIndex(of: slot) else { return nil }
        let rects = layout(byId: layoutId).rects
        guard rects.indices.contains(j) else { return nil }
        return (rects[j], j)
    }
}

/// A design that plays as a sequence of scenes. The cells of the project are its slots: each holds one photo or video
/// (with its own crop, look and frame) and the scenes move the slots around. Videos play straight through the scene
/// changes and repeat when they are shorter than the design.
struct Motion: Codable, Equatable {
    var scenes: [MotionScene]
    /// Seconds each transition takes (shortened for short scenes).
    var transitionLength: Double = 0.7

    var slotCount: Int { (scenes.flatMap(\.slots).max() ?? -1) + 1 }
    var total: Double { min(maxDuration, scenes.reduce(0) { $0 + $1.length }) }

    /// When each scene starts.
    var starts: [Double] {
        var out: [Double] = []
        var t = 0.0
        for s in scenes {
            out.append(t)
            t += s.length
        }
        return out
    }

    func sceneIndex(at t: Double) -> Int {
        let s = starts
        return max(0, (s.lastIndex { $0 <= t + 1e-9 }) ?? 0)
    }

    /// How long the transition into scene `k` takes.
    func transitionTime(into k: Int) -> Double {
        guard k > 0, scenes.indices.contains(k), scenes[k].transition != .cut else { return 0 }
        return max(0.05, min(transitionLength, scenes[k].length * 0.5, scenes[k - 1].length * 0.5))
    }
}

/// Where every cell is at one moment of a motion design. Not saved: the store's project never has one, only the
/// copies the preview and the exports draw (`Project.posed(at:)`).
struct MotionPose: Codable, Equatable {
    /// One rect per cell, as fractions of the design.
    var rects: [LayoutRect]
    /// 0 = hidden.
    var alpha: [Double]
    /// Cell indices from the bottom of the pile to the top.
    var order: [Int]
    /// Captions tied to a scene, by id (captions shown throughout aren't listed).
    var captionAlpha: [String: Double]
    /// The scene on screen (the one coming in, during a transition).
    var scene: Int
}

// MARK: - Easing

private func easeInOut(_ x: Double) -> Double {
    let p = clamp(x, 0, 1)
    return p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2
}

private func easeOut(_ x: Double) -> Double {
    let p = clamp(x, 0, 1)
    return 1 - pow(1 - p, 3)
}

/// Overshoots a little before settling (a pop).
private func easeOutBack(_ x: Double) -> Double {
    let p = clamp(x, 0, 1)
    let c1 = 1.70158, c3 = c1 + 1
    return 1 + c3 * pow(p - 1, 3) + c1 * pow(p - 1, 2)
}

private func lerp(_ a: Double, _ b: Double, _ e: Double) -> Double { a + (b - a) * e }

private extension LayoutRect {
    /// Scaled by `k` about the point (cx, cy).
    func scaled(_ k: Double, cx: Double, cy: Double) -> LayoutRect {
        LayoutRect(x: cx + (x - cx) * k, y: cy + (y - cy) * k, w: w * k, h: h * k, tilt: tilt)
    }
    func scaled(_ k: Double) -> LayoutRect { scaled(k, cx: x + w / 2, cy: y + h / 2) }
    func moved(_ dx: Double, _ dy: Double) -> LayoutRect { LayoutRect(x: x + dx, y: y + dy, w: w, h: h, tilt: tilt) }
    static func mix(_ a: LayoutRect, _ b: LayoutRect, _ e: Double) -> LayoutRect {
        LayoutRect(x: lerp(a.x, b.x, e), y: lerp(a.y, b.y, e), w: lerp(a.w, b.w, e), h: lerp(a.h, b.h, e), tilt: lerp(a.tilt, b.tilt, e))
    }
}

/// Off the design, for slots that aren't showing (so they can't be tapped either).
private let hiddenRect = LayoutRect(x: 3, y: 3, w: 0.01, h: 0.01)

private struct SlotLook {
    var rect: LayoutRect
    var alpha: Double = 1
    /// Extra zoom on top of the picture's own.
    var zoom: Double = 1
    /// Added to the picture's pan (photos drifting).
    var pan: Double = 0
    /// Pile order: leaving pictures lowest, gliding ones highest.
    var layer: Int = 0
}

// MARK: - Posing

extension Motion {
    /// Slot `slot` while scene `k` is on screen, `local` seconds into it. `entering`: new to the scene, so it plays the
    /// scene's entrance.
    private func settled(_ k: Int, slot: Int, local: Double, entering: Bool, video: Bool) -> SlotLook? {
        let scene = scenes[k]
        guard let (base, place) = scene.rect(of: slot) else { return nil }
        var look = SlotLook(rect: base)
        if entering, scene.entrance != .none {
            let p = clamp((local - Double(place) * 0.14) / 0.5, 0, 1)
            look.alpha = min(1, p * 2.5)
            switch scene.entrance {
            case .pop: look.rect = base.scaled(0.55 + 0.45 * easeOutBack(p))
            case .drop: look.rect = base.moved(0, -(1 - easeOut(p)) * 0.3)
            case .rise: look.rect = base.moved(0, (1 - easeOut(p)) * 0.22)
            case .none: break
            }
        }
        if !video {
            // keeps going a little through the next transition, so a photo never stops dead
            let q = clamp(local / max(0.1, scene.length), 0, 1.25)
            switch scene.move {
            case .zoomIn: look.zoom = 1 + 0.16 * q
            case .zoomOut: look.zoom = 1 + 0.16 * max(0, 1 - q)
            case .drift: look.zoom = 1.14; look.pan = clamp(-0.8 + 1.6 * q, -1, 1)
            case .none: break
            }
        }
        return look
    }

    /// Where every one of `count` cells is at time `t`. `isVideo(i)`: cell i holds a video (videos don't get photo moves).
    func pose(at t: Double, count: Int, captions: [Caption], isVideo: (Int) -> Bool) -> (pose: MotionPose, zoom: [Double], pan: [Double]) {
        guard !scenes.isEmpty else {
            return (MotionPose(rects: Array(repeating: hiddenRect, count: count), alpha: Array(repeating: 0, count: count),
                               order: Array(0..<count), captionAlpha: [:], scene: 0), Array(repeating: 1, count: count), Array(repeating: 0, count: count))
        }
        let tt = clamp(t, 0, total)
        let k = sceneIndex(at: tt)
        let starts = self.starts
        let local = tt - starts[k]
        let T = transitionTime(into: k)
        let inTransition = k > 0 && T > 0 && local < T
        let e = inTransition ? easeInOut(local / T) : 1
        let scene = scenes[k]

        var looks: [SlotLook] = []
        for s in 0..<count {
            let video = isVideo(s)
            let wasThere = k > 0 && scenes[k - 1].slots.contains(s)
            let cur = settled(k, slot: s, local: local, entering: k == 0 || !wasThere, video: video)
            guard inTransition else {
                looks.append(cur ?? SlotLook(rect: hiddenRect, alpha: 0))
                continue
            }
            let prev = settled(k - 1, slot: s, local: tt - starts[k - 1], entering: false, video: video)
            switch (prev, cur) {
            case let (p?, c?):
                // in both scenes: glide from the old place to the new one
                looks.append(SlotLook(rect: .mix(p.rect, c.rect, e), alpha: 1, zoom: lerp(p.zoom, c.zoom, e), pan: lerp(p.pan, c.pan, e), layer: 2))
            case (var p?, nil):
                switch scene.transition {
                case .fade, .cut: p.alpha = 1 - e
                case .slideLeft: p.rect = p.rect.moved(-e, 0)
                case .slideUp: p.rect = p.rect.moved(0, -e)
                case .zoom: p.rect = p.rect.scaled(1 + 0.35 * e, cx: 0.5, cy: 0.5); p.alpha = 1 - e
                }
                p.layer = 0
                looks.append(p)
            case (nil, var c?):
                if scene.entrance == .none {
                    switch scene.transition {
                    case .fade, .cut: c.alpha = e
                    case .slideLeft: c.rect = c.rect.moved(1 - e, 0)
                    case .slideUp: c.rect = c.rect.moved(0, 1 - e)
                    case .zoom: c.rect = c.rect.scaled(0.8 + 0.2 * e, cx: 0.5, cy: 0.5); c.alpha = e
                    }
                }
                c.layer = 1
                looks.append(c)
            case (nil, nil):
                looks.append(SlotLook(rect: hiddenRect, alpha: 0))
            }
        }

        var captionAlpha: [String: Double] = [:]
        for c in captions {
            guard let sc = c.scene else { continue }
            if sc == k {
                captionAlpha[c.id] = inTransition ? e : 1
            } else if inTransition && sc == k - 1 {
                captionAlpha[c.id] = 1 - e
            } else {
                captionAlpha[c.id] = 0
            }
        }

        let order = looks.indices.sorted { a, b in
            looks[a].layer != looks[b].layer ? looks[a].layer < looks[b].layer : a < b
        }
        let pose = MotionPose(rects: looks.map(\.rect), alpha: looks.map(\.alpha), order: order, captionAlpha: captionAlpha, scene: k)
        return (pose, looks.map(\.zoom), looks.map(\.pan))
    }
}

extension Project {
    /// True when the design plays as a sequence of scenes.
    var isMotion: Bool { mode == .collage && motion != nil && !(motion?.scenes.isEmpty ?? true) }

    /// The design as it looks at time `t`: for a motion design, a copy with every cell moved where it is at that moment
    /// (`pose`), photos zoomed or drifted, and captions of other scenes left out. Anything else comes back unchanged.
    /// Draw this copy; edit the store's own project.
    func posed(at t: Double) -> Project {
        guard pose == nil, isMotion, let motion else { return self }
        let videos = Set(lanes.map(\.mediaId))
        let r = motion.pose(at: t, count: cellCount, captions: captions) { i in
            cells.indices.contains(i) && cells[i].mediaId.map(videos.contains) == true
        }
        var p = self
        p.pose = r.pose
        for i in p.cells.indices where i < cellCount {
            p.cells[i].zoom = max(1, p.cells[i].zoom) * r.zoom[i]
            if r.pan[i] != 0 { p.cells[i].panX = clamp(p.cells[i].panX + r.pan[i], -1, 1) }
        }
        p.captions = captions.filter { $0.scene == nil || (r.pose.captionAlpha[$0.id] ?? 0) > 0.001 }
        return p
    }

    /// How visible cell `i` is (1 for designs without motion).
    func cellAlpha(_ i: Int) -> Double {
        guard let pose, pose.alpha.indices.contains(i) else { return 1 }
        return pose.alpha[i]
    }

    /// Cells in drawing order, bottom first.
    var cellDrawOrder: [Int] {
        if let pose, pose.order.count == cellCount { return pose.order }
        return Array(0..<cellCount)
    }

    /// How visible caption `c` is (captions that belong to a scene fade with it).
    func captionAlpha(_ c: Caption) -> Double {
        guard c.scene != nil, let pose else { return 1 }
        return pose.captionAlpha[c.id] ?? 1
    }

    /// The design at a spread of moments through its length: what export sizes photos for (a photo may be shown far
    /// bigger in one scene than in another, or zoomed in). One entry for designs without motion.
    func motionSamples(step: Double = 0.2) -> [Project] {
        guard isMotion, let motion else { return [self] }
        let n = max(1, Int((motion.total / step).rounded(.up)))
        return (0...n).map { posed(at: Double($0) * step) }
    }
}

// MARK: - Editing

/// Limits for scenes the person edits.
let maxScenes = 12
let minSceneLength = 0.5
let maxSceneLength = 10.0

extension MotionScene {
    /// The same scene with `slots` shown: it keeps its layout when that still has the right number of places, otherwise
    /// it takes the first layout for that many.
    func showing(_ slots: [Int]) -> MotionScene {
        var s = self
        s.slots = slots
        if layout(byId: layoutId).count != slots.count { s.layoutId = defaultLayout(for: max(1, slots.count)).id }
        return s
    }
}

extension Motion {
    /// A first motion for a still collage of `count` pictures in `layoutId`: the first picture on its own, then the
    /// whole collage with the others popping in. One picture: just a slow zoom.
    static func starter(count: Int, layoutId: String) -> Motion {
        let all = Array(0..<max(1, count))
        let finalLayout = layout(byId: layoutId).count == all.count ? layoutId : defaultLayout(for: all.count).id
        guard all.count > 1 else {
            return Motion(scenes: [MotionScene(layoutId: finalLayout, slots: all, length: 4, move: .zoomIn)])
        }
        return Motion(scenes: [
            MotionScene(layoutId: "1-full", slots: [0], length: 2.4, move: .zoomIn),
            MotionScene(layoutId: finalLayout, slots: all, length: 3.6, transition: .fade, move: .zoomOut, entrance: .pop),
        ])
    }

    /// Scenes cleaned up for a design with `count` slots: slots that are gone leave every scene (a scene left empty
    /// goes), and slots that are new join the last scene, so a picture added to the design shows up.
    func fitted(to count: Int, previous: Int) -> Motion {
        var m = self
        m.scenes = scenes.compactMap { s in
            let kept = s.slots.filter { $0 < count }
            return kept.isEmpty ? nil : s.showing(kept)
        }
        let added = Array(max(0, previous)..<max(0, count)).filter { slot in !m.scenes.contains { $0.slots.contains(slot) } }
        if m.scenes.isEmpty {
            m.scenes = [MotionScene(layoutId: defaultLayout(for: max(1, count)).id, slots: Array(0..<max(1, count)), length: 3, move: .zoomIn)]
        } else if !added.isEmpty, let last = m.scenes.indices.last {
            let slots = Array((m.scenes[last].slots + added).prefix(maxCells))
            m.scenes[last] = m.scenes[last].showing(slots)
        }
        return m
    }

    /// The moment scene `k` is fully in: its transition and entrance over.
    func settledTime(of k: Int) -> Double {
        guard scenes.indices.contains(k) else { return 0 }
        let s = scenes[k]
        var dt = transitionTime(into: k)
        if s.entrance != .none { dt = max(dt, Double(max(0, s.slots.count - 1)) * 0.14 + 0.5) }
        return min(starts[k] + dt + 0.05, starts[k] + s.length - 0.05)
    }

    /// Lengths scaled by `k` (slower > 1), each kept between the limits and the whole within 60 seconds.
    func scaled(_ k: Double) -> Motion {
        var m = self
        for i in m.scenes.indices { m.scenes[i].length = clamp(m.scenes[i].length * k, minSceneLength, maxSceneLength) }
        return m.withinLimit()
    }

    /// Shortens the last scenes so the whole design fits in 60 seconds.
    func withinLimit() -> Motion {
        var m = self
        var over = m.scenes.reduce(0) { $0 + $1.length } - maxDuration
        var i = m.scenes.count - 1
        while over > 0.001 && i >= 0 {
            let cut = min(over, m.scenes[i].length - minSceneLength)
            m.scenes[i].length -= cut
            over -= cut
            i -= 1
        }
        return m
    }
}
