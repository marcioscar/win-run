import SwiftUI
import SwiftData

@main struct WinRunApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [Wine.self, Tasting.self])
    }
}
