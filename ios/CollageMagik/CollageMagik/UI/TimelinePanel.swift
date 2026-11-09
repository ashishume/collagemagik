import SwiftUI

/// Play / pause, a scrubber and the time. Sits under the preview whenever the collage has a video.
struct TransportBar: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        let pb = store.playback
        HStack(spacing: 10) {
            Button { pb.togglePlay() } label: {
                Image(systemName: pb.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
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
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .capsule)
    }
}

struct TimelinePanel: View {
    @Environment(CollageStore.self) private var store

    var body: some View {
        let lanes = placedLanes(store.project)
        if lanes.isEmpty {
            ContentUnavailableView {
                Label("Nothing to cut yet", systemImage: "film")
            } description: {
                Text("Add a video to cut it here. Photos stay on screen for the whole video.")
            }
        } else {
            VStack(spacing: 8) {
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
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(pb.isPlaying ? "Pause" : "Play")

            Text("\(formatTime(pb.playhead)) / \(formatTime(store.totalDuration))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ChipButton(title: "Split", symbol: "scissors") { store.splitAtPlayhead() }
                    ChipButton(title: "Delete", symbol: "trash", role: .destructive) { store.deleteSelectedClip() }
                }
            }
        }
    }
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
    }

    private let laneHeight: CGFloat = 32
    private let rulerHeight: CGFloat = 16
    private let labelWidth: CGFloat = 62
    private let musicLane = "__music__"

    @State private var drag: DragCtx?
    @State private var frozenView: Double?
    @State private var scrubbing = false

    private func viewSeconds(_ dur: Double) -> Double {
        frozenView ?? clamp((dur * 1.4 / 5).rounded(.up) * 5, 10, 60)
    }

    var body: some View {
        let dur = store.totalDuration
        let rows = lanes.count + 1
        HStack(alignment: .top, spacing: 6) {
            labels(rows: rows)
            GeometryReader { geo in
                track(width: geo.size.width, dur: dur)
            }
            .frame(height: rulerHeight + CGFloat(rows) * (laneHeight + 4))
            .coordinateSpace(name: "track")
        }
    }

    // MARK: Labels

    private func labels(rows: Int) -> some View {
        VStack(spacing: 4) {
            Color.clear.frame(height: rulerHeight)
            ForEach(Array(lanes.enumerated()), id: \.element.mediaId) { i, lane in
                let name = i == 0 ? "A" : "B"
                HStack(spacing: 3) {
                    Text(name)
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 20, height: 20)
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
            HStack(spacing: 3) {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 20, height: 20)
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
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 18, height: 24)
                .foregroundStyle(on ? Color.brand : Color.secondary)
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
            // Background: tap or drag anywhere to move the playhead.
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("track"))
                        .onChanged { v in
                            if !scrubbing {
                                scrubbing = true
                                store.selectedClip = nil
                            }
                            store.playback.seek(to: clamp(Double(v.location.x) / pxPerSec, 0, dur))
                        }
                        .onEnded { _ in scrubbing = false }
                )

            ruler(view: view, pxPerSec: pxPerSec)

            ForEach(Array(lanes.enumerated()), id: \.element.mediaId) { i, lane in
                laneRow(index: i, lane: lane, pxPerSec: pxPerSec, width: width)
                    .offset(y: rulerHeight + CGFloat(i) * (laneHeight + 4))
            }
            musicRow(pxPerSec: pxPerSec, width: width, dur: dur)
                .offset(y: rulerHeight + CGFloat(lanes.count) * (laneHeight + 4))

            Playhead(pxPerSec: pxPerSec, height: rulerHeight + CGFloat(lanes.count + 1) * (laneHeight + 4))
                .allowsHitTesting(false)
        }
    }

    private func ruler(view: Double, pxPerSec: Double) -> some View {
        let step = view <= 15 ? 2.0 : view <= 30 ? 5.0 : 10.0
        return ZStack(alignment: .topLeading) {
            ForEach(Array(stride(from: 0.0, through: view, by: step)), id: \.self) { t in
                Text("\(Int(t))s")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
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
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.06))
                .frame(width: width, height: laneHeight)
                .allowsHitTesting(false)
            ForEach(lane.clips) { clip in
                clipView(
                    clip: clip, color: color, mediaId: lane.mediaId, pxPerSec: pxPerSec,
                    thumbnail: item?.thumbnail, label: formatTime(clip.length),
                    sourceLength: item?.duration ?? clip.outPoint
                )
            }
        }
        .frame(width: width, height: laneHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private func musicRow(pxPerSec: Double, width: CGFloat, dur: Double) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.06))
                .frame(width: width, height: laneHeight)
                .allowsHitTesting(false)
            if let m = store.project.music {
                let ownEnd = m.start + m.clipLength
                let end = m.end(total: dur)
                if m.loop && end > ownEnd {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.musicGreen.opacity(0.18))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.musicGreen.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        .frame(width: (end - ownEnd) * pxPerSec, height: laneHeight - 6)
                        .offset(x: ownEnd * pxPerSec, y: 3)
                        .allowsHitTesting(false)
                }
                clipView(
                    clip: m.asClip, color: .musicGreen, mediaId: musicLane, pxPerSec: pxPerSec,
                    thumbnail: nil, label: m.name, sourceLength: m.duration
                )
            } else {
                Button { store.openMusicImporter() } label: {
                    Label("Add music", systemImage: "plus").font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12).frame(height: laneHeight - 4)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .offset(x: 2, y: 2)
            }
        }
        .frame(width: width, height: laneHeight, alignment: .topLeading)
    }

    private func clipView(clip: Clip, color: Color, mediaId: String, pxPerSec: Double, thumbnail: UIImage?, label: String, sourceLength: Double) -> some View {
        let w = max(8, clip.length * pxPerSec)
        let selected = store.selectedClip == clip.id
        return ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(color.opacity(0.55))
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: laneHeight)
                    .opacity(0.35)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(.white)
                .shadow(radius: 2)
                .padding(.horizontal, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(selected ? Color.white : color, lineWidth: selected ? 2.5 : 1)
            HStack {
                handle(.left, mediaId: mediaId, clip: clip, pxPerSec: pxPerSec, sourceLength: sourceLength)
                Spacer(minLength: 0)
                handle(.right, mediaId: mediaId, clip: clip, pxPerSec: pxPerSec, sourceLength: sourceLength)
            }
        }
        .frame(width: w, height: laneHeight - 2)
        .contentShape(Rectangle())
        .gesture(dragGesture(.move, mediaId: mediaId, clip: clip, pxPerSec: pxPerSec, sourceLength: sourceLength))
        .offset(x: clip.start * pxPerSec, y: 1)
        .accessibilityLabel(mediaId == musicLane ? "Music \(label)" : "Clip \(label)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func handle(_ kind: Kind, mediaId: String, clip: Clip, pxPerSec: Double, sourceLength: Double) -> some View {
        Capsule()
            .fill(.white.opacity(0.9))
            .frame(width: 4, height: 16)
            .frame(width: 22, height: laneHeight)
            .contentShape(Rectangle())
            .gesture(dragGesture(kind, mediaId: mediaId, clip: clip, pxPerSec: pxPerSec, sourceLength: sourceLength))
            .accessibilityLabel(kind == .left ? "Trim start" : "Trim end")
    }

    private func dragGesture(_ kind: Kind, mediaId: String, clip: Clip, pxPerSec: Double, sourceLength: Double) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("track"))
            .onChanged { v in
                if drag == nil {
                    drag = DragCtx(kind: kind, mediaId: mediaId, origin: clip, pxPerSec: pxPerSec)
                    frozenView = viewSeconds(store.totalDuration)
                    store.selectedClip = clip.id
                    store.playback.pause()
                }
                guard let d = drag else { return }
                let dt = Double(v.translation.width) / d.pxPerSec
                let next: Clip
                switch d.kind {
                case .left: next = trimLeft(d.origin, dt)
                case .right: next = trimRight(d.origin, dt, mediaDuration: sourceLength)
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
            .onEnded { _ in
                drag = nil
                frozenView = nil
            }
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
            Circle().fill(.white).frame(width: 9, height: 9).shadow(radius: 2)
        }
        .offset(x: x - 1)
    }
}
