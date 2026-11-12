import AVFoundation
import SwiftUI

/// "Choose part" for one video clip, like Instagram's trim window: the whole video is shown as a filmstrip with a bright window
/// over the part that plays. Drag the window to slide to another moment (same length), drag its ends to make it longer or shorter.
/// The clip keeps its place on the timeline. The chosen part plays on a loop above.
struct ChoosePartEditor: View {
    @Environment(CollageStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let ref: ClipRef

    @State private var draft: Clip?
    @State private var player = AVPlayer()
    @State private var playing = true
    @State private var current: Double = 0
    @State private var frames: [UIImage] = []
    @State private var timeObserver: Any?
    @State private var drag: DragState?

    private enum Grab { case left, right, window }
    private struct DragState { var grab: Grab; var origin: Clip }

    private var item: MediaItem? { store.item(ref.mediaId) }
    private var mediaDuration: Double { max(item?.duration ?? 0, minClip) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if let draft {
                    summary(draft)
                    filmstrip(draft)
                        .frame(height: 64)
                    Text("Drag the frame to choose another moment. Drag its ends to change the length.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    controls(draft)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .background { AuroraBackground().ignoresSafeArea() }
            .navigationTitle("Choose part")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply", systemImage: "checkmark") {
                        if let draft { store.updateClip(mediaId: ref.mediaId, clipId: ref.clipId) { _ in draft } }
                        if let draft { store.playback.seek(to: draft.start) }
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(draft == nil)
                }
            }
        }
        .task { await setUp() }
        .onDisappear { tearDown() }
    }

    // MARK: Preview

