import SwiftUI

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Build a collage") {
                    Label("Add up to 9 photos and 2 videos from your library or Files.", systemImage: "photo.on.rectangle.angled")
                    Label("Pick a layout for the number of cells, then set the gap, corners and colour.", systemImage: "square.grid.2x2")
                    Label("Story, Post (4:5) and Square formats.", systemImage: "rectangle.portrait")
                }
                Section("In the preview") {
                    Label("Tap a picture to edit it.", systemImage: "hand.tap")
                    Label("Drag to move it inside its cell. Pinch to zoom.", systemImage: "hand.draw")
                    Label("Press and hold a picture, then drag it onto another cell to swap.", systemImage: "arrow.left.arrow.right")
                }
                Section("Videos & music") {
                    Label("Videos play inside the collage. Cut them on the Timeline: drag the ends to trim, drag a clip to delay it, Split at the playhead.", systemImage: "scissors")
                    Label("Add your own music (MP3, M4A, WAV) and set volume and fade out.", systemImage: "music.note")
                    Label("The collage lasts as long as the longest clip, up to 60 seconds.", systemImage: "clock")
                }
                Section("Formats that work") {
                    Label("Photos: HEIC, JPEG, PNG and more.", systemImage: "photo")
                    Label("Videos: iPhone .mov and .mp4 in H.264 or HEVC, including HDR and portrait clips.", systemImage: "video")
                    Label("Other containers (AVI, MKV, WebM, MPEG-1/2) can't be played by iOS. Convert them to MP4 first.", systemImage: "exclamationmark.triangle")
                }
                Section("Export") {
                    Label("MP4 at 1080 wide (or double on supported iPhones), or a PNG still. Share it or save to Photos.", systemImage: "square.and.arrow.up")
                }
            }
            .navigationTitle("How it works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
