import SwiftUI

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Collage or Carousel") {
                    Label("Switch at the top: Collage makes one picture or video. Carousel makes a post with several slides.", systemImage: "rectangle.split.3x1")
                    Label("In a Carousel, pictures run across the line between slides, so half of a photo is on one slide and half on the next. People swipe to see the rest.", systemImage: "arrow.left.and.right")
                    Label("Drag to swipe between slides, or tap a number under the preview. Tap a picture first, then drag it to move it. Slides are added for you to fit your pictures. Pick a style in Layout, and tap Shuffle to try another arrangement.", systemImage: "hand.draw")
                    Label("Export gives you one image per slide. Upload them to Instagram in order.", systemImage: "square.and.arrow.up")
                }
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
                Section("My Library") {
                    Label("Every collage you export is kept in My Library (the ••• menu), on this iPhone only. Open one to play, share, save to Photos or delete it.", systemImage: "photo.stack")
                    Label("There is no account and nothing is uploaded. Deleting the app deletes your library.", systemImage: "lock.shield")
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
