import AVKit
import SwiftUI

@MainActor
@Observable
final class ExportJob {
    enum State: Equatable {
        case idle
        case running
        case done(URL, isVideo: Bool)
        case failed(String)
    }

    var state: State = .idle
    var progress: Double = 0
    var saved = false
    private var exporter: CollageExporter?
    private var task: Task<Void, Never>?

    var isRunning: Bool { state == .running }

    func start(snapshot: ExportSnapshot, video: Bool, quality: ExportQuality, stillTime: Double) {
        state = .running
        progress = 0
        saved = false
        let exporter = CollageExporter(snapshot: snapshot)
        self.exporter = exporter
        UIApplication.shared.isIdleTimerDisabled = true
        task = Task {
            defer { UIApplication.shared.isIdleTimerDisabled = false }
            do {
                if video {
                    let url = try await exporter.exportVideo(quality: quality) { p in
                        Task { @MainActor in self.progress = p }
                    }
                    state = .done(url, isVideo: true)
                } else {
                    let url = try await Task.detached { try exporter.exportPNG(at: stillTime, quality: quality) }.value
                    state = .done(url, isVideo: false)
                }
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        exporter?.cancel()
    }
}

struct ExportSheet: View {
    @Environment(CollageStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum Kind: String, CaseIterable, Identifiable {
        case video = "Video (MP4)", still = "Still (PNG)"
        var id: String { rawValue }
    }

    @State private var kind: Kind = .video
    @State private var quality: ExportQuality = .standard
    @State private var ultraAvailable = true
    @State private var job = ExportJob()
    @State private var resultPlayer: AVPlayer?
    @State private var saveError: String?
    @State private var detent: PresentationDetent = .fraction(0.62)

    private var project: Project { store.project }
    private var dims: (w: Int, h: Int) {
        (Int(project.format.width * quality.scale), Int(project.format.height * quality.scale))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    switch job.state {
                    case .idle, .failed: options
                    case .running: running
                    case .done(let url, let isVideo): done(url, isVideo)
                    }
                }
                .padding(16)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        if job.isRunning { job.cancel() }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.62), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(job.isRunning)
        .task {
            ultraAvailable = CollageExporter.canEncode(format: project.format, quality: .ultra)
            if !project.lanes.isEmpty == false { kind = .video }
        }
        .onChange(of: job.state) { _, new in
            if case .done(let url, true) = new { resultPlayer = AVPlayer(url: url) } else { resultPlayer?.pause(); resultPlayer = nil }
            if case .done = new { withAnimation(.smooth) { detent = .large } }
        }
    }

    // MARK: Options

    private var options: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                row("Format", "\(project.format.label)")
                row("Size", "\(dims.w) × \(dims.h)")
                if kind == .video {
                    row("Length", formatTime(store.totalDuration))
                    row("Sound", soundSummary)
                } else {
                    row("Frame", store.hasPlacedVideo ? "At \(formatTime(store.playback.playhead))" : "Collage")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))

            Picker("Type", selection: $kind) {
                ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Picker("Quality", selection: $quality) {
                    Text(verbatim: "Standard · \(Int(project.format.width))×\(Int(project.format.height))").tag(ExportQuality.standard)
                    if ultraAvailable {
                        Text(verbatim: "Ultra · \(Int(project.format.width * 2))×\(Int(project.format.height * 2))").tag(ExportQuality.ultra)
                    }
                }
                .pickerStyle(.segmented)
                Text(qualityNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if case .failed(let message) = job.state {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { start() } label: {
                Label(kind == .video ? "Export video" : "Export picture", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .disabled(store.placedMediaCount == 0)

            if store.placedMediaCount == 0 {
                Text("Add a photo or video first.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var qualityNote: String {
        if kind == .still { return "A single frame saved as a PNG." }
        return "H.264 video with AAC sound at 30 fps. Your original files are re-read at full quality. Keep the screen on until it finishes."
    }

    private var soundSummary: String {
        let hasVideoSound = placedLanes(project).contains { l in l.volume > 0 && store.item(l.mediaId)?.hasAudio == true }
        let hasMusic = (project.music?.volume ?? 0) > 0
        switch (hasVideoSound, hasMusic) {
        case (true, true): return "Video + music"
        case (true, false): return "Video"
        case (false, true): return "Music"
        default: return "None"
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.subheadline)
    }

    // MARK: Running

    private var running: some View {
        VStack(spacing: 18) {
            Gauge(value: job.progress) {
                Text("Exporting")
            } currentValueLabel: {
                Text(job.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.title3.weight(.semibold).monospacedDigit())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .scaleEffect(1.8)
            .frame(height: 110)
            .padding(.top, 24)
            Text("Rendering your collage. Keep the screen on.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(role: .cancel) { job.cancel() } label: {
                Label("Cancel", systemImage: "xmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
    }

    // MARK: Done

    @ViewBuilder
    private func done(_ url: URL, _ isVideo: Bool) -> some View {
        VStack(spacing: 14) {
            if isVideo, let resultPlayer {
                VideoPlayer(player: resultPlayer)
                    .aspectRatio(project.format.width / project.format.height, contentMode: .fit)
                    .frame(maxHeight: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else if let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            Label("Your collage is ready", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Color.musicGreen)

            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)

                    Button {
                        Task {
                            do {
                                try await PhotoSaver.save(url: url, isVideo: isVideo)
                                withAnimation { job.saved = true }
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } catch {
                                saveError = error.localizedDescription
                            }
                        }
                    } label: {
                        Label(job.saved ? "Saved to Photos" : "Save to Photos", systemImage: job.saved ? "checkmark" : "photo.badge.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .disabled(job.saved)

                    Button { job.state = .idle } label: {
                        Label("Export again", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }
            if let saveError {
                Text(saveError).font(.footnote).foregroundStyle(.orange)
            }
        }
    }

    private func start() {
        store.playback.pause()
        let snapshot = ExportSnapshot(
            project: store.project,
            items: Dictionary(uniqueKeysWithValues: store.items.map { ($0.id, $0) })
        )
        job.start(snapshot: snapshot, video: kind == .video, quality: quality, stillTime: store.playback.playhead)
    }
}
