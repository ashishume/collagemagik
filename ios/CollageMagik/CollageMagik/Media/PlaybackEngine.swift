import AVFoundation
import SwiftUI

/// Keeps one AVPlayer per video (and one for the music) in step with the timeline clock, so the collage plays live.
@MainActor
@Observable
final class PlaybackEngine {
    var playhead: Double = 0
    var isPlaying = false

    @ObservationIgnored weak var store: CollageStore?
    @ObservationIgnored private var players: [String: AVPlayer] = [:]
    @ObservationIgnored private var seeking: Set<String> = []
    /// When each player was last jumped back into step while playing (see `sync`).
    @ObservationIgnored private var lastPlayingSeek: [String: CFTimeInterval] = [:]
    @ObservationIgnored private var musicPlayer: AVAudioPlayer?
    @ObservationIgnored private var musicURL: URL?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var anchorWall: CFTimeInterval = 0
    @ObservationIgnored private var anchorHead: Double = 0

    func player(for item: MediaItem) -> AVPlayer {
        if let p = players[item.id] { return p }
        // the live preview plays a small copy of big or HDR videos once it's ready (exports use the original)
        PreviewCopies.shared.request(item)
        let playerItem = AVPlayerItem(url: PreviewCopies.shared.playbackURL(for: item))
        // slowed or sped-up clips keep their natural pitch
        playerItem.audioTimePitchAlgorithm = .spectral
        let p = AVPlayer(playerItem: playerItem)
        p.automaticallyWaitsToMinimizeStalling = false
        p.actionAtItemEnd = .pause
        players[item.id] = p
        return p
    }

    /// A video's small preview copy is ready: its player switches to it and catches up with the timeline.
    func useCopy(_ mediaId: String, _ url: URL) {
        guard let p = players[mediaId] else { return }
        let playerItem = AVPlayerItem(url: url)
        playerItem.audioTimePitchAlgorithm = .spectral
        p.replaceCurrentItem(with: playerItem)
        seeking.remove(mediaId)
        sync()
    }

    func dispose(_ mediaId: String) {
        players[mediaId]?.pause()
        players[mediaId] = nil
        seeking.remove(mediaId)
    }

    // MARK: Transport

    func togglePlay() { isPlaying ? pause() : play() }

    func play() {
        guard let store, !isPlaying else { return }
        let total = store.totalDuration
        if playhead >= total - 0.05 { playhead = 0 }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        anchorWall = CACurrentMediaTime()
        anchorHead = playhead
        isPlaying = true
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        sync()
    }

    func pause() {
        guard isPlaying else { return }
        isPlaying = false
        timer?.invalidate()
        timer = nil
        sync()
    }

    func seek(to t: Double) {
        guard let store else { return }
        if isPlaying { pause() }
        playhead = clamp(t, 0, store.totalDuration)
        sync()
    }

    private func tick() {
        guard let store, isPlaying else { return }
        let t = anchorHead + (CACurrentMediaTime() - anchorWall)
        if t >= store.totalDuration {
            isPlaying = false
            timer?.invalidate()
            timer = nil
            // a motion design rests on its last frame (every picture in place; its first moment may still be empty
            // while pictures come in); anything else goes back to the start. Play starts over from the beginning.
            playhead = store.project.isMotion ? store.totalDuration : 0
            sync()
            return
        }
        playhead = t
        sync()
    }

    /// Call after the project changes (trim, move, delete, volume…).
    func projectChanged() {
        guard let store else { return }
        if playhead > store.totalDuration { playhead = store.totalDuration }
        if isPlaying {
            anchorWall = CACurrentMediaTime()
            anchorHead = playhead
        }
        sync()
    }

    // MARK: Sync

