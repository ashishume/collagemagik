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
    @ObservationIgnored private var musicPlayer: AVAudioPlayer?
    @ObservationIgnored private var musicURL: URL?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var anchorWall: CFTimeInterval = 0
    @ObservationIgnored private var anchorHead: Double = 0

    func player(for item: MediaItem) -> AVPlayer {
        if let p = players[item.id] { return p }
        let p = AVPlayer(url: item.url)
        p.automaticallyWaitsToMinimizeStalling = false
        p.actionAtItemEnd = .pause
        players[item.id] = p
        return p
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
            playhead = 0
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

        for lane in lanes {
            guard let item = store.item(lane.mediaId), let r = resolveLane(lane, playhead) else { continue }
            let p = player(for: item)
            p.volume = Float(lane.volume)
            p.isMuted = lane.volume <= 0
            let cur = p.currentTime().seconds
            let drift = abs(cur - r.time)

            if isPlaying && r.active {
                if seeking.contains(item.id) { continue }
                if !cur.isFinite || drift > 0.35 {
                    seek(p, id: item.id, to: r.time, thenPlay: true)
                } else if p.timeControlStatus == .paused {
                    p.play()
                }
            } else {
                if p.rate != 0 { p.pause() }
                if (!cur.isFinite || drift > 0.04) && !seeking.contains(item.id) {
                    seek(p, id: item.id, to: r.time, thenPlay: false)
                }
            }
        }
        syncMusic(project, total: store.totalDuration)
    }

    private func seek(_ p: AVPlayer, id: String, to t: Double, thenPlay: Bool) {
        seeking.insert(id)
        p.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self, weak p] _ in
            Task { @MainActor in
                guard let self else { return }
                self.seeking.remove(id)
                if thenPlay, self.isPlaying { p?.play() } else if !self.isPlaying { self.sync() }
            }
        }
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
