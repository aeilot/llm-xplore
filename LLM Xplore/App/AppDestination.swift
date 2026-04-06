import Foundation

enum AppDestination: Hashable {
    case home
    case chat(UUID)
    case models
    case settings
}