    func sync() {
        guard let store else { return }
        let project = store.project
        let lanes = placedLanes(project)
        let active = Set(lanes.map(\.mediaId))

        for (id, p) in players where !active.contains(id) && p.rate != 0 { p.pause() }
        // a motion design: the videos on screen now or within half a second; the others needn't decode
        let onScreenSoon = isPlaying && project.isMotion ? videosOnScreen(project, from: playhead, ahead: 0.6) : nil
        let now = CACurrentMediaTime()

        for lane in lanes {
            guard let item = store.item(lane.mediaId), let r = resolveLane(lane, playhead) else { continue }
            let p = player(for: item)
            p.volume = Float(lane.volume)
            p.isMuted = lane.volume <= 0
            // hidden and silent: pause it (one whose sound is heard keeps playing, so the preview sounds like the export).
            // It is put back in step just before its scene comes in.
            if let onScreenSoon, !onScreenSoon.contains(lane.mediaId), lane.volume <= 0 || !item.hasAudio {
                if p.rate != 0 {
                    p.pause()
                    syncLog("hide \(laneLabel(lane)) at \(String(format: "%.2f", playhead))")
                }
                continue
            }
            let cur = p.currentTime().seconds
            let drift = abs(cur - r.time)

            let rate = Float(r.clip.speed)
            if isPlaying && r.active {
                if seeking.contains(item.id) { continue }
                // Jumping a player back into step costs a decode, and a busy phone drifts again while it does: so
                // while playing, a player just jumped is left to run for a second unless it's far off.
                let recentlyJumped = now - (lastPlayingSeek[item.id] ?? 0) < 1.0
                if !cur.isFinite || (drift > 0.35 * max(1, r.clip.speed) && (!recentlyJumped || drift > 1.0)) {
                    lastPlayingSeek[item.id] = now
                    syncLog("jump \(laneLabel(lane)) at \(String(format: "%.2f", playhead)) drift \(String(format: "%.2f", cur.isFinite ? drift : -1))")
                    seek(p, id: item.id, to: r.time, thenPlay: true, rate: rate, exact: false)
                } else if p.timeControlStatus == .paused || abs(p.rate - rate) > 0.01 {
                    p.playImmediately(atRate: rate)
                }
            } else {
                if p.rate != 0 { p.pause() }
                if (!cur.isFinite || drift > 0.04) && !seeking.contains(item.id) {
                    seek(p, id: item.id, to: r.time, thenPlay: false, rate: rate)
                }
            }
        }
        syncMusic(project, total: store.totalDuration)
    }

    /// `exact: false` (while playing) lets the player land within a few frames, which needs far less decoding than an
    /// exact frame; a paused preview always shows the exact frame.
    private func seek(_ p: AVPlayer, id: String, to t: Double, thenPlay: Bool, rate: Float = 1, exact: Bool = true) {
        seeking.insert(id)
        let tolerance = exact ? CMTime.zero : CMTime(value: 1, timescale: 10)
        p.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self, weak p] _ in
            Task { @MainActor in
                guard let self else { return }
                self.seeking.remove(id)
                if thenPlay, self.isPlaying { p?.playImmediately(atRate: rate) } else if !self.isPlaying { self.sync() }
            }
        }
    }

    /// Debug builds: `CM_SYNC_LOG=1` logs when hidden videos pause and when players are jumped back into step.
    private func syncLog(_ text: @autoclosure () -> String) {
        #if DEBUG
        if ProcessInfo.processInfo.environment["CM_SYNC_LOG"] == "1" { NSLog("CM_SYNC %@", text()) }
        #endif
    }

    private func laneLabel(_ lane: Lane) -> String {
        let i = store?.project.lanes.firstIndex { $0.mediaId == lane.mediaId } ?? 0
        return laneName(i)
    }

    /// Videos shown (even partly faded) in a motion design between `t` and `t + ahead`.
    private func videosOnScreen(_ project: Project, from t: Double, ahead: Double) -> Set<String> {
        var ids: Set<String> = []
        for time in [t, t + ahead / 2, t + ahead] {
            let posed = project.posed(at: time)
            for i in 0..<min(posed.cellCount, posed.cells.count) where posed.cellAlpha(i) > 0.001 {
                if let id = posed.cells[i].mediaId { ids.insert(id) }
            }
        }
        return ids
    }

    private func syncMusic(_ project: Project, total: Double) {
        guard let m = project.music else {
            musicPlayer?.stop()
            musicPlayer = nil
            musicURL = nil
            return
        }
        if musicURL != m.url || musicPlayer == nil {
            musicPlayer = try? AVAudioPlayer(contentsOf: m.url)
            musicPlayer?.prepareToPlay()
            musicURL = m.url
        }
        guard let mp = musicPlayer else { return }
        let s = musicAt(m, playhead, total: total)
        if isPlaying && s.audible {
            mp.volume = Float(m.volume * s.fade)
            if !mp.isPlaying {
                mp.currentTime = s.want
                mp.play()
            } else if abs(mp.currentTime - s.want) > 0.3 {
                mp.currentTime = s.want
            }
        } else if mp.isPlaying {
            mp.pause()
        }
    }
}