    private var preview: some View {
        ZStack {
            PartPlayerView(player: player)
                .aspectRatio(item.map { $0.width / max($0.height, 1) } ?? 16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.15)))
                .onTapGesture { togglePlay() }
            if !playing {
                Image(systemName: "play.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .frame(width: 64, height: 64)
                    .glassEffect(.regular, in: .circle)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of the chosen part")
        .accessibilityHint(playing ? "Tap to pause" : "Tap to play")
        .accessibilityAddTraits(.isButton)
    }

    private func summary(_ c: Clip) -> some View {
        HStack {
            Label("\(precise(c.inPoint)) – \(precise(c.outPoint))", systemImage: "film")
                .font(.subheadline.weight(.semibold).monospacedDigit())
            Spacer()
            Text(String(format: "%.1fs of %.1fs", c.length, mediaDuration))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func precise(_ s: Double) -> String {
        let t = max(0, s)
        return String(format: "%d:%04.1f", Int(t) / 60, t.truncatingRemainder(dividingBy: 60))
    }

    // MARK: Filmstrip

    private func filmstrip(_ c: Clip) -> some View {
        GeometryReader { geo in
            let inset: CGFloat = 14
            let w = geo.size.width - inset * 2
            let pxPerSec = Double(w) / mediaDuration
            let x0 = inset + CGFloat(c.inPoint * pxPerSec)
            let x1 = inset + CGFloat(c.outPoint * pxPerSec)
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                // the whole video
                HStack(spacing: 0) {
                    ForEach(Array(frames.enumerated()), id: \.offset) { _, img in
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: w / CGFloat(max(frames.count, 1)), height: h)
                            .clipped()
                    }
                }
                .frame(width: w, height: h, alignment: .leading)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .offset(x: inset)

                // dim what isn't used
                Rectangle().fill(.black.opacity(0.6)).frame(width: max(0, x0 - inset), height: h).offset(x: inset)
                Rectangle().fill(.black.opacity(0.6)).frame(width: max(0, inset + w - x1), height: h).offset(x: x1)

                // the window over the chosen part
                window(width: x1 - x0, height: h)
                    .offset(x: x0 - inset)

                // where the preview is
                if current >= c.inPoint, current <= c.outPoint {
                    Capsule().fill(.white).frame(width: 2, height: h - 8)
                        .offset(x: inset + CGFloat(current * pxPerSec) - 1, y: 4)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(stripGesture(x0: x0, x1: x1, pxPerSec: pxPerSec, inset: inset))
        }
        .accessibilityElement()
        .accessibilityLabel("Chosen part")
        .accessibilityValue("\(precise(c.inPoint)) to \(precise(c.outPoint))")
        .accessibilityAdjustableAction { dir in
            let step = dir == .increment ? 0.5 : -0.5
            guard let d = draft else { return }
            draft = slipClip(d, step, mediaDuration: mediaDuration)
            restartLoop()
        }
    }

    private func window(width: CGFloat, height: CGFloat) -> some View {
        let handle: CGFloat = 14
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.yellow, lineWidth: 3)
            HStack(spacing: 0) {
                handleView.frame(width: handle)
                Spacer(minLength: 0)
                handleView.frame(width: handle)
            }
        }
        .frame(width: width + handle * 2, height: height)
        .offset(x: -handle)
        .allowsHitTesting(false)
    }

    private var handleView: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.yellow)
            .overlay(Capsule().fill(.black.opacity(0.55)).frame(width: 3, height: 18))
    }

    private func stripGesture(x0: CGFloat, x1: CGFloat, pxPerSec: Double, inset: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard let d = draft else { return }
                if drag == nil {
                    let x = v.startLocation.x
                    let grab: Grab
                    if abs(x - x0) <= 24 && x <= (x0 + x1) / 2 { grab = .left }
                    else if abs(x - x1) <= 24 { grab = .right }
                    else if x > x0 && x < x1 { grab = .window }
                    else {
                        // a tap outside the window moves it there (centred on the finger)
                        let t = Double(x - inset) / pxPerSec
                        draft = slipClip(d, t - (d.inPoint + d.length / 2), mediaDuration: mediaDuration)
                        grab = .window
                    }
                    drag = DragState(grab: grab, origin: draft ?? d)
                    player.pause()
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                guard let ds = drag else { return }
                let dt = Double(v.translation.width) / pxPerSec
                let o = ds.origin
                let next: Clip
                switch ds.grab {
                case .window: next = slipClip(o, dt, mediaDuration: mediaDuration)
                case .left: next = choosePart(o, inPoint: min(o.inPoint + dt, o.outPoint - minClip), outPoint: o.outPoint, mediaDuration: mediaDuration)
                case .right: next = choosePart(o, inPoint: o.inPoint, outPoint: o.outPoint + dt, mediaDuration: mediaDuration)
                }
                draft = next
                // show the frame at the edge being moved
                let at = ds.grab == .right ? max(next.inPoint, next.outPoint - 0.04) : next.inPoint
                seek(at, precise: true)
            }
            .onEnded { _ in
                drag = nil
                restartLoop()
            }
    }

    // MARK: Controls

    private func controls(_ c: Clip) -> some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ChipButton(title: playing ? "Pause" : "Play", symbol: playing ? "pause.fill" : "play.fill") { togglePlay() }
                ChipButton(title: "Whole video", symbol: "arrow.left.and.right") {
                    draft = choosePart(c, inPoint: 0, outPoint: mediaDuration, mediaDuration: mediaDuration)
                    restartLoop()
                }
                ChipButton(title: "Start here", symbol: "arrow.right.to.line") {
                    // the chosen part begins at the frame showing now
                    draft = choosePart(c, inPoint: current, outPoint: current + c.length, mediaDuration: mediaDuration)
                    restartLoop()
                }
            }
        }
    }

    // MARK: Player

    private func setUp() async {
        guard draft == nil, let item, let clip = store.clip(ref) else { return }
        store.playback.pause()
        draft = clip
        let playerItem = AVPlayerItem(url: item.url)
        player.replaceCurrentItem(with: playerItem)
        player.isMuted = (store.project.lanes.first { $0.mediaId == ref.mediaId }?.volume ?? 1) == 0
        player.actionAtItemEnd = .pause
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { t in
            MainActor.assumeIsolated { tick(t.seconds) }
        }
        restartLoop()
        await loadFrames(url: item.url)
    }

    private func tearDown() {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    private func tick(_ t: Double) {
        guard t.isFinite else { return }
        current = t
        guard drag == nil, playing, let d = draft else { return }
        if t >= d.outPoint - 0.02 || player.timeControlStatus == .paused && player.rate == 0 && t >= mediaDuration - 0.05 {
            seek(d.inPoint, precise: true)
            player.play()
        }
    }

    private func restartLoop() {
        guard let d = draft else { return }
        seek(d.inPoint, precise: true)
        if playing { player.play() }
    }

    private func togglePlay() {
        playing.toggle()
        if playing {
            if let d = draft, current < d.inPoint || current >= d.outPoint - 0.05 { seek(d.inPoint, precise: true) }
            player.play()
        } else {
            player.pause()
        }
    }

    private func seek(_ t: Double, precise: Bool) {
        current = t
        let tol = precise ? CMTime.zero : CMTime(value: 1, timescale: 10)
        player.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: tol, toleranceAfter: tol)
    }

    private func loadFrames(url: URL) async {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 200, height: 200)
        gen.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 2)
        gen.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 2)
        let count = 10
        let times = (0..<count).map { CMTime(seconds: mediaDuration * (Double($0) + 0.5) / Double(count), preferredTimescale: 600) }
        var images: [UIImage] = []
        for await result in gen.images(for: times) {
            if let img = try? result.image { images.append(UIImage(cgImage: img)) }
        }
        if !images.isEmpty { frames = images }
    }
}

/// Shows an AVPlayer without the system controls.
private struct PartPlayerView: UIViewRepresentable {
    let player: AVPlayer

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> PlayerUIView {
        let v = PlayerUIView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspect
        v.backgroundColor = .black
        return v
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}
