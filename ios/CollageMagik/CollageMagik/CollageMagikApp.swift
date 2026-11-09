import SwiftUI

@main
struct CollageMagikApp: App {
    @State private var store = CollageStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(.brand)
                // A photo and video editor reads best on a dark canvas: the pictures stay the brightest thing on screen.
                .preferredColorScheme(.dark)
        }
    }
}
