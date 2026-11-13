import AVKit
import StoreKit
import SwiftUI

@MainActor
@Observable
final class ExportJob {
    enum State: Equatable {
        case idle
        case running
        case done(URL, isVideo: Bool)
        /// A carousel: one picture per slide, in order.
        case doneSlides([URL])
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
                    await showAdBeforeResult()
                    state = .done(url, isVideo: true)
                } else {
                    let url = try await Task.detached { try exporter.exportPNG(at: stillTime, quality: quality) }.value
                    await showAdBeforeResult()
                    state = .done(url, isVideo: false)
                }
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    /// Carousel: renders the whole design once and cuts it into slides.
    func startSlides(snapshot: ExportSnapshot) {
        state = .running
        progress = 0
        saved = false
        let exporter = CollageExporter(snapshot: snapshot)
        self.exporter = exporter
        task = Task {
            do {
                let urls = try await Task.detached { try exporter.exportSlides() }.value
                await showAdBeforeResult()
                state = .doneSlides(urls)
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        exporter?.cancel()
    }

    /// True while the full-screen ad that comes before the result is up (the export itself is finished).
    var waitingForAd = false

    /// Google ads: one full-screen ad between "export finished" and showing the result.
    private func showAdBeforeResult() async {
        progress = 1
        waitingForAd = true
        await GoogleAdsManager.shared.beforeShowingExportResult()
        waitingForAd = false
    }
}

struct ExportSheet: View {
    @Environment(CollageStore.self) private var store
    @Environment(LibraryStore.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    /// Every finished export is also kept in My Library, on this iPhone.
    private enum LibrarySave: Equatable { case idle, saving, saved, failed(String) }

    private enum Kind: String, CaseIterable, Identifiable {
        case video = "Video (MP4)", still = "Still (PNG)"
        var id: String { rawValue }
    }

    @State private var kind: Kind = .video
    @State private var quality: ExportQuality = .standard
    @State private var ultraAvailable = true
    @State private var job = ExportJob()
    @State private var resultPlayer: AVPlayer?
    @State private var saveError: Error?
    @State private var librarySave: LibrarySave = .idle
    @State private var detent: PresentationDetent = .fraction(0.62)

    private var project: Project { store.project }
    /// Pixels of one picture: the whole collage, or a single carousel slide.
    private var dims: (w: Int, h: Int) {
        (Int(project.format.width * quality.scale), Int(project.format.height * quality.scale))
    }
    private var isCarousel: Bool { project.mode == .carousel }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    switch job.state {
                    case .idle, .failed: options
                    case .running: running
                    case .done(let url, let isVideo): done(url, isVideo)
                    case .doneSlides(let urls): doneSlides(urls)
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
        .proPaywallHost()
        .onDisappear {
            // An ad (if one is due) comes only after a finished export, once this sheet is gone.
            let finished: Bool
            switch job.state {
            case .done, .doneSlides: finished = true
            default: finished = false
            }
            AdManager.shared.exportSheetClosed(finished: finished)
        }
        .task {
            ultraAvailable = CollageExporter.canEncode(format: project.format, quality: .ultra)
            if !project.lanes.isEmpty == false { kind = .video }
        }
        .onChange(of: job.state) { _, new in
            if case .done(let url, true) = new { resultPlayer = AVPlayer(url: url) } else { resultPlayer?.pause(); resultPlayer = nil }
            switch new {
            case .done(let url, let isVideo):
                withAnimation(.smooth) { detent = .large }
                keepInLibrary(url, isVideo: isVideo)
                askForReviewIfDue()
            case .doneSlides(let urls):
                withAnimation(.smooth) { detent = .large }
                keepCarouselInLibrary(urls)
                askForReviewIfDue()
            default:
                librarySave = .idle
            }
        }
    }

    /// Apple's own rating prompt, after the 3rd and 10th finished export (Apple also limits how often it really appears).
    private func askForReviewIfDue() {
        let key = "rating.finishedExports"
        let n = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(n, forKey: key)
        guard n == 3 || n == 10 else { return }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            requestReview()
        }
    }

    private func keepCarouselInLibrary(_ urls: [URL]) {
        librarySave = .saving
        let size = dims
        let label = "Carousel \(project.format.short)"
        Task {
            do {
                try await library.addCarousel(files: urls, width: size.w, height: size.h, formatLabel: label)
                librarySave = .saved
            } catch {
                librarySave = .failed(error.localizedDescription)
            }
        }
    }

    private func keepInLibrary(_ url: URL, isVideo: Bool) {
        librarySave = .saving
        let size = dims
        let duration = isVideo ? store.totalDuration : 0
        let label = project.format.label
        Task {
            do {
                try await library.add(file: url, isVideo: isVideo, width: size.w, height: size.h, duration: duration, formatLabel: label)
                librarySave = .saved
            } catch {
                librarySave = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: Options

    @ViewBuilder
    private var options: some View {
        if isCarousel { carouselOptions } else { collageOptions }
    }

    private var carouselOptions: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                row("Format", "Carousel \(project.format.short)")
                row("Slides", "\(project.slides)")
                row("Size", "\(dims.w) × \(dims.h) each")
                row("Files", "JPEG, one per slide")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))

            Text("Upload the slides to Instagram in order, and the pictures that cross a seam join up as people swipe.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if case .failed(let message) = job.state {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { startSlides() } label: {
                Label("Export \(project.slides) slides", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .disabled(store.placedMediaCount == 0)

            if store.placedMediaCount == 0 {
                Text("Add a photo first.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var collageOptions: some View {
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
            Text(job.waitingForAd ? "Done! Your collage is ready — it opens right after a short ad." : "Rendering your collage. Keep the screen on.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !job.waitingForAd {
                Button(role: .cancel) { job.cancel() } label: {
                    Label("Cancel", systemImage: "xmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
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
            switch librarySave {
            case .saved:
                Label("Kept in My Library on this iPhone", systemImage: "photo.stack")
                    .font(.footnote).foregroundStyle(.secondary)
            case .failed(let why):
                Label("Couldn't add it to My Library: \(why)", systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.orange)
            case .idle, .saving:
                EmptyView()
            }

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
                                saveError = error
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
                SaveFailureNote(error: saveError)
            }
            if GoogleAdsManager.shared.isEnabled || AdManager.shared.isEnabled {
                Button { ProStore.shared.openPaywall() } label: {
                    Label("Remove ads with Pro", systemImage: "sparkles").font(.footnote.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.brand)
            }
            RateUsLink()
        }
    }

    private func startSlides() {
        store.playback.pause()
        let snapshot = ExportSnapshot(
            project: store.project,
            items: Dictionary(uniqueKeysWithValues: store.items.map { ($0.id, $0) })
        )
        job.startSlides(snapshot: snapshot)
    }

    // MARK: Done (carousel)

    @ViewBuilder
    private func doneSlides(_ urls: [URL]) -> some View {
        VStack(spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { i, url in
                        if let img = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(alignment: .topLeading) {
                                    Text("\(i + 1)")
                                        .font(.caption2.weight(.bold).monospacedDigit())
                                        .padding(.horizontal, 7).padding(.vertical, 3)
                                        .glassEffect(.regular, in: .capsule)
                                        .padding(6)
                                }
                        }
                    }
                }
            }
            .scrollClipDisabled()

            Label("Your carousel is ready", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Color.musicGreen)
            switch librarySave {
            case .saved:
                Label("Kept in My Library on this iPhone", systemImage: "photo.stack")
                    .font(.footnote).foregroundStyle(.secondary)
            case .failed(let why):
                Label("Couldn't add it to My Library: \(why)", systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(.orange)
            case .idle, .saving:
                EmptyView()
            }

            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    ShareLink(items: urls) {
                        Label("Share all \(urls.count) slides", systemImage: "square.and.arrow.up").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)

                    Button {
                        Task {
                            do {
                                try await PhotoSaver.saveAll(urls: urls)
                                withAnimation { job.saved = true }
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } catch {
                                saveError = error
                            }
                        }
                    } label: {
                        Label(job.saved ? "Saved to Photos" : "Save all to Photos", systemImage: job.saved ? "checkmark" : "photo.badge.arrow.down")
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
                SaveFailureNote(error: saveError)
            }
            if GoogleAdsManager.shared.isEnabled || AdManager.shared.isEnabled {
                Button { ProStore.shared.openPaywall() } label: {
                    Label("Remove ads with Pro", systemImage: "sparkles").font(.footnote.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.brand)
            }
            RateUsLink()
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
