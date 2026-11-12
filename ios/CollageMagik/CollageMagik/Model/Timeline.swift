import Foundation

/// Instagram Stories play up to 60 seconds per clip.
let maxDuration = 60.0
let minClip = 0.2
/// Length of a collage that has no video (used for the preview clock and still export).
let stillDuration = 6.0

func newId() -> String { UUID().uuidString }

extension Clip {
    var length: Double { outPoint - inPoint }
    var end: Double { start + length }
}

extension Lane {
    var sortedClips: [Clip] { clips.sorted { $0.start < $1.start } }
}

struct Resolved {
    var clip: Clip
    /// Second to show from the source file.
    var time: Double
    /// True when the playhead is inside a clip (as opposed to holding the first or last frame).
    var active: Bool
}

/// What a lane shows at timeline time `t`.
func resolveLane(_ lane: Lane, _ t: Double) -> Resolved? {
    let clips = lane.sortedClips
    guard let first = clips.first else { return nil }
    let seqStart = first.start
    let seqEnd = clips.map(\.end).max() ?? seqStart
    var tt = t
    if lane.loop && seqEnd > seqStart && t >= seqEnd {
        tt = seqStart + (t - seqStart).truncatingRemainder(dividingBy: seqEnd - seqStart)
    }
    for clip in clips where tt >= clip.start && tt < clip.end {
        return Resolved(clip: clip, time: clip.inPoint + (tt - clip.start), active: true)
    }
    if tt < seqStart { return Resolved(clip: first, time: first.inPoint, active: false) }
    var prev = first
    for c in clips where c.end <= tt { prev = c }
    return Resolved(clip: prev, time: max(prev.inPoint, prev.outPoint - 0.04), active: false)
}

/// Lanes whose video is shown in a cell.
func placedLanes(_ project: Project) -> [Lane] {
    let placed = Set(project.cells.prefix(project.cellCount).compactMap(\.mediaId))
    return project.lanes.filter { placed.contains($0.mediaId) }
}

/// Length of the collage: the end of its latest clip, up to 60 seconds.
func totalDuration(_ project: Project) -> Double {
    let lanes = placedLanes(project)
    if lanes.isEmpty { return stillDuration }
    let end = lanes.flatMap { $0.clips.map(\.end) }.max() ?? stillDuration
    return clamp(end, minClip, maxDuration)
}

/// A new lane for a video: whole file (or its first 60 s), starting at 0.
func newLane(mediaId: String, duration: Double, volume: Double) -> Lane {
    Lane(mediaId: mediaId, clips: [Clip(id: newId(), start: 0, inPoint: 0, outPoint: min(duration, maxDuration))], loop: false, volume: volume)
}

/// Drag the left handle by dt seconds. The picture stays where it is on the timeline.
func trimLeft(_ clip: Clip, _ dt: Double) -> Clip {
    let minDt = max(-clip.inPoint, -clip.start)
    let maxDt = clip.length - minClip
    let d = clamp(dt, minDt, maxDt)
    var c = clip
    c.inPoint += d
    c.start += d
    return c
}

func trimRight(_ clip: Clip, _ dt: Double, mediaDuration: Double) -> Clip {
    let maxOut = min(mediaDuration, clip.inPoint + (maxDuration - clip.start))
    var c = clip
    c.outPoint = clamp(clip.outPoint + dt, clip.inPoint + minClip, maxOut)
    return c
}

func moveClip(_ clip: Clip, _ dt: Double) -> Clip {
    var c = clip
    c.start = clamp(clip.start + dt, 0, max(0, maxDuration - clip.length))
    return c
}

/// Cut a clip at timeline time t. Returns nil if t is not inside the clip (with some room on both sides).
func splitClip(_ clip: Clip, _ t: Double) -> (Clip, Clip)? {
    if t <= clip.start + minClip || t >= clip.end - minClip { return nil }
    let cut = clip.inPoint + (t - clip.start)
    var a = clip
    a.outPoint = cut
    let b = Clip(id: newId(), start: t, inPoint: cut, outPoint: clip.outPoint)
    return (a, b)
}

