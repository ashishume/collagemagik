import SwiftUI

/// The collage, as large as the screen allows, playing from the start. Tap to show or hide the controls.
struct FullScreenPreview: View {
    @Environment(CollageStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showControls = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            StageView(interactive: false)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // A tap anywhere shows or hides the controls.
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { toggleControls() }

            if showControls {
                controls
                    .transition(.opacity)
            }
        }
        .statusBarHidden(!showControls)
        .persistentSystemOverlays(showControls ? .automatic : .hidden)
        .animation(.smooth(duration: 0.25), value: showControls)
        .onAppear {
            let pb = store.playback
            pb.seek(to: 0)
            if store.hasPlacedVideo { pb.play() }
            scheduleHide()
        }
        .onDisappear {
            hideTask?.cancel()
            store.playback.pause()
        }
        .onChange(of: store.playback.isPlaying) { scheduleHide() }
    }

    private var controls: some View {
        VStack {
            HStack {
                GlassIconButton(symbol: "xmark", label: "Close preview", size: 44) { dismiss() }
                Spacer()
            }
            Spacer()
            if store.hasPlacedVideo { transport }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var transport: some View {
        let pb = store.playback
        return HStack(spacing: 10) {
            Button {
                pb.togglePlay()
                scheduleHide()
            } label: {
                Image(systemName: pb.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(pb.isPlaying ? "Pause" : "Play")

            Slider(
                value: Binding(get: { pb.playhead }, set: { pb.seek(to: $0); scheduleHide() }),
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

    private func toggleControls() {
        showControls.toggle()
        if showControls { scheduleHide() }
    }

    /// While a video plays the controls fade away on their own, so the collage has the whole screen.
    private func scheduleHide() {
        hideTask?.cancel()
        guard store.playback.isPlaying else { return }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { showControls = false }
        }
    }
}
