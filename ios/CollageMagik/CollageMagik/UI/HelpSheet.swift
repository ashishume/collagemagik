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
                    Label("Keep up to 15 photos and videos in your tray (2 can be videos), and use up to 9 in the collage. Press and hold a tray picture to remove it.", systemImage: "photo.on.rectangle.angled")
                    Label("Pick a layout for the number of cells, then set the gap, corners and colour.", systemImage: "square.grid.2x2")
                    Label("Story, Post (4:5) and Square formats.", systemImage: "rectangle.portrait")
                }
                Section("In the preview") {
                    Label("Tap a picture, a photo on top or a caption to select it. Only what is selected moves, so the layers under it stay put.", systemImage: "hand.tap")
                    Label("Drag the selected picture to move it, pinch to zoom or resize it, and twist with two fingers to turn or straighten it.", systemImage: "hand.draw")
                    Label("Tap anywhere outside the selection to deselect it.", systemImage: "hand.tap.fill")
                    Label("Press and hold a picture, then drag it onto another cell to swap.", systemImage: "arrow.left.arrow.right")
                    Label("Photos on top have the same tools as pictures in cells: change, rotate, flip, crop and zoom.", systemImage: "square.on.square")
                }
                Section("Captions") {
                    Label("Open Text and tap Add caption to write on your collage. Pick from \(CaptionFont.allCases.count) lettering styles, bold, italic, underline, strikethrough or all caps, any colour, and a shadow, label, plate or outline behind the words.", systemImage: "textformat")
                    Label("Tap a caption to select it, then drag to move it (it clicks onto the middle), pinch to resize it and twist with two fingers to turn it. Tap it again to change the words.", systemImage: "hand.draw")
                    Label("Long captions wrap by themselves so they always fit inside the picture. Captions are part of every export.", systemImage: "text.justify.left")
                }
                Section("Videos & music") {
                    Label("Videos play inside the collage. While there is one, a bar under the preview plays it and opens the Timeline (or select the video and tap Edit timeline). Drag the ends to trim, drag a clip to delay it, Split at the playhead.", systemImage: "scissors")
                    Label("Add your own music (MP3, M4A, WAV) and set volume and fade out under Timeline, then Sound.", systemImage: "music.note")
                    Label("The collage lasts as long as the longest clip, up to 60 seconds.", systemImage: "clock")
                }
                Section("Formats that work") {
                    Label("Photos: HEIC, JPEG, PNG and more.", systemImage: "photo")
                    Label("Videos: iPhone .mov and .mp4 in H.264 or HEVC, including HDR and portrait clips.", systemImage: "video")
                    Label("Other containers (AVI, MKV, WebM, MPEG-1/2) can't be played by iOS. Convert them to MP4 first.", systemImage: "exclamationmark.triangle")
                }
                Section("Export") {
                    Label("MP4 at 1080 wide (or double on supported iPhones), or a PNG still. With HDR videos it can export in HDR, keeping their bright highlights. Share it or save to Photos.", systemImage: "square.and.arrow.up")
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
