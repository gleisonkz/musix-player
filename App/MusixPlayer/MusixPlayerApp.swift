import SwiftUI

@main
struct MusixPlayerApp: App {
    @State private var library = SongLibrary()
    @State private var player = PlayerModel()

    init() {
        AudioSession.configure()
        // Live use: the screen must never lock in the middle of a song.
        UIApplication.shared.isIdleTimerDisabled = true
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
                .environment(player)
                .preferredColorScheme(.dark)
                .task { library.installDemoIfNeeded() }
        }
    }
}
