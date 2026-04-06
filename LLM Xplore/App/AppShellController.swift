import Foundation
import Observation

@Observable
final class AppShellController {
    var destination: AppDestination = .home
    var selectedChatID: UUID?
    var sidebarSearchText = ""
    var quickAskRequestedChatID: UUID?

    func selectHome() {
        destination = .home
        selectedChatID = nil
    }

    func selectChat(_ id: UUID) {
        selectedChatID = id
        destination = .chat(id)
    }

    func selectModels() {
        destination = .models
    }

    func selectSettings() {
        destination = .settings
    }
}
