import SwiftUI

extension EnvironmentValues {
    /// True once the opening animation has finished (the editor is fully on screen).
    @Entry var splashDone = false
}

@main
struct CollageMagikApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = CollageStore()
    @State private var library: LibraryStore
    @State private var showSplash = true

    init() {
        // Nothing is open yet, so leftovers from earlier sessions (imported copies, finished exports) can go.
        MediaLoader.purgeTemporaryFiles()
        _library = State(initialValue: LibraryStore())
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environment(\.splashDone, !showSplash)

                if showSplash {
                    SplashView { showSplash = false }
                        .zIndex(1)
                }
            }
            .environment(store)
            .environment(library)
            .tint(.brand)
            // A photo and video editor reads best on a dark canvas: the pictures stay the brightest thing on screen.
            .preferredColorScheme(.dark)
        }
    }
}