func formatTime(_ s: Double) -> String {
    let t = max(0, s)
    let m = Int(t) / 60
    let sec = Int(t) % 60
    return String(format: "%d:%02d", m, sec)
}

// MARK: - Background music ribbon

/// Id used for the music clip when it is selected on the timeline.
let musicClipId = "music"
let fadeSeconds = 1.5

extension MusicTrack {
    /// The music as a clip, so it can be trimmed and moved with the same functions as a video clip.
    var asClip: Clip { Clip(id: musicClipId, start: start, inPoint: inPoint, outPoint: outPoint) }
    var clipLength: Double { outPoint - inPoint }
    /// When the music stops: at the end of the collage if it loops, otherwise at the end of its clip.
    func end(total: Double) -> Double { loop ? total : min(total, start + clipLength) }
}

/// The pieces of the song to play, with the timeline time each one starts at.
func musicSegments(_ m: MusicTrack, total: Double) -> [(at: Double, from: Double, to: Double)] {
    let len = m.clipLength
    var segs: [(at: Double, from: Double, to: Double)] = []
    if len <= 0 { return segs }
    var at = m.start
    repeat {
        let l = min(len, total - at)
        if l <= 0 { break }
        segs.append((at, m.inPoint, m.inPoint + l))
        at += len
    } while m.loop && at < total
    return segs
}

/// Which second of the song to hear at timeline time t, and how loud (fade) it should be.
func musicAt(_ m: MusicTrack, _ t: Double, total: Double) -> (want: Double, audible: Bool, fade: Double) {
    let len = m.clipLength
    if len <= 0 || t < m.start { return (m.inPoint, false, 0) }
    let rel = t - m.start
    if !m.loop && rel >= len { return (m.outPoint, false, 0) }
    let end = m.end(total: total)
    return (
        m.inPoint + (m.loop ? rel.truncatingRemainder(dividingBy: len) : rel),
        t < end,
        m.fadeOut ? clamp((end - t) / fadeSeconds, 0, 1) : 1
    )
}

// MARK: - Choose part (slip)

/// Slide which part of the video plays, keeping the clip's length and its place on the timeline (Instagram's "trim" window).
func slipClip(_ clip: Clip, _ dt: Double, mediaDuration: Double) -> Clip {
    let d = clamp(dt, -clip.inPoint, max(0, mediaDuration - clip.outPoint))
    var c = clip
    c.inPoint += d
    c.outPoint += d
    return c
}

/// Set the part of the video a clip plays, keeping where it starts on the timeline. Clamped to the file, a minimum length,
/// and the 60-second collage limit.
func choosePart(_ clip: Clip, inPoint: Double, outPoint: Double, mediaDuration: Double) -> Clip {
    let maxLen = max(minClip, min(mediaDuration, maxDuration - clip.start))
    var i = clamp(inPoint, 0, max(0, mediaDuration - minClip))
    var o = clamp(outPoint, i + minClip, mediaDuration)
    if o - i > maxLen { o = i + maxLen }
    if o > mediaDuration { o = mediaDuration; i = max(0, o - maxLen) }
    var c = clip
    c.inPoint = i
    c.outPoint = o
    return c
}

/// A copy of a clip placed right after it (or as late as still fits in 60 seconds). nil when there is no room.
func duplicateClip(_ clip: Clip) -> Clip? {
    let start = min(clip.end, maxDuration - clip.length)
    guard start >= clip.start + minClip else { return nil }
    return Clip(id: newId(), start: start, inPoint: clip.inPoint, outPoint: clip.outPoint)
}

/// One clip of one video lane.
struct ClipRef: Identifiable, Equatable {
    let mediaId: String
    let clipId: String
    var id: String { clipId }
}
