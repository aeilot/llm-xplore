import Foundation
import SwiftUI

struct AppShellView: View {
    @State private var controller = AppShellController()

    var body: some View {
        NavigationSplitView {
            SidebarView(controller: controller)
        } detail: {
            AppShellDetailView(destination: controller.destination)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: controller.selectSettings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
    }
}

private struct AppShellDetailView: View {
    let destination: AppDestination

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch destination {
            case .home:
                Text("LLM Xplore")
                    .font(.largeTitle.bold())
                Text("Start a chat or browse your existing history.")
                    .foregroundStyle(.secondary)
            case .chat(let id):
                Text("Chat")
                    .font(.largeTitle.bold())
                Text("Selected chat: \(id.uuidString)")
                    .font(.headline)
            case .models:
                Text("Models")
                    .font(.largeTitle.bold())
                Text("Model management will live here in a later task.")
                    .foregroundStyle(.secondary)
            case .settings:
                Text("Settings")
                    .font(.largeTitle.bold())
                Text("Settings details will be added later.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }
}
