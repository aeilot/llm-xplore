import Foundation
import SwiftData

@Model
final class AppPreferences {
    @Attribute(.unique) var id: UUID
    var defaultChatModelID: UUID?
    var defaultQuickAskModelID: UUID?
    var opensMainWindowAfterQuickAskSend: Bool

    init(
        id: UUID = UUID(),
        defaultChatModelID: UUID? = nil,
        defaultQuickAskModelID: UUID? = nil,
        opensMainWindowAfterQuickAskSend: Bool = true
    ) {
        self.id = id
        self.defaultChatModelID = defaultChatModelID
        self.defaultQuickAskModelID = defaultQuickAskModelID
        self.opensMainWindowAfterQuickAskSend = opensMainWindowAfterQuickAskSend
    }
}
