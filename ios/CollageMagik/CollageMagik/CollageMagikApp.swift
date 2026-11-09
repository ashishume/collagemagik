import SwiftUI

@main
struct CollageMagikApp: App {
    @State private var store = CollageStore()
    @State private var library: LibraryStore

    init() {
        // Nothing is open yet, so leftovers from earlier sessions (imported copies, finished exports) can go.
        MediaLoader.purgeTemporaryFiles()
        _library = State(initialValue: LibraryStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(library)
                .tint(.brand)
                // A photo and video editor reads best on a dark canvas: the pictures stay the brightest thing on screen.
                .preferredColorScheme(.dark)
        }
    }
}
