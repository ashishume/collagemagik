import SwiftUI

/// Play / pause, a scrubber and the time. Sits under the preview whenever the collage has a video.
struct TransportBar: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        let pb = store.playback
        HStack(spacing: 8) {
            Button { pb.togglePlay() } label: {
                Image(systemName: pb.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(pb.isPlaying ? "Pause" : "Play")

            Slider(
                value: Binding(get: { pb.playhead }, set: { pb.seek(to: $0) }),
                in: 0...max(store.totalDuration, 0.1)
            )
            .accessibilityLabel("Playhead")

            Text("\(formatTime(pb.playhead)) / \(formatTime(store.totalDuration))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .glassEffect(.regular, in: .capsule)
    }
}

struct TimelinePanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        let lanes = placedLanes(store.project)
        if lanes.isEmpty {
            HintRow(symbol: "film", text: "Add a video to cut it here. Photos stay on screen for the whole video.")
        } else {
            VStack(spacing: 6) {
                controls
                TimelineArea(lanes: lanes)
            }
        }
    }

    private var controls: some View {
        let pb = store.playback
        return HStack(spacing: 8) {
            Button { pb.togglePlay() } label: {
                Image(systemName: pb.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(pb.isPlaying ? "Pause" : "Play")

            Text("\(formatTime(pb.playhead)) / \(formatTime(store.totalDuration))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ChipButton(title: "Split", symbol: "scissors") { store.splitAtPlayhead() }
                        .fixedSize()
                    ChipButton(title: "Part", symbol: "film.stack") { store.openChoosePart() }
                        .fixedSize()
                        .accessibilityLabel("Choose part of the clip")
                    Menu {
                        Button { store.openChoosePart() } label: { Label("Choose part…", systemImage: "film.stack") }
                        Button { store.duplicateSelectedClip() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                        Button { store.resetSelectedClip() } label: { Label("Use whole video", systemImage: "arrow.left.and.right") }
                        Divider()
                        Button(role: .destructive) { store.deleteSelectedClip() } label: { Label("Delete clip", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.footnote.weight(.semibold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .accessibilityLabel("More clip options")
                }
            }
        }
    }
}

/// Height of the timeline panel's content for a given number of video lanes (used to size the panel card).
func timelineContentHeight(lanes: Int) -> CGFloat {
    TimelineMetrics.controlsHeight + 6 + TimelineMetrics.rulerHeight + CGFloat(lanes + 1) * (TimelineMetrics.laneHeight + TimelineMetrics.rowGap)
}

enum TimelineMetrics {
    static let laneHeight: CGFloat = 28
    static let rulerHeight: CGFloat = 14
    static let rowGap: CGFloat = 3
    static let controlsHeight: CGFloat = 30
}

private struct TimelineArea: View {
    @Environment(CollageStore.self) private var store
    let lanes: [Lane]

    private enum Kind { case left, right, move }
    private struct DragCtx {
        var kind: Kind
        var mediaId: String
        var origin: Clip
        var pxPerSec: Double
        var sourceLength: Double
    }
    private struct Target {
        var kind: Kind
        var mediaId: String
        var clip: Clip
        var sourceLength: Double
    }

    private let laneHeight = TimelineMetrics.laneHeight
    private let rulerHeight = TimelineMetrics.rulerHeight
    private let rowGap = TimelineMetrics.rowGap
    private let labelWidth: CGFloat = 54
    private let musicLane = "__music__"
    /// Clips narrower than this still get a finger-sized touch area, so a tiny clip can be grabbed instead of scrubbing past it.
    private let minHitWidth: CGFloat = 52
    private let maxEdgeZone: CGFloat = 22

    @State private var drag: DragCtx?
    @State private var frozenView: Double?
    @State private var scrubbing = false
    @GestureState private var touching = false

    private func viewSeconds(_ dur: Double) -> Double {
        frozenView ?? clamp((dur * 1.4 / 5).rounded(.up) * 5, 10, 60)
    }

    private func rowY(_ i: Int) -> CGFloat { rulerHeight + CGFloat(i) * (laneHeight + rowGap) }

    var body: some View {
        let dur = store.totalDuration
        let rows = lanes.count + 1
        HStack(alignment: .top, spacing: 6) {
            labels(rows: rows)
            GeometryReader { geo in
                track(width: geo.size.width, dur: dur)
            }
            .frame(height: rowY(rows) - rowGap)
            .coordinateSpace(name: "track")
        }
    }

    // MARK: Labels

    private func labels(rows: Int) -> some View {
        VStack(spacing: rowGap) {
            Color.clear.frame(height: rulerHeight)
            ForEach(Array(lanes.enumerated()), id: \.element.mediaId) { i, lane in
                let name = i == 0 ? "A" : "B"
                HStack(spacing: 2) {
                    Text(name)
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(i == 0 ? Color.laneA : Color.laneB, in: Circle())
                        .foregroundStyle(.black.opacity(0.8))
                    miniButton(lane.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill", on: lane.volume == 0, label: lane.volume == 0 ? "Unmute video \(name)" : "Mute video \(name)") {
                        store.setLane(lane.mediaId) { $0.volume = $0.volume == 0 ? 1 : 0 }
                    }
                    miniButton("repeat", on: lane.loop, label: "Loop video \(name) when it ends") {
                        store.setLane(lane.mediaId) { $0.loop.toggle() }
                    }
                }
                .frame(width: labelWidth, height: laneHeight)
            }
            HStack(spacing: 2) {
                Image(systemName: "music.note")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 18, height: 18)
                    .background(Color.musicGreen, in: Circle())
                    .foregroundStyle(.black.opacity(0.8))
                if let m = store.project.music {
                    miniButton(m.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill", on: m.volume == 0, label: m.volume == 0 ? "Unmute music" : "Mute music") {
                        store.project.music?.volume = m.volume == 0 ? 0.7 : 0
                    }
                    miniButton("repeat", on: m.loop, label: "Repeat the music until the collage ends") {
                        store.project.music?.loop.toggle()
                    }
                }
            }
            .frame(width: labelWidth, height: laneHeight)
        }
        .frame(width: labelWidth)
    }

    private func miniButton(_ symbol: String, on: Bool, label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 17, height: laneHeight)
                .foregroundStyle(on ? Color.brand : Color.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Track

    @ViewBuilder
    private func track(width: CGFloat, dur: Double) -> some View {
        let view = viewSeconds(dur)
        let pxPerSec = Double(width) / view
        ZStack(alignment: .topLeading) {
            Color.clear

            ruler(view: view, pxPerSec: pxPerSec)

            ForEach(Array(lanes.enumerated()), id: \.element.mediaId) { i, lane in
                laneRow(index: i, lane: lane, pxPerSec: pxPerSec, width: width)
                    .offset(y: rowY(i))
            }
            musicRow(pxPerSec: pxPerSec, width: width, dur: dur)
                .offset(y: rowY(lanes.count))

            Playhead(pxPerSec: pxPerSec, height: rowY(lanes.count + 1) - rowGap)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        // One gesture owns the whole track. It decides on touch-down what the finger grabbed (a trim handle, a clip, or empty
        // space = playhead), using touch areas that stay finger-sized even for tiny clips, so a small clip is never lost to scrubbing.
        .gesture(trackGesture(pxPerSec: pxPerSec, dur: dur))
        .onChange(of: touching) { _, now in
            if !now { endGesture() }
        }
    }

    private func endGesture() {
        drag = nil
        scrubbing = false
        frozenView = nil
    }

    private func trackGesture(pxPerSec: Double, dur: Double) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("track"))
            .updating($touching) { _, state, _ in state = true }
            .onChanged { v in
                if drag == nil && !scrubbing {
                    if let t = hitTarget(v.startLocation, pxPerSec: pxPerSec) {
                        drag = DragCtx(kind: t.kind, mediaId: t.mediaId, origin: t.clip, pxPerSec: pxPerSec, sourceLength: t.sourceLength)
                        frozenView = viewSeconds(dur)
                        store.selectedClip = t.clip.id
                        store.playback.pause()
                    } else {
                        scrubbing = true
                        store.selectedClip = nil
                    }
                }
                if let d = drag {
                    applyEdit(d, translation: Double(v.translation.width))
                } else if scrubbing {
                    store.playback.seek(to: clamp(Double(v.location.x) / pxPerSec, 0, dur))
                }
            }
            .onEnded { _ in endGesture() }
    }

    /// What is under the finger at `p` (nil = empty space or the ruler).
    private func hitTarget(_ p: CGPoint, pxPerSec: Double) -> Target? {
        guard p.y >= rulerHeight else { return nil }
        let row = Int((p.y - rulerHeight) / (laneHeight + rowGap))
        let mediaId: String
        let clips: [Clip]
        let sourceLength: (Clip) -> Double
        if row < lanes.count {
            let lane = lanes[row]
            mediaId = lane.mediaId
            clips = lane.clips
            let dur = store.item(lane.mediaId)?.duration
            sourceLength = { dur ?? $0.outPoint }
        } else if row == lanes.count, let m = store.project.music {
            mediaId = musicLane
            clips = [m.asClip]
            sourceLength = { _ in m.duration }
        } else {
            return nil
        }

        var best: (clip: Clip, kind: Kind, dist: CGFloat)?
        for clip in clips {
            var x0 = CGFloat(clip.start * pxPerSec)
            var x1 = CGFloat(clip.end * pxPerSec)
            let mid = (x0 + x1) / 2
            if x1 - x0 < minHitWidth {
                x0 = mid - minHitWidth / 2
                x1 = mid + minHitWidth / 2
            }
            // a few points of slack just outside the clip make the trim handles easy to catch
            guard p.x >= x0 - 8, p.x <= x1 + 8 else { continue }
            let edge = min(maxEdgeZone, (x1 - x0) * 0.3)
            let kind: Kind = p.x < x0 + edge ? .left : (p.x > x1 - edge ? .right : .move)
            let dist = abs(p.x - mid)
            if best == nil || dist < best!.dist { best = (clip, kind, dist) }
        }
        guard let best else { return nil }
        return Target(kind: best.kind, mediaId: mediaId, clip: best.clip, sourceLength: sourceLength(best.clip))
    }

    private func applyEdit(_ d: DragCtx, translation: Double) {
        let dt = translation / d.pxPerSec
        let next: Clip
        switch d.kind {
        case .left: next = trimLeft(d.origin, dt)
        case .right: next = trimRight(d.origin, dt, mediaDuration: d.sourceLength)
        case .move: next = moveClip(d.origin, dt)
        }
        if d.mediaId == musicLane {
            store.project.music?.start = next.start
            store.project.music?.inPoint = next.inPoint
            store.project.music?.outPoint = next.outPoint
            return
        }
        store.updateClip(mediaId: d.mediaId, clipId: d.origin.id) { _ in next }
        // keep the picture on the clip being edited
        if d.kind == .left { store.playback.seek(to: next.start) }
        else if d.kind == .right { store.playback.seek(to: max(next.start, next.end - 0.05)) }
    }

    private func ruler(view: Double, pxPerSec: Double) -> some View {
        let step = view <= 15 ? 2.0 : view <= 30 ? 5.0 : 10.0
        return ZStack(alignment: .topLeading) {
            ForEach(Array(stride(from: 0.0, through: view, by: step)), id: \.self) { t in
                Text("\(Int(t))s")
                    .font(.system(size: 8.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .offset(x: t * pxPerSec + 2)
            }
        }
        .frame(height: rulerHeight, alignment: .top)
        .allowsHitTesting(false)
    }

    private func laneRow(index: Int, lane: Lane, pxPerSec: Double, width: CGFloat) -> some View {
        let color: Color = index == 0 ? .laneA : .laneB
        let item = store.item(lane.mediaId)
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.white.opacity(0.06))
                .frame(width: width, height: laneHeight)
            ForEach(lane.clips) { clip in
                clipView(clip: clip, color: color, pxPerSec: pxPerSec, thumbnail: item?.thumbnail, label: formatTime(clip.length))
            }
        }
        .frame(width: width, height: laneHeight, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func musicRow(pxPerSec: Double, width: CGFloat, dur: Double) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.white.opacity(0.06))
                .frame(width: width, height: laneHeight)
                .allowsHitTesting(false)
            if let m = store.project.music {
                let ownEnd = m.start + m.clipLength
                let end = m.end(total: dur)
                if m.loop && end > ownEnd {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.musicGreen.opacity(0.18))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.musicGreen.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        .frame(width: (end - ownEnd) * pxPerSec, height: laneHeight - 6)
                        .offset(x: ownEnd * pxPerSec, y: 3)
                        .allowsHitTesting(false)
                }
                clipView(clip: m.asClip, color: .musicGreen, pxPerSec: pxPerSec, thumbnail: nil, label: m.name)
                    .allowsHitTesting(false)
            } else {
                Button { store.openMusicImporter() } label: {
                    Label("Add music", systemImage: "plus").font(.caption.weight(.semibold))
                        .padding(.horizontal, 12).frame(height: laneHeight - 6)
                        .contentShape(Capsule())
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                .offset(x: 3, y: 3)
            }
        }
        .frame(width: width, height: laneHeight, alignment: .topLeading)
    }

    /// Drawing only. Touches are handled by the track gesture.
    private func clipView(clip: Clip, color: Color, pxPerSec: Double, thumbnail: UIImage?, label: String) -> some View {
        let w = max(8, clip.length * pxPerSec)
        let selected = store.selectedClip == clip.id
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return ZStack {
            shape.fill(color.opacity(0.55))
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: laneHeight)
                    .opacity(0.35)
                    .clipShape(shape)
            }
            if w >= 64 {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            shape.strokeBorder(selected ? Color.white : color, lineWidth: selected ? 2 : 1)
            if w >= 28 {
                HStack {
                    Capsule().fill(.white.opacity(0.9)).frame(width: 3, height: 12)
                    Spacer(minLength: 0)
                    Capsule().fill(.white.opacity(0.9)).frame(width: 3, height: 12)
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(width: w, height: laneHeight - 2)
        .offset(x: clip.start * pxPerSec, y: 1)
        .accessibilityLabel(clip.id == musicClipId ? "Music \(label)" : "Clip \(label)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct Playhead: View {
    @Environment(CollageStore.self) private var store
    let pxPerSec: Double
    let height: CGFloat

    var body: some View {
        let x = store.playback.playhead * pxPerSec
        ZStack(alignment: .top) {
            Capsule().fill(.white).frame(width: 2, height: height)
            Circle().fill(.white).frame(width: 8, height: 8).shadow(radius: 2)
        }
        .offset(x: x - 1)
    }
}
