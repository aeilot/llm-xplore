import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        AppShellView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ChatSession.self, LanguageModel.self, AppPreferences.self], inMemory: true)
}
