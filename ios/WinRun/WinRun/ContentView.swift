import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Adega", systemImage: "wineglass") {
                WineListView()
            }
            Tab("Degustações", systemImage: "list.star") {
                TastingListView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Wine.self, Tasting.self], inMemory: true)
        .preferredColorScheme(.dark)
}
